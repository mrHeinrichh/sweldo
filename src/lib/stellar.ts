import {
  Address as StellarAddress,
  Asset,
  Claimant,
  Contract,
  Horizon,
  Networks,
  nativeToScVal,
  Operation,
  rpc,
  TransactionBuilder,
  xdr,
} from '@stellar/stellar-sdk'
import { getNetwork, isConnected, requestAccess, signTransaction } from '@stellar/freighter-api'

export const HORIZON_URL = 'https://horizon-testnet.stellar.org'
export const SOROBAN_RPC_URL = 'https://soroban-testnet.stellar.org'
export const NETWORK_PASSPHRASE = Networks.TESTNET
export const server = new Horizon.Server(HORIZON_URL)
export const rpcServer = new rpc.Server(SOROBAN_RPC_URL)

export type WalletState = {
  address: string
  network: string
}

export type BalanceRecord = {
  id: string
  balance_id: string
  amount: string
  asset: string
  sponsor?: string
  last_modified_time?: string
  claimants: Array<{
    destination: string
    predicate: Record<string, unknown>
  }>
}

export type ClaimHistoryRecord = {
  id: string
  balanceId: string
  transactionHash?: string
  claimedAt: string
  amount?: string
  asset?: string
  source: 'stellar' | 'local'
}

export type ScheduleRecipient = {
  employee: string
  amountPerPayout: string
}

type FreighterError = { code?: number; message?: string; ext?: string[] }

function unwrap<T>(result: { error?: FreighterError } & T, label: string): T {
  if (result.error) {
    const detail = result.error.message || result.error.ext?.join(', ') || `error ${result.error.code ?? 'unknown'}`
    throw new Error(`${label}: ${detail}`)
  }
  return result
}

function withTimeout<T>(promise: Promise<T>, milliseconds: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      window.setTimeout(() => reject(new Error('Freighter did not respond. Unlock the extension and try again.')), milliseconds)
    }),
  ])
}

export async function connectWallet(): Promise<WalletState> {
  const connection = unwrap(
    await withTimeout(isConnected(), 3_000),
    'Could not detect Freighter',
  )
  if (!connection.isConnected) {
    throw new Error('Freighter is not available. Install the extension, unlock it, and open Sweldo in the same browser.')
  }

  const access = unwrap(
    await withTimeout(requestAccess(), 30_000),
    'Could not connect Freighter',
  )
  const network = unwrap(
    await withTimeout(getNetwork(), 5_000),
    'Could not read wallet network',
  )
  if (!access.address) throw new Error('Freighter did not return an account. Unlock it and select an account first.')
  return { address: access.address, network: network.network }
}

export async function loadAccount(address: string) {
  return server.loadAccount(address)
}

export async function getXlmBalance(address: string) {
  const account = await loadAccount(address)
  return account.balances.find((balance) => balance.asset_type === 'native')?.balance ?? '0'
}

async function signAndSubmit(transaction: ReturnType<TransactionBuilder['build']>, address: string) {
  const signed = unwrap(
    await signTransaction(transaction.toXDR(), {
      address,
      networkPassphrase: NETWORK_PASSPHRASE,
    }),
    'Freighter could not sign the transaction',
  )
  return server.submitTransaction(TransactionBuilder.fromXDR(signed.signedTxXdr, NETWORK_PASSPHRASE))
}

function wait(milliseconds: number) {
  return new Promise((resolve) => window.setTimeout(resolve, milliseconds))
}

function hexToBytes(hex: string) {
  const clean = hex.trim().replace(/^0x/, '')
  if (!/^[0-9a-fA-F]+$/.test(clean) || clean.length % 2 !== 0) {
    throw new Error('Expected a hex string.')
  }
  const bytes = new Uint8Array(clean.length / 2)
  for (let index = 0; index < clean.length; index += 2) {
    bytes[index / 2] = Number.parseInt(clean.slice(index, index + 2), 16)
  }
  return bytes
}

function bytesToHex(bytes: Uint8Array) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

function amountToScaledInteger(value: string) {
  const [whole = '0', fraction = ''] = value.trim().split('.')
  const normalizedWhole = whole.replace(/[^\d]/g, '') || '0'
  const normalizedFraction = fraction.replace(/[^\d]/g, '').padEnd(7, '0').slice(0, 7)
  return BigInt(normalizedWhole) * 10_000_000n + BigInt(normalizedFraction || '0')
}

export function registryContractId() {
  return import.meta.env.VITE_PAYROLL_REGISTRY_CONTRACT_ID?.trim() ?? ''
}

export async function recordScheduleProof(input: {
  employer: string
  employee: string
  total: string
  asset: string
  cadenceSeconds: number
  claimableBalanceId: string
  payoutTxHash: string
}) {
  const contractId = registryContractId()
  if (!contractId) return null

  const account = await loadAccount(input.employer)
  const scheduleId = new Uint8Array(32)
  window.crypto.getRandomValues(scheduleId)
  const contract = new Contract(contractId)
  const transaction = new TransactionBuilder(account, {
    fee: '1000000',
    networkPassphrase: NETWORK_PASSPHRASE,
  })
    .addOperation(contract.call(
      'record_schedule',
      nativeToScVal(scheduleId, { type: 'bytes' }),
      StellarAddress.fromString(input.employer).toScVal(),
      StellarAddress.fromString(input.employee).toScVal(),
      nativeToScVal(amountToScaledInteger(input.total), { type: 'i128' }),
      nativeToScVal(input.asset, { type: 'string' }),
      nativeToScVal(BigInt(input.cadenceSeconds), { type: 'u64' }),
      nativeToScVal(input.claimableBalanceId, { type: 'string' }),
      nativeToScVal(hexToBytes(input.payoutTxHash), { type: 'bytes' }),
    ))
    .setTimeout(180)
    .build()

  const prepared = await rpcServer.prepareTransaction(transaction)
  const signed = unwrap(
    await signTransaction(prepared.toXDR(), {
      address: input.employer,
      networkPassphrase: NETWORK_PASSPHRASE,
    }),
    'Freighter could not sign the Soroban registry proof',
  )
  const signedTransaction = TransactionBuilder.fromXDR(signed.signedTxXdr, NETWORK_PASSPHRASE)
  const response = await rpcServer.sendTransaction(signedTransaction)
  if (response.status === 'ERROR') {
    throw new Error(`Soroban registry proof failed: ${JSON.stringify(response.errorResult)}`)
  }

  for (let attempt = 0; attempt < 20; attempt += 1) {
    const result = await rpcServer.getTransaction(response.hash)
    if (result.status === 'SUCCESS') {
      return {
        hash: response.hash,
        contractId,
        scheduleId: bytesToHex(scheduleId),
      }
    }
    if (result.status === 'FAILED') {
      throw new Error('Soroban registry proof failed on-chain.')
    }
    await wait(1000)
  }

  return {
    hash: response.hash,
    contractId,
    scheduleId: bytesToHex(scheduleId),
  }
}

function createdBalanceIds(resultXdr?: string) {
  if (!resultXdr) return []
  const transactionResult = xdr.TransactionResult.fromXDR(resultXdr, 'base64')
  return transactionResult.result().results().map((operationResult) => (
    operationResult
      .tr()
      .createClaimableBalanceResult()
      .balanceId()
      .toXDR('hex')
  ))
}

export async function createSchedule(input: {
  employer: string
  employee: string
  amountPerTranche: string
  tranches: number
  firstUnlock: Date
  intervalSeconds: number
  asset: Asset
}) {
  return createBatchSchedule({
    employer: input.employer,
    recipients: [{ employee: input.employee, amountPerPayout: input.amountPerTranche }],
    payouts: input.tranches,
    firstUnlock: input.firstUnlock,
    intervalSeconds: input.intervalSeconds,
    asset: input.asset,
  })
}

export async function createBatchSchedule(input: {
  employer: string
  recipients: ScheduleRecipient[]
  payouts: number
  firstUnlock: Date
  intervalSeconds: number
  asset: Asset
}) {
  const operationCount = input.recipients.length * input.payouts
  if (operationCount < 1) throw new Error('Add at least one employee before locking payroll.')
  if (operationCount > 100) throw new Error('A Stellar transaction can include up to 100 payroll payouts. Reduce employees or payouts.')

  const account = await loadAccount(input.employer)
  let builder = new TransactionBuilder(account, {
    fee: '100',
    networkPassphrase: NETWORK_PASSPHRASE,
  })

  for (const recipient of input.recipients) {
    for (let index = 0; index < input.payouts; index += 1) {
      const unlockUnix = Math.floor(input.firstUnlock.getTime() / 1000) + index * input.intervalSeconds
      const employeeClaimant = new Claimant(
        recipient.employee,
        Claimant.predicateNot(Claimant.predicateBeforeAbsoluteTime(String(unlockUnix))),
      )
      const employerClaimant = new Claimant(
        input.employer,
        Claimant.predicateBeforeAbsoluteTime(String(unlockUnix)),
      )
      builder = builder.addOperation(
        Operation.createClaimableBalance({
          asset: input.asset,
          amount: recipient.amountPerPayout,
          claimants: [employeeClaimant, employerClaimant],
        }),
      )
    }
  }

  const transaction = builder.setTimeout(180).build()
  const result = await signAndSubmit(transaction, input.employer)
  return {
    ...result,
    balanceIds: createdBalanceIds(result.result_xdr),
  }
}

export async function claimBalance(address: string, balanceId: string) {
  const account = await loadAccount(address)
  const transaction = new TransactionBuilder(account, {
    fee: '100',
    networkPassphrase: NETWORK_PASSPHRASE,
  })
    .addOperation(Operation.claimClaimableBalance({ balanceId }))
    .setTimeout(180)
    .build()
  return signAndSubmit(transaction, address)
}

export async function cancelBalances(address: string, balanceIds: string[]) {
  if (balanceIds.length < 1) throw new Error('There are no future payouts available to cancel.')
  if (balanceIds.length > 100) throw new Error('A Stellar transaction can cancel up to 100 payouts at once.')
  const account = await loadAccount(address)
  let builder = new TransactionBuilder(account, {
    fee: '100',
    networkPassphrase: NETWORK_PASSPHRASE,
  })
  for (const balanceId of balanceIds) {
    builder = builder.addOperation(Operation.claimClaimableBalance({ balanceId }))
  }
  return signAndSubmit(builder.setTimeout(180).build(), address)
}

export async function addTrustline(address: string, asset: Asset) {
  if (asset.isNative()) throw new Error('XLM does not need a trustline.')
  const account = await loadAccount(address)
  const transaction = new TransactionBuilder(account, {
    fee: '100',
    networkPassphrase: NETWORK_PASSPHRASE,
  })
    .addOperation(Operation.changeTrust({ asset }))
    .setTimeout(180)
    .build()
  return signAndSubmit(transaction, address)
}

export async function getClaimableBalances(address: string): Promise<BalanceRecord[]> {
  const page = await server.claimableBalances().claimant(address).limit(100).order('desc').call()
  return page.records.map((record) => {
    const claimableBalance = record as unknown as Omit<BalanceRecord, 'balance_id'> & { balance_id?: string }
    return {
      ...claimableBalance,
      balance_id: claimableBalance.balance_id ?? claimableBalance.id,
    }
  })
}

export async function getClaimHistory(address: string): Promise<ClaimHistoryRecord[]> {
  const page = await server.operations().forAccount(address).limit(50).order('desc').call()
  return page.records
    .filter((record) => record.type === 'claim_claimable_balance')
    .map((record) => {
      const operation = record as unknown as {
        id: string
        transaction_hash?: string
        created_at: string
        claimable_balance_id?: string
      }
      return {
        id: operation.id,
        balanceId: operation.claimable_balance_id ?? '',
        transactionHash: operation.transaction_hash,
        claimedAt: operation.created_at,
        source: 'stellar' as const,
      }
    })
}

export function configuredAsset() {
  const code = import.meta.env.VITE_ASSET_CODE?.trim()
  const issuer = import.meta.env.VITE_ASSET_ISSUER?.trim()
  return code && issuer ? new Asset(code, issuer) : Asset.native()
}

export function assetLabel(asset: Asset) {
  return asset.isNative() ? 'XLM' : asset.getCode()
}

export function parseUnlockTime(predicate: Record<string, unknown>): Date | null {
  const not = predicate.not as Record<string, unknown> | undefined
  if (!not) return null
  const value = not.abs_before ?? not.before_absolute_time
  if (typeof value !== 'string' && typeof value !== 'number') return null
  const asNumber = Number(value)
  return Number.isFinite(asNumber) ? new Date(asNumber * 1000) : new Date(String(value))
}

export function friendlyError(error: unknown) {
  const fallback = error instanceof Error ? error.message : String(error)
  const response = (error as { response?: { data?: { extras?: { result_codes?: unknown } } } })?.response
  const codes = response?.data?.extras?.result_codes
  if (codes) return `Stellar rejected the transaction: ${JSON.stringify(codes)}`
  return fallback
}

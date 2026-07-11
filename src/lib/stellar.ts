import {
  Asset,
  Claimant,
  Horizon,
  Networks,
  Operation,
  TransactionBuilder,
} from '@stellar/stellar-sdk'
import { getNetwork, isConnected, requestAccess, signTransaction } from '@stellar/freighter-api'

export const HORIZON_URL = 'https://horizon-testnet.stellar.org'
export const NETWORK_PASSPHRASE = Networks.TESTNET
export const server = new Horizon.Server(HORIZON_URL)

export type WalletState = {
  address: string
  network: string
}

export type BalanceRecord = {
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

export async function createSchedule(input: {
  employer: string
  employee: string
  amountPerTranche: string
  tranches: number
  firstUnlock: Date
  intervalSeconds: number
  asset: Asset
}) {
  const account = await loadAccount(input.employer)
  let builder = new TransactionBuilder(account, {
    fee: '100',
    networkPassphrase: NETWORK_PASSPHRASE,
  })

  for (let index = 0; index < input.tranches; index += 1) {
    const unlockUnix = Math.floor(input.firstUnlock.getTime() / 1000) + index * input.intervalSeconds
    const claimant = new Claimant(
      input.employee,
      Claimant.predicateNot(Claimant.predicateBeforeAbsoluteTime(String(unlockUnix))),
    )
    builder = builder.addOperation(
      Operation.createClaimableBalance({
        asset: input.asset,
        amount: input.amountPerTranche,
        claimants: [claimant],
      }),
    )
  }

  const transaction = builder.setTimeout(180).build()
  return signAndSubmit(transaction, input.employer)
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
  return page.records as unknown as BalanceRecord[]
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

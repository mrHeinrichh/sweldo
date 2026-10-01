import { Asset, Horizon, Networks, Operation, TransactionBuilder } from '@stellar/stellar-sdk'

export type Payout = {
  balance_id: string
  asset: string
  amount: string
  claimants: Array<{ destination: string; predicate: Record<string, unknown> }>
}

export type ConversionPair = { source: Asset; destination: Asset }
export type ConversionQuote = {
  address: string
  balanceId: string
  source: Asset
  destination: Asset
  sendAmount: string
  expectedAmount: string
  minimumAmount: string
  path: Asset[]
  missingTrustlines: Asset[]
  expiresAt: number
}
export type ConversionReceipt = {
  hash: string
  balanceId: string
  sentAmount: string
  receivedAmount: string | null
  minimumAmount: string
}

type Account = Awaited<ReturnType<Horizon.Server['loadAccount']>>
const SCALE = 10_000_000n
export const QUOTE_LIFETIME_MS = 60_000
export const SLIPPAGE_BPS = 100

export function amountUnits(value: string): bigint {
  if (!/^\d+(\.\d{1,7})?$/.test(value)) throw new Error('Invalid Stellar amount.')
  const [whole, fraction = ''] = value.split('.')
  const units = BigInt(whole) * SCALE + BigInt(fraction.padEnd(7, '0'))
  if (units > 9_223_372_036_854_775_807n) throw new Error('Stellar amount is too large.')
  return units
}

export function amountString(units: bigint): string {
  const fraction = (units % SCALE).toString().padStart(7, '0').replace(/0+$/, '')
  return `${units / SCALE}${fraction ? `.${fraction}` : ''}`
}

export function minimumReceived(expected: string): string {
  const minimum = amountUnits(expected) * BigInt(10_000 - SLIPPAGE_BPS) / 10_000n
  if (minimum <= 0n) throw new Error('The payout is too small to convert with slippage protection.')
  return amountString(minimum)
}

export function configuredConversion(env: Record<string, string | undefined>): ConversionPair | null {
  const issuer = env.VITE_ASSET_ISSUER?.trim()
  const phptIssuer = env.VITE_PHPT_ISSUER?.trim()
  if (env.VITE_ASSET_CODE?.trim() !== 'USDC' || !issuer || !phptIssuer) return null
  return { source: new Asset('USDC', issuer), destination: new Asset('PHPT', phptIssuer) }
}

export function supportsConversion(payout: Payout, pair: ConversionPair | null): boolean {
  return !!pair && payout.asset === `${pair.source.code}:${pair.source.issuer}`
}

function predicateAllows(predicate: Record<string, unknown>, ledgerTime: number): boolean {
  if (predicate.unconditional === true) return true
  if (predicate.not) return !predicateAllows(predicate.not as Record<string, unknown>, ledgerTime)
  if (Array.isArray(predicate.and)) return predicate.and.every((p) => predicateAllows(p, ledgerTime))
  if (Array.isArray(predicate.or)) return predicate.or.some((p) => predicateAllows(p, ledgerTime))
  const before = predicate.abs_before ?? predicate.before_absolute_time
  if (typeof before === 'string' || typeof before === 'number') {
    const milliseconds = Number.isFinite(Number(before)) ? Number(before) * 1000 : Date.parse(String(before))
    if (Number.isFinite(milliseconds)) return ledgerTime < milliseconds
  }
  throw new Error('This payout predicate is not supported by the conversion flow.')
}

function checkPayout(payout: Payout, address: string, ledgerTime: number) {
  const claimant = payout.claimants.find((item) => item.destination === address)
  if (!claimant) throw new Error('This wallet is not a claimant for this payout.')
  if (!predicateAllows(claimant.predicate, ledgerTime)) {
    throw new Error('This payout is still locked on the Stellar ledger. Wait for payday and refresh.')
  }
  if (amountUnits(payout.amount) <= 0n) throw new Error('The payout amount must be positive.')
}

function checkTrustlines(account: Account, source: Asset, destination: Asset, send: string, receive: string): Asset[] {
  const missing: Asset[] = []
  for (const [asset, incoming] of [[source, send], [destination, receive]] as const) {
    if (account.account_id === asset.issuer) throw new Error('Use a worker wallet, not an asset issuer, for this demo.')
    const line = account.balances.find((item) => (
      item.asset_type !== 'native' && 'asset_code' in item
      && item.asset_code === asset.code && item.asset_issuer === asset.issuer
    ))
    if (!line) { missing.push(asset); continue }
    if (!('asset_code' in line)) throw new Error('Unsupported trustline.')
    if (!line.is_authorized) throw new Error(`${asset.code} trustline is not authorized by its issuer.`)
    const capacity = amountUnits(line.limit) - amountUnits(line.balance) - amountUnits(line.buying_liabilities ?? '0')
    if (capacity < amountUnits(incoming)) throw new Error(`${asset.code} trustline limit is too low. Increase its limit in your wallet.`)
  }
  return missing
}

async function currentPayout(server: Horizon.Server, balanceId: string): Promise<Payout> {
  try {
    const record = await server.claimableBalances().claimableBalance(balanceId).call()
    return {
      balance_id: record.id, asset: record.asset, amount: record.amount,
      claimants: record.claimants.map((claimant) => ({ destination: claimant.destination, predicate: { ...claimant.predicate } })),
    }
  } catch (error) {
    if ((error as { response?: { status?: number } }).response?.status === 404) {
      throw new Error('This payout is no longer available. Refresh your pay list.')
    }
    throw error
  }
}

export async function quoteClaimConversion(server: Horizon.Server, address: string, balanceId: string, pair: ConversionPair): Promise<ConversionQuote> {
  const [payout, account, ledgers] = await Promise.all([
    currentPayout(server, balanceId), server.loadAccount(address), server.ledgers().order('desc').limit(1).call(),
  ])
  if (!supportsConversion(payout, pair)) throw new Error('Only the configured test-USDC issuer is supported for PHPT conversion.')
  const ledgerTime = Date.parse(ledgers.records[0]?.closed_at ?? '')
  if (!Number.isFinite(ledgerTime)) throw new Error('Could not verify the latest Stellar ledger. Please refresh.')
  checkPayout(payout, address, ledgerTime)
  const routes = await server.strictSendPaths(pair.source, payout.amount, [pair.destination]).call()
  const choices = routes.records.filter((route) => (
    route.destination_asset_code === pair.destination.code && route.destination_asset_issuer === pair.destination.issuer
    && route.source_asset_code === pair.source.code && route.source_asset_issuer === pair.source.issuer
    && amountUnits(route.source_amount) === amountUnits(payout.amount)
    && amountUnits(route.destination_amount) > 0n
  )).sort((a, b) => amountUnits(a.destination_amount) > amountUnits(b.destination_amount) ? -1 : 1)
  const best = choices[0]
  if (!best) throw new Error('No USDC to PHPT liquidity is available for this payout. Nothing was claimed. Refresh the quote after liquidity is restored.')
  const missingTrustlines = checkTrustlines(account, pair.source, pair.destination, payout.amount, best.destination_amount)
  return {
    address, balanceId, source: pair.source, destination: pair.destination,
    sendAmount: payout.amount, expectedAmount: best.destination_amount,
    minimumAmount: minimumReceived(best.destination_amount), missingTrustlines,
    path: best.path.map((asset) => asset.asset_type === 'native' ? Asset.native() : new Asset(asset.asset_code!, asset.asset_issuer!)),
    expiresAt: Date.now() + QUOTE_LIFETIME_MS,
  }
}

export function buildClaimConversion(account: Account, payout: Payout, quote: ConversionQuote, fee: string, now = Date.now()) {
  if (now >= quote.expiresAt) throw new Error('Your quote expired. Refresh it before signing.')
  if (account.account_id !== quote.address || payout.balance_id !== quote.balanceId
      || payout.asset !== `${quote.source.code}:${quote.source.issuer}`
      || amountUnits(payout.amount) !== amountUnits(quote.sendAmount)) {
    throw new Error('The wallet or payout changed. Refresh the quote.')
  }
  checkPayout(payout, quote.address, now)
  const missing = checkTrustlines(account, quote.source, quote.destination, quote.sendAmount, quote.expectedAmount)
  let builder = new TransactionBuilder(account, { fee, networkPassphrase: Networks.TESTNET })
  // All operations roll back together if the claim or conversion fails.
  for (const asset of missing) builder = builder.addOperation(Operation.changeTrust({ asset }))
  return builder
    .addOperation(Operation.claimClaimableBalance({ balanceId: quote.balanceId }))
    .addOperation(Operation.pathPaymentStrictSend({
      sendAsset: quote.source, sendAmount: quote.sendAmount, destination: quote.address,
      destAsset: quote.destination, destMin: quote.minimumAmount, path: quote.path,
    }))
    .setTimeout(Math.max(1, Math.floor((quote.expiresAt - now) / 1000)))
    .build()
}

export async function prepareClaimConversion(server: Horizon.Server, quote: ConversionQuote) {
  const [account, payout, fee] = await Promise.all([
    server.loadAccount(quote.address), currentPayout(server, quote.balanceId), server.fetchBaseFee(),
  ])
  return buildClaimConversion(account, payout, quote, String(fee))
}

export function conversionError(error: unknown): string {
  const codes = (error as { response?: { data?: { extras?: { result_codes?: { transaction?: string; operations?: string[] } } } } })?.response?.data?.extras?.result_codes
  const operations = codes?.operations ?? []
  if (operations.includes('op_under_dest_min')) return 'The PHPT rate moved beyond the 1% limit. Nothing was claimed or converted. Refresh the quote.'
  if (operations.includes('op_too_few_offers')) return 'There is no longer enough liquidity. Nothing was claimed or converted. Refresh the quote.'
  if (operations.includes('op_low_reserve') || codes?.transaction === 'tx_insufficient_balance') return 'Not enough Testnet XLM for trustline reserves and transaction fees. Fund the worker wallet and retry.'
  if (operations.some((code) => ['op_no_trust', 'op_src_no_trust', 'op_line_full', 'op_not_authorized', 'op_src_not_authorized'].includes(code))) return 'Check the test-USDC and PHPT trustline authorization and limits. Nothing was claimed or converted.'
  if (operations.includes('op_cannot_claim')) return 'The payout is locked or this wallet cannot claim it. Refresh your pay list.'
  if (operations.includes('op_does_not_exist')) return 'The payout was already claimed or cancelled. Refresh your pay list.'
  if (codes?.transaction === 'tx_too_late') return 'Your quote expired while signing. Nothing was claimed. Refresh the quote.'
  if (codes?.transaction === 'tx_bad_seq') return 'Your wallet changed while signing. Refresh the quote and try again.'
  if (codes) return `Stellar rejected the transaction (${[codes.transaction, ...operations].filter(Boolean).join(', ')}). No payout operations were applied.`
  return error instanceof Error ? error.message : 'Could not complete the conversion. Please try again.'
}

import { StrKey } from '@stellar/stellar-sdk'

type Receipt = { wallet: 'freighter' | 'xbull'; kind: 'funding' | 'claim-convert' | 'cancellation' | 'registry'; account: string; hash: string }
export type VerificationManifest = {
  network: 'Stellar Testnet'
  assets: { usdc: { code: 'USDC'; issuer: string }; phpt: { code: 'PHPT'; issuer: string } }
  receipts: Receipt[]
  demoVideoUrl?: string
  liveUrl?: string
  week4PrUrl?: string
}

export function verificationManifest(input: unknown): VerificationManifest {
  const value = input as VerificationManifest
  if (value?.network !== 'Stellar Testnet') throw new Error('Only Stellar Testnet evidence is accepted.')
  if (!Array.isArray(value.receipts) || !value.receipts.length || value.receipts.length > 50) {
    throw new Error('Supply 1-50 actual Testnet receipts. Empty templates are not completed evidence.')
  }
  const seen = new Set<string>()
  for (const receipt of value.receipts) {
    if (!receipt || !['freighter', 'xbull'].includes(receipt.wallet)
      || !['funding', 'claim-convert', 'cancellation', 'registry'].includes(receipt.kind)
      || !StrKey.isValidEd25519PublicKey(receipt.account)
      || !/^[a-f0-9]{64}$/i.test(receipt.hash)) throw new Error('Each receipt needs a supported wallet, action, public G key and 64-character hash.')
    if (seen.has(receipt.hash.toLowerCase())) throw new Error('Do not count the same receipt twice.')
    seen.add(receipt.hash.toLowerCase())
  }
  if (value.receipts.some((receipt) => receipt.kind === 'claim-convert')) {
    for (const [name, code] of [['usdc', 'USDC'], ['phpt', 'PHPT']] as const) {
      if (value.assets?.[name]?.code !== code || !StrKey.isValidEd25519PublicKey(value.assets[name].issuer)) {
        throw new Error('Claim-and-convert evidence needs the exact controlled test-USDC and PHPT issuers.')
      }
    }
  }
  return value
}

export function verifyReceipt(receipt: Receipt, transaction: { successful: boolean; source_account: string }, operations: Array<Record<string, unknown>>, assets: VerificationManifest['assets']) {
  if (!transaction.successful || transaction.source_account !== receipt.account) return false
  const byAccount = operations.filter((op) => op.source_account === receipt.account && op.transaction_successful !== false)
  if (receipt.kind === 'funding') return byAccount.some((op) => op.type === 'create_claimable_balance')
  if (receipt.kind === 'registry') return byAccount.some((op) => op.type === 'invoke_host_function')
  if (receipt.kind === 'cancellation') return byAccount.some((op) => op.type === 'claim_claimable_balance' && op.claimant === receipt.account)
  return byAccount.some((op) => op.type === 'claim_claimable_balance' && op.claimant === receipt.account)
    && byAccount.some((op) => op.type === 'path_payment_strict_send'
      && op.from === receipt.account && op.to === receipt.account
      && op.source_asset_code === assets.usdc.code && op.source_asset_issuer === assets.usdc.issuer
      && op.asset_code === assets.phpt.code && op.asset_issuer === assets.phpt.issuer
      && Number(op.amount) > 0 && Number(op.amount) >= Number(op.destination_min))
}

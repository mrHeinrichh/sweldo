import { Asset, StrKey } from '@stellar/stellar-sdk'
import { tryUnits } from '../state/amount.ts'

export type PayrollAssetOption = { id: string; label: string; asset: Asset }

export function payrollAssetOptions(code: string, issuer: string): PayrollAssetOption[] {
  const options = [{ id: 'native', label: 'XLM (Testnet)', asset: Asset.native() }]
  if (code === 'USDC' && StrKey.isValidEd25519PublicKey(issuer)) {
    options.push({ id: `USDC:${issuer}`, label: 'Test-USDC', asset: new Asset('USDC', issuer) })
  }
  return options
}

export type PayoutTotal = { asset: string; assetCode: string; units: bigint }

/** Keep issuers distinct: a currency code alone does not identify an asset. */
export function payoutTotals(payouts: { asset: string; amount: string }[]): PayoutTotal[] {
  const totals = new Map<string, PayoutTotal>()
  for (const payout of payouts) {
    const previous = totals.get(payout.asset)
    totals.set(payout.asset, {
      asset: payout.asset,
      assetCode: payout.asset === 'native' ? 'XLM' : payout.asset.split(':')[0],
      units: (previous?.units ?? 0n) + (tryUnits(payout.amount) ?? 0n),
    })
  }
  return [...totals.values()]
}

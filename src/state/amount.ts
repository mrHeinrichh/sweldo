import { amountString, amountUnits } from '../lib/claim-convert'

// Exact Stellar amount arithmetic in stroops, as in the Flutter `Amount`.

export { amountString, amountUnits }

/** Like `amountUnits` but returns null; accepts whitespace and thousands separators. */
export function tryUnits(value: string): bigint | null {
  const cleaned = value.trim().replace(/,/g, '')
  if (!cleaned) return null
  try {
    return amountUnits(cleaned.startsWith('.') ? `0${cleaned}` : cleaned)
  } catch {
    return null
  }
}

/** Splits a total evenly across payouts, rounding down to the stroop. */
export function perPayout(total: string, payouts: number) {
  const units = tryUnits(total)
  if (units === null || payouts < 1) return '0'
  return amountString(units / BigInt(payouts))
}

const display = new Intl.NumberFormat('en-US', { maximumFractionDigits: 7 })

/** Human display with grouping and up to 7 decimals. */
export function formatAmount(value: string | number | null | undefined) {
  const number = typeof value === 'number' ? value : Number(String(value ?? '0').replace(/,/g, ''))
  return display.format(Number.isFinite(number) ? number : 0)
}

export const formatUnits = (units: bigint) => formatAmount(amountString(units))

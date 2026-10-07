// Translates any failure into copy that says what happened and what to do.
// Same wording as sweldo_flutter/lib/core/error/error_messages.dart.

type ResultCodes = { transaction?: string; operations?: string[] }

export function resultCodes(error: unknown): ResultCodes | null {
  const codes = (error as { response?: { data?: { extras?: { result_codes?: ResultCodes } } } })?.response?.data?.extras?.result_codes
  return codes ?? null
}

export function isNotFound(error: unknown) {
  const status = (error as { response?: { status?: number } })?.response?.status
  return status === 404 || (error as { name?: string })?.name === 'NotFoundError'
}

function rejectedMessage(codes: string[]) {
  if (codes.includes('op_underfunded') || codes.includes('tx_insufficient_balance')) {
    return "This wallet doesn't hold enough to lock that payroll, including a 1 XLM reserve per payout. Lower the amount or fund the wallet."
  }
  if (codes.includes('op_no_trust') || codes.includes('op_src_no_trust')) {
    return 'A wallet in this payroll has no trustline for the asset. Enable the asset first.'
  }
  if (codes.includes('op_cannot_claim')) return 'This payout is still locked, or this wallet cannot claim it.'
  if (codes.includes('op_does_not_exist')) return 'That payout was already claimed or cancelled. Refresh the list.'
  if (codes.includes('tx_bad_seq')) return 'Your wallet sent another transaction meanwhile. Try again.'
  if (codes.includes('tx_too_late')) return 'The transaction expired before it was signed. Try again.'
  return null
}

export function friendlyError(error: unknown): string {
  if (isNotFound(error)) return "This wallet isn't on Stellar Testnet yet. Use “Get free test XLM”, then try again."
  const codes = resultCodes(error)
  if (codes) {
    const all = [codes.transaction, ...(codes.operations ?? []).filter((code) => code !== 'op_success')].filter(Boolean) as string[]
    return rejectedMessage(all) ?? `Stellar rejected the transaction (${all.join(', ')}).`
  }
  const status = (error as { response?: { status?: number } })?.response?.status
  if (status === 429) return 'Stellar Testnet is rate-limiting requests. Wait a few seconds and retry.'
  if (error instanceof TypeError && /fetch|network/i.test(error.message)) {
    return "Couldn't reach Stellar Testnet. Check your connection and retry."
  }
  if ((error as { message?: string })?.message === 'Network Error') {
    return "Couldn't reach Stellar Testnet. Check your connection and retry."
  }
  return error instanceof Error ? error.message : String(error)
}

/** Mapping used by the claim-and-convert flow. */
export function conversionError(error: unknown): string {
  const codes = resultCodes(error)
  if (codes) {
    const ops = codes.operations ?? []
    const tx = codes.transaction
    if (ops.includes('op_under_dest_min')) return 'The PHPT rate moved beyond the 1% limit. Nothing was claimed or converted. Refresh the quote.'
    if (ops.includes('op_too_few_offers')) return 'There is no longer enough liquidity. Nothing was claimed or converted. Refresh the quote.'
    if (ops.includes('op_low_reserve') || tx === 'tx_insufficient_balance') return 'Not enough test XLM for trustline reserves and fees. Fund the worker wallet and retry.'
    if (ops.some((code) => ['op_no_trust', 'op_src_no_trust', 'op_line_full', 'op_not_authorized', 'op_src_not_authorized'].includes(code))) {
      return 'Check the test-USDC and PHPT trustline authorization and limits. Nothing was claimed or converted.'
    }
    if (ops.includes('op_cannot_claim')) return 'The payout is locked or this wallet cannot claim it. Refresh your pay list.'
    if (ops.includes('op_does_not_exist')) return 'The payout was already claimed or cancelled. Refresh your pay list.'
    if (tx === 'tx_too_late') return 'Your quote expired while signing. Nothing was claimed. Refresh the quote.'
    if (tx === 'tx_bad_seq') return 'Your wallet changed while signing. Refresh the quote and try again.'
    const all = [tx, ...ops.filter((code) => code !== 'op_success')].filter(Boolean)
    return `Stellar rejected the transaction (${all.join(', ')}). No payout operations were applied.`
  }
  return friendlyError(error)
}

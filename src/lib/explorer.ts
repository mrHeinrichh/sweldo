import { StrKey, xdr } from '@stellar/stellar-sdk'

const EXPLORER = 'https://stellar.expert/explorer/testnet'

/** Stellar Expert expects a B… StrKey, while Horizon returns a 36-byte XDR ID. */
export function claimableBalanceExplorerId(id: string): string {
  if (StrKey.isValidClaimableBalance(id)) return id
  const hex = id.toLowerCase()
  const canonical = /^[a-f0-9]{64}$/.test(hex) ? `00000000${hex}` : hex
  if (!/^00000000[a-f0-9]{64}$/.test(canonical)) throw new Error('Invalid claimable balance ID')
  // StrKey carries a one-byte version discriminant; XDR uses four bytes.
  const bytes = xdr.ClaimableBalanceId.fromXDR(canonical, 'hex').toXDR()
  return StrKey.encodeClaimableBalance(bytes.subarray(3))
}

export const explorer = {
  home: EXPLORER,
  transaction: (hash: string) => `${EXPLORER}/tx/${hash}`,
  claimableBalance: (id: string) => `${EXPLORER}/claimable-balance/${claimableBalanceExplorerId(id)}`,
  contract: (id: string) => `${EXPLORER}/contract/${id}`,
  account: (id: string) => `${EXPLORER}/account/${id}`,
}

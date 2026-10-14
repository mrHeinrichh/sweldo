export type WalletKind = 'freighter-extension' | 'freighter-mobile' | 'xbull'

export type WalletAccount = {
  address: string
  /** Reported network, or the explicitly requested Testnet network for xBull. */
  network: string
  networkPassphrase?: string
}

export type WalletState = WalletAccount & { kind: WalletKind }

export type WalletKind = 'freighter-extension' | 'freighter-mobile'

export type WalletAccount = {
  address: string
  /** Freighter's network name: TESTNET or PUBLIC. */
  network: string
  networkPassphrase?: string
}

export type WalletState = WalletAccount & { kind: WalletKind }

import { Networks } from '@stellar/stellar-sdk'
import { connectExtension, extensionAccount, restoreExtension, signWithExtension } from './freighter-extension'
import {
  connectMobile,
  disconnectMobile,
  isMobileBrowser,
  mobileAccount,
  onMobileDisconnect,
  restoreMobile,
  signWithMobile,
  walletConnectProjectId,
} from './walletconnect'
import type { WalletAccount, WalletKind, WalletState } from './types'

export type { WalletAccount, WalletKind, WalletState } from './types'
export { FREIGHTER_MISSING, FreighterMissingError } from './freighter-extension'
export { freighterDeepLink, isMobileBrowser, walletConnectProjectId } from './walletconnect'

// One place that knows which Freighter is connected. Everything that signs
// goes through `signXdr`, so features never care whether the signature came
// from the browser extension or the phone app.

const LAST_WALLET_KEY = 'sweldo-last-wallet-v1'
let active: WalletKind | null = null

export function mobileAvailable() {
  return walletConnectProjectId().length > 0
}

export async function connect(kind: WalletKind, options: { onPairingUri?: (uri: string) => void; signal?: AbortSignal } = {}): Promise<WalletState> {
  const reason = unavailableReason(kind)
  if (reason) throw new Error(reason)
  const account = kind === 'freighter-mobile'
    ? await connectMobile(options.onPairingUri ?? (() => {}), options.signal)
    : await connectExtension()
  if (active === 'freighter-mobile' && kind !== 'freighter-mobile') await disconnectMobile()
  active = kind
  try { localStorage.setItem(LAST_WALLET_KEY, kind) } catch { /* storage may be blocked */ }
  return { ...account, kind }
}

/** Reconnects to the wallet used last time, without prompting. */
export async function restore(): Promise<WalletState | null> {
  let last: string | null = null
  try { last = localStorage.getItem(LAST_WALLET_KEY) } catch { /* ignore */ }
  if (last !== 'freighter-mobile' && last !== 'freighter-extension') return null
  if (!walletAvailable(last)) return null
  const account = last === 'freighter-mobile'
    ? await restoreMobile().catch(() => null)
    : await restoreExtension()
  if (!account) return null
  active = last
  return { ...account, kind: last }
}

export const WALLET_KINDS: Record<WalletKind, { title: string; description: string }> = {
  'freighter-extension': { title: 'Freighter extension', description: 'Sign in this browser with the Freighter extension.' },
  'freighter-mobile': { title: 'Freighter app', description: 'Approve each payroll action in Freighter on your phone.' },
}

/** Why a wallet can't be used here, phrased as what to do about it. */
export function unavailableReason(kind: WalletKind): string | null {
  if (kind === 'freighter-extension') {
    return isMobileBrowser() ? 'Browser extensions aren’t available on phones. Use the Freighter app.' : null
  }
  return mobileAvailable() ? null : 'Pairing with the Freighter app isn’t switched on for this version of Sweldo yet.'
}

export function walletAvailable(kind: WalletKind) {
  return unavailableReason(kind) === null
}

export async function disconnect() {
  if (active === 'freighter-mobile') await disconnectMobile()
  active = null
  try { localStorage.removeItem(LAST_WALLET_KEY) } catch { /* ignore */ }
}

export function onWalletDisconnected(listener: () => void) {
  return onMobileDisconnect(() => {
    if (active === 'freighter-mobile') active = null
    listener()
  })
}

/** The connected wallet's current account and network, re-read before sensitive signatures. */
export async function currentAccount(): Promise<WalletAccount> {
  if (active === 'freighter-mobile') return mobileAccount()
  if (active === 'freighter-extension') return extensionAccount()
  throw new Error('Connect Freighter to continue.')
}

export async function signXdr(xdr: string, address: string, networkPassphrase: string = Networks.TESTNET) {
  if (active === 'freighter-mobile') return signWithMobile(xdr)
  if (active === 'freighter-extension') return signWithExtension(xdr, address, networkPassphrase)
  throw new Error('Connect Freighter to continue.')
}

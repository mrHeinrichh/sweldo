import { Networks } from '@stellar/stellar-sdk'
import { connectExtension, extensionAccount, signWithExtension } from './freighter-extension'
import {
  connectMobile,
  disconnectMobile,
  mobileAccount,
  onMobileDisconnect,
  restoreMobile,
  signWithMobile,
  walletConnectProjectId,
} from './walletconnect'
import type { WalletAccount, WalletKind, WalletState } from './types'

export type { WalletAccount, WalletKind, WalletState } from './types'
export { FREIGHTER_MISSING } from './freighter-extension'
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
  const account = kind === 'freighter-mobile'
    ? await connectMobile(options.onPairingUri ?? (() => {}), options.signal)
    : await connectExtension()
  if (active === 'freighter-mobile' && kind !== 'freighter-mobile') await disconnectMobile()
  active = kind
  try { localStorage.setItem(LAST_WALLET_KEY, kind) } catch { /* storage may be blocked */ }
  return { ...account, kind }
}

/** Brings back a Freighter Mobile session from an earlier visit, silently. */
export async function restore(): Promise<WalletState | null> {
  let last: string | null = null
  try { last = localStorage.getItem(LAST_WALLET_KEY) } catch { /* ignore */ }
  if (last !== 'freighter-mobile') return null
  const account = await restoreMobile().catch(() => null)
  if (!account) return null
  active = 'freighter-mobile'
  return { ...account, kind: 'freighter-mobile' }
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
  return extensionAccount()
}

// "Approve in Freighter" prompts while a phone signature is pending.
type ApprovalListener = (pending: boolean) => void
const approvalListeners = new Set<ApprovalListener>()
export function onPendingApproval(listener: ApprovalListener) {
  approvalListeners.add(listener)
  return () => approvalListeners.delete(listener)
}

export async function signXdr(xdr: string, address: string, networkPassphrase: string = Networks.TESTNET) {
  if (active === 'freighter-mobile') {
    approvalListeners.forEach((listener) => listener(true))
    try {
      return await signWithMobile(xdr)
    } finally {
      approvalListeners.forEach((listener) => listener(false))
    }
  }
  return signWithExtension(xdr, address, networkPassphrase)
}

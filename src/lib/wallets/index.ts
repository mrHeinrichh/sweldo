import { Networks } from '@stellar/stellar-sdk'
import { restoreExtension } from './freighter-extension'
import { connectKit, currentKitAccount, signKit } from './kit'
import { requireTestnetAccount, reviewedTransaction, verifiedSignature } from './signing'
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
export { freighterDeepLink, freighterStoreName, freighterStoreUrl, isMobileBrowser, openFreighter, walletConnectProjectId } from './walletconnect'

// All payroll signatures use the same account, Testnet and envelope checks.

const LAST_WALLET_KEY = 'sweldo-last-wallet-v1'
let active: WalletKind | null = null
let connectionVersion = 0

export function mobileAvailable() {
  return walletConnectProjectId().length > 0
}

export async function connect(kind: WalletKind, options: { onPairingUri?: (uri: string) => void; signal?: AbortSignal } = {}): Promise<WalletState> {
  const version = ++connectionVersion
  const reason = unavailableReason(kind)
  if (reason) throw new Error(reason)
  const account = kind === 'freighter-mobile'
    ? await connectMobile(options.onPairingUri ?? (() => {}), options.signal)
    : await connectKit(kind, options.signal)
  if (options.signal?.aborted || version !== connectionVersion) throw new DOMException('Connection cancelled.', 'AbortError')
  if (active === 'freighter-mobile' && kind !== 'freighter-mobile') await disconnectMobile()
  active = kind
  try { localStorage.setItem(LAST_WALLET_KEY, kind) } catch { /* storage may be blocked */ }
  return { ...account, kind }
}

/** Reconnects to the wallet used last time, without prompting. */
export async function restore(): Promise<WalletState | null> {
  const version = connectionVersion
  let last: string | null = null
  try { last = localStorage.getItem(LAST_WALLET_KEY) } catch { /* ignore */ }
  if (last !== 'freighter-mobile' && last !== 'freighter-extension') return null
  if (!walletAvailable(last)) return null
  const account = last === 'freighter-mobile'
    ? await restoreMobile().catch(() => null)
    : await restoreExtension()
  if (!account || version !== connectionVersion) return null
  active = last
  return { ...account, kind: last }
}

export const WALLET_KINDS: Record<WalletKind, { title: string; description: string }> = {
  'freighter-extension': { title: 'Freighter extension', description: 'Sign in this browser with the Freighter extension.' },
  'freighter-mobile': { title: 'Freighter app', description: 'Approve each payroll action in Freighter on your phone.' },
  xbull: { title: 'xBull', description: 'Connect your xBull wallet on Stellar Testnet.' },
}

/** Why a wallet can't be used here, phrased as what to do about it. */
export function unavailableReason(kind: WalletKind): string | null {
  if (kind === 'xbull') return null
  if (kind === 'freighter-extension') {
    return isMobileBrowser() ? 'Browser extensions aren’t available on phones. Use the Freighter app.' : null
  }
  return mobileAvailable() ? null : 'Pairing with the Freighter app isn’t switched on for this version of Sweldo yet.'
}

export function walletAvailable(kind: WalletKind) {
  return unavailableReason(kind) === null
}

export async function disconnect() {
  connectionVersion += 1
  if (active === 'freighter-mobile') await disconnectMobile()
  active = null
  try { localStorage.removeItem(LAST_WALLET_KEY) } catch { /* ignore */ }
}

export function onWalletDisconnected(listener: () => void) {
  return onMobileDisconnect(() => {
    if (active !== 'freighter-mobile') return
    active = null
    listener()
  })
}

/** The connected wallet's current account and network, re-read before sensitive signatures. */
export async function currentAccount(): Promise<WalletAccount> {
  if (active === 'freighter-mobile') return mobileAccount()
  if (active === 'freighter-extension' || active === 'xbull') return currentKitAccount(active)
  throw new Error('Connect a wallet to continue.')
}

export async function signXdr(xdr: string, address: string, networkPassphrase: string = Networks.TESTNET) {
  const selected = active
  const version = connectionVersion
  reviewedTransaction(xdr, address, networkPassphrase)
  let signed: string
  if (selected === 'freighter-mobile') {
    requireTestnetAccount(mobileAccount(), address)
    signed = verifiedSignature(xdr, await signWithMobile(xdr), address)
  } else if (selected === 'freighter-extension' || selected === 'xbull') {
    signed = await signKit(xdr, address, networkPassphrase, selected)
  } else {
    throw new Error('Connect a wallet to continue.')
  }
  if (version !== connectionVersion || active !== selected) throw new Error('The connected wallet changed while signing. Nothing was submitted.')
  return signed
}

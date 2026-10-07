import { getAddress, getNetwork, isAllowed, isConnected, requestAccess, setAllowed, signTransaction } from '@stellar/freighter-api'
import type { WalletAccount } from './types'

// The Freighter browser extension, reached through @stellar/freighter-api.

type FreighterError = { code?: number; message?: string; ext?: string[] }

function unwrap<T>(result: { error?: FreighterError } & T, label: string): T {
  if (result.error) {
    const detail = result.error.message || result.error.ext?.join(', ') || `error ${result.error.code ?? 'unknown'}`
    throw new Error(`${label}: ${detail}`)
  }
  return result
}

function withTimeout<T>(promise: Promise<T>, milliseconds: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      window.setTimeout(() => reject(new Error('Freighter did not respond. Unlock the extension and try again.')), milliseconds)
    }),
  ])
}

function wait(milliseconds: number) {
  return new Promise((resolve) => window.setTimeout(resolve, milliseconds))
}

export const FREIGHTER_MISSING =
  'Freighter is not available. Install it from freighter.app, or open chrome://extensions, enable Freighter, set Site access to “On all sites”, unlock it, then reload this tab.'

/** Raised when no Freighter extension could be reached at all. */
export class FreighterMissingError extends Error {
  readonly walletMissing = true
  constructor() { super(FREIGHTER_MISSING) }
}

async function detectFreighter(): Promise<boolean> {
  // The extension injects its content script after page load, so a single early check can miss it.
  const deadline = Date.now() + 4_000
  do {
    try {
      const connection = await withTimeout(isConnected(), 1_500)
      if (!connection.error && connection.isConnected) return true
    } catch {
      // not ready yet; retry
    }
    await wait(400)
  } while (Date.now() < deadline)
  return false
}

export async function connectExtension(): Promise<WalletAccount> {
  // If detection fails we still call requestAccess below: it talks to the extension directly
  // and surfaces a precise error (locked, denied, or truly missing).
  const detected = await detectFreighter()

  let accessResult
  try {
    accessResult = await withTimeout(requestAccess(), 30_000)
  } catch (error) {
    if (!detected) throw new FreighterMissingError()
    throw error
  }
  const access = unwrap(accessResult, 'Could not connect Freighter')
  let address = access.address

  if (!address) {
    // Some Freighter builds answer requestAccess without a key until this site is on the allow list.
    // Allow the site, then read the active account directly.
    try {
      const allowed = await withTimeout(isAllowed(), 3_000)
      if (!allowed.isAllowed) await withTimeout(setAllowed(), 30_000)
      const active = await withTimeout(getAddress(), 5_000)
      if (!active.error) address = active.address
    } catch {
      // fall through to the error below
    }
  }
  const network = unwrap(await withTimeout(getNetwork(), 5_000), 'Could not read wallet network')
  if (!address) throw new Error('Freighter did not return an account. Open the Freighter popup, unlock it, make sure an account is selected, approve the connection request for this site, then try again.')
  return { address, network: network.network, networkPassphrase: network.networkPassphrase }
}

/** The extension's active account and network, without prompting. */
export async function extensionAccount(): Promise<WalletAccount> {
  const active = unwrap(await withTimeout(getAddress(), 5_000), 'Could not read the Freighter account')
  if (!active.address) throw new Error('Freighter is locked. Unlock it and reconnect.')
  const network = unwrap(await withTimeout(getNetwork(), 5_000), 'Could not read wallet network')
  return { address: active.address, network: network.network, networkPassphrase: network.networkPassphrase }
}

/** Reconnects silently when this site is already on Freighter's allow list. */
export async function restoreExtension(): Promise<WalletAccount | null> {
  if (!(await detectFreighter())) return null
  try {
    const allowed = await withTimeout(isAllowed(), 3_000)
    if (!allowed.isAllowed) return null
    return await extensionAccount()
  } catch {
    return null
  }
}

export async function signWithExtension(xdr: string, address: string, networkPassphrase: string) {
  const signed = unwrap(
    await withTimeout(signTransaction(xdr, { address, networkPassphrase }), 5 * 60_000),
    'Freighter could not sign the transaction',
  )
  if (!signed.signedTxXdr) throw new Error('Signing was cancelled. Nothing was submitted.')
  return signed.signedTxXdr
}

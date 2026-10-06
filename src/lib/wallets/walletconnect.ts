import SignClient from '@walletconnect/sign-client'
import { getSdkError } from '@walletconnect/utils'
import type { SessionTypes } from '@walletconnect/types'
import type { WalletAccount } from './types'

// Freighter Mobile over WalletConnect v2. Freighter Mobile implements the
// `stellar` namespace: `stellar_signXDR` takes `{ xdr }` and returns
// `{ signedXDR }`, on the `stellar:testnet` chain. Its deep-link scheme is
// `freighterwallet://`.

const NAMESPACE = 'stellar'
export const TESTNET_CHAIN = 'stellar:testnet'
const SIGN_METHOD = 'stellar_signXDR'

export function walletConnectProjectId() {
  return import.meta.env.VITE_WALLETCONNECT_PROJECT_ID?.trim() ?? ''
}

export function isMobileBrowser() {
  return /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)
}

/** Opens Freighter Mobile, with a pairing link when one is given. */
export function freighterDeepLink(pairingUri?: string) {
  return pairingUri ? `freighterwallet://wc?uri=${encodeURIComponent(pairingUri)}` : 'freighterwallet://'
}

let clientPromise: Promise<SignClient> | null = null
let session: SessionTypes.Struct | null = null
const disconnectListeners = new Set<() => void>()

function client() {
  const projectId = walletConnectProjectId()
  if (!projectId) throw new Error('Freighter Mobile needs a WalletConnect project ID in VITE_WALLETCONNECT_PROJECT_ID.')
  clientPromise ??= SignClient.init({
    projectId,
    metadata: {
      name: 'Sweldo',
      description: 'Payroll locked on Stellar. Claim pay on payday.',
      url: window.location.origin,
      icons: [`${window.location.origin}/favicon.svg`],
    },
  }).then((instance) => {
    const dropped = ({ topic }: { topic: string }) => {
      if (session?.topic !== topic) return
      session = null
      disconnectListeners.forEach((listener) => listener())
    }
    instance.on('session_delete', dropped)
    instance.on('session_expire', dropped)
    return instance
  })
  return clientPromise
}

function toAccount(active: SessionTypes.Struct): WalletAccount {
  const accounts = active.namespaces[NAMESPACE]?.accounts ?? []
  // CAIP-10: stellar:<network>:<address>
  const parsed = accounts.map((account) => account.split(':')).filter((parts) => parts.length === 3)
  const pick = parsed.find((parts) => `${parts[0]}:${parts[1]}` === TESTNET_CHAIN) ?? parsed[0]
  if (!pick) throw new Error('Freighter did not share a Stellar account. Try pairing again.')
  const testnet = `${pick[0]}:${pick[1]}` === TESTNET_CHAIN
  return { address: pick[2], network: testnet ? 'TESTNET' : 'PUBLIC' }
}

export function onMobileDisconnect(listener: () => void) {
  disconnectListeners.add(listener)
  return () => disconnectListeners.delete(listener)
}

/** Reconnects to a Freighter Mobile session from a previous visit. */
export async function restoreMobile(): Promise<WalletAccount | null> {
  if (!walletConnectProjectId()) return null
  const instance = await client()
  const existing = instance.session.getAll().find((item) => item.namespaces[NAMESPACE])
  if (!existing) return null
  session = existing
  return toAccount(existing)
}

/**
 * Starts pairing. `onUri` receives the WalletConnect URI to show as a QR
 * code or open as a deep link; the promise resolves once Freighter approves.
 */
export async function connectMobile(onUri: (uri: string) => void, signal?: AbortSignal): Promise<WalletAccount> {
  const instance = await client()
  const { uri, approval } = await instance.connect({
    optionalNamespaces: {
      [NAMESPACE]: {
        chains: [TESTNET_CHAIN],
        methods: [SIGN_METHOD, 'stellar_signAndSubmitXDR'],
        events: ['accountsChanged'],
      },
    },
  })
  if (uri) onUri(uri)
  const approved = await new Promise<SessionTypes.Struct>((resolve, reject) => {
    signal?.addEventListener('abort', () => reject(new DOMException('Pairing cancelled.', 'AbortError')))
    approval().then(resolve, (error: unknown) => {
      const message = (error as { message?: string })?.message ?? ''
      reject(new Error(/reject/i.test(message)
        ? 'You declined the connection in Freighter.'
        : `Freighter did not connect: ${message || 'the request expired'}`))
    })
  })
  session = approved
  return toAccount(approved)
}

export function mobileAccount(): WalletAccount {
  if (!session) throw new Error('The Freighter app is not connected. Pair it again.')
  return toAccount(session)
}

export async function signWithMobile(xdr: string) {
  const instance = await client()
  if (!session) throw new Error('The Freighter app is not connected. Pair it again.')
  try {
    const result = await instance.request<{ signedXDR?: string }>({
      topic: session.topic,
      chainId: TESTNET_CHAIN,
      request: { method: SIGN_METHOD, params: { xdr } },
    })
    if (!result?.signedXDR) throw new Error('Freighter returned no signature. Nothing was submitted.')
    return result.signedXDR
  } catch (error) {
    const message = (error as { message?: string })?.message ?? ''
    if (/reject/i.test(message)) throw new Error('You declined the request in Freighter. Nothing was submitted.')
    throw error instanceof Error ? error : new Error(message || 'Freighter could not sign the transaction.')
  }
}

export async function disconnectMobile() {
  const active = session
  session = null
  if (!active || !clientPromise) return
  try {
    const instance = await clientPromise
    await instance.disconnect({ topic: active.topic, reason: getSdkError('USER_DISCONNECTED') })
  } catch {
    // The relay may already have dropped the session.
  }
}

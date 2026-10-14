import { Networks } from '@stellar/stellar-sdk'
import { FreighterMissingError } from './freighter-extension'
import { kitAccount, signWithKit, type KitTransport, type KitWalletKind } from './signing'

let kitPromise: Promise<KitTransport> | null = null

function walletError(error: unknown): Error {
  if (error instanceof Error) return error
  const message = (error as { message?: string })?.message
  return new Error(message || 'The wallet request was cancelled or unavailable. Nothing was submitted.')
}

async function bounded<T>(request: Promise<T>, milliseconds: number, signal?: AbortSignal): Promise<T> {
  if (signal?.aborted) throw new DOMException('Connection cancelled.', 'AbortError')
  let timer: ReturnType<typeof setTimeout> | undefined
  let abort: (() => void) | undefined
  try {
    return await Promise.race([
      request,
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('The wallet did not respond. Unlock it and try again.')), milliseconds)
        abort = () => reject(new DOMException('Connection cancelled.', 'AbortError'))
        signal?.addEventListener('abort', abort, { once: true })
      }),
    ])
  } catch (error) {
    throw walletError(error)
  } finally {
    clearTimeout(timer)
    if (abort) signal?.removeEventListener('abort', abort)
  }
}

/** Load only the two scoped kit modules, and only when a wallet is used. */
async function transport(): Promise<KitTransport> {
  kitPromise ??= (async () => {
    const { StellarWalletsKit } = await import('@creit.tech/stellar-wallets-kit/sdk')
    const { FreighterModule } = await import('@creit.tech/stellar-wallets-kit/modules/freighter')
    const { xBullModule } = await import('@creit.tech/stellar-wallets-kit/modules/xbull')
    StellarWalletsKit.init({ modules: [new FreighterModule(), new xBullModule()], network: Networks.TESTNET })
    const api: KitTransport = {
      async address(kind, requestAccess) {
        StellarWalletsKit.setWallet(kind === 'xbull' ? 'xbull' : 'freighter')
        if (kind === 'freighter-extension' && !await StellarWalletsKit.selectedModule.isAvailable()) throw new FreighterMissingError()
        return requestAccess
          ? StellarWalletsKit.fetchAddress()
          : StellarWalletsKit.selectedModule.getAddress({ skipRequestAccess: true })
      },
      network: () => StellarWalletsKit.getNetwork(),
      sign: (xdr, options) => StellarWalletsKit.signTransaction(xdr, options),
    }
    return api
  })().catch((error) => { kitPromise = null; throw walletError(error) })
  return kitPromise
}

export async function connectKit(kind: KitWalletKind, signal?: AbortSignal) {
  const api = await transport()
  if (signal?.aborted) throw new DOMException('Connection cancelled.', 'AbortError')
  return bounded(kitAccount(api, kind, true), 120_000, signal)
}

export async function currentKitAccount(kind: KitWalletKind) {
  return bounded(kitAccount(await transport(), kind), 120_000)
}

export async function signKit(xdr: string, address: string, networkPassphrase: string, kind: KitWalletKind) {
  return bounded(signWithKit(await transport(), kind, xdr, address, networkPassphrase), 5 * 60_000)
}

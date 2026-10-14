import { connectKit, currentKitAccount, signKit } from '../src/lib/wallets/kit'
import type { KitWalletKind } from '../src/lib/wallets/signing'

type Request = { action: string; kind: KitWalletKind; xdr?: string; address?: string; networkPassphrase?: string }

// The same Kit implementation is used by React, Flutter web and the native
// wallet-only approval window. This bridge never submits transactions.
Object.assign(window, {
  SweldoWallets: {
    async call(payload: string): Promise<string> {
      try {
        const request = JSON.parse(payload) as Request
        if (!['xbull', 'freighter-extension'].includes(request.kind)) throw new Error('Unsupported wallet.')
        if (request.action === 'connect') return JSON.stringify({ ok: true, ...(await connectKit(request.kind)) })
        if (request.action === 'current') return JSON.stringify({ ok: true, ...(await currentKitAccount(request.kind)) })
        if (request.action === 'sign' && request.xdr && request.address && request.networkPassphrase) {
          return JSON.stringify({ ok: true, xdr: await signKit(request.xdr, request.address, request.networkPassphrase, request.kind) })
        }
        throw new Error('Unsupported wallet request.')
      } catch (error) {
        return JSON.stringify({ ok: false, error: error instanceof Error ? error.message : 'The wallet request failed. Nothing was submitted.' })
      }
    },
  },
})

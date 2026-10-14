import { randomBytes, timingSafeEqual } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { pathToFileURL } from 'node:url'
import { Asset, Horizon, Keypair, Networks, Operation, StrKey, TransactionBuilder } from '@stellar/stellar-sdk'

export const FAUCET_PATH = '/__sweldo_local/test-usdc'
const amount = '25'
const loopbackHosts = new Set(['localhost', '127.0.0.1', '[::1]', '10.0.2.2'])
const loopback = (value = '') => value === '::1' || /^(::ffff:)?127\./.test(value)
const localUrl = (value) => {
  try { const url = new URL(value); return url.protocol === 'http:' && !url.username && !url.password && loopbackHosts.has(url.hostname) } catch { return false }
}

class FaucetError extends Error {
  constructor(status, message) { super(message); this.status = status }
}

/** Only the dev server reads the disposable issuer key. It is never part of client code. */
export function controlledTestUsdc(root, expectedIssuer, dependencies = {}) {
  const server = dependencies.server ?? new Horizon.Server('https://horizon-testnet.stellar.org')
  const read = dependencies.readFile ?? readFile
  const asset = new Asset('USDC', expectedIssuer)
  const pending = new Map()
  const recent = new Map()
  let queue = Promise.resolve()
  return async (address) => {
    const previous = pending.get(address)
    if (previous) return previous
    const run = queue.catch(() => {}).then(async () => {
      const old = recent.get(address)
      if (old?.receipt.status === 'pending') return old.receipt
      const evidence = JSON.parse(await read(new URL('.sweldo-local/week1-result.json', root), 'utf8'))
      if (evidence.network !== 'Stellar Testnet' || evidence.assets?.usdc?.issuer !== expectedIssuer || evidence.assets?.usdc?.code !== 'USDC') {
        throw new FaucetError(503, 'The controlled Testnet asset configuration does not match this app.')
      }
      const destination = await server.loadAccount(address).catch((error) => {
        if (error?.response?.status === 404 || error?.name === 'NotFoundError') throw new FaucetError(409, 'Fund this wallet with free test XLM first.')
        throw new FaucetError(503, 'Stellar Testnet is unavailable. Try again later.')
      })
      const line = destination.balances.find((balance) => balance.asset_code === 'USDC' && balance.asset_issuer === expectedIssuer)
      if (!line) throw new FaucetError(409, 'Enable USDC in this wallet first.')
      if (Number(line.balance) - Number(line.selling_liabilities ?? 0) >= 25) return { status: 'already-funded', amount: '0' }
      if (old && Date.now() - old.at < 60_000) throw new FaucetError(429, 'This wallet received test-USDC recently. Wait a minute before requesting more.')

      const state = JSON.parse(await read(new URL('.sweldo-local/week1-testnet.json', root), 'utf8'))
      if (state.network !== 'Stellar Testnet' || state.accounts?.usdcIssuer?.publicKey !== expectedIssuer) {
        throw new FaucetError(503, 'The local Testnet issuer is unavailable.')
      }
      const key = Keypair.fromSecret(state.accounts.usdcIssuer.secret)
      if (key.publicKey() !== expectedIssuer) throw new FaucetError(503, 'The local Testnet issuer is unavailable.')
      const transaction = new TransactionBuilder(await server.loadAccount(expectedIssuer), {
        fee: String(await server.fetchBaseFee()), networkPassphrase: Networks.TESTNET,
      }).addOperation(Operation.payment({ destination: address, asset, amount })).setTimeout(60).build()
      transaction.sign(key)
      const receipt = { status: 'pending', amount, hash: transaction.hash().toString('hex') }
      // Keep uncertain submissions blocked rather than creating another payment on retry.
      recent.set(address, { at: Number.POSITIVE_INFINITY, receipt })
      try {
        await server.submitTransaction(transaction)
      } catch (error) {
        if (error?.response?.data?.extras?.result_codes) {
          recent.delete(address)
          throw new FaucetError(409, 'Stellar rejected the test funding. Check the USDC trustline and test XLM balance.')
        }
        return receipt
      }
      receipt.status = 'funded'
      recent.set(address, { at: Date.now(), receipt })
      return receipt
    })
    queue = run
    pending.set(address, run)
    try { return await run } finally { pending.delete(address) }
  }
}

export function faucetMiddleware({ issuer, grant }) {
  const token = randomBytes(32).toString('hex')
  return async (request, response, next) => {
    if (request.url?.split('?')[0] !== FAUCET_PATH) return next()
    const send = (status, body) => {
      response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' })
      response.end(JSON.stringify(body))
    }
    const origin = request.headers.origin
    if (!loopback(request.socket.remoteAddress) || !localUrl(`http://${request.headers.host}`) || (origin && !localUrl(origin))) {
      return send(403, { error: 'The test faucet is available only from a local app.' })
    }
    if (origin) {
      response.setHeader('Access-Control-Allow-Origin', origin)
      response.setHeader('Vary', 'Origin')
    }
    if (request.method === 'OPTIONS') {
      response.setHeader('Access-Control-Allow-Methods', 'GET, POST')
      response.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Sweldo-Test-Faucet-Token')
      return send(204, null)
    }
    if (request.method === 'GET') return send(200, { network: 'Stellar Testnet', code: 'USDC', issuer, amount, token })
    if (request.method !== 'POST') return send(405, { error: 'Use GET or POST.' })
    const supplied = request.headers['x-sweldo-test-faucet-token']
    if (typeof supplied !== 'string' || !/^[a-f0-9]{64}$/.test(supplied) || !timingSafeEqual(Buffer.from(supplied), Buffer.from(token))) {
      return send(403, { error: 'Refresh the local app before requesting test funds.' })
    }
    if (!request.headers['content-type']?.startsWith('application/json')) return send(415, { error: 'Expected JSON.' })
    try {
      const chunks = []
      let size = 0
      for await (const chunk of request) {
        size += chunk.length
        if (size > 1024) throw new FaucetError(413, 'Request is too large.')
        chunks.push(chunk)
      }
      let body
      try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')) } catch { throw new FaucetError(400, 'Expected a public Stellar address.') }
      if (!body || typeof body !== 'object' || Object.keys(body).length !== 1 || typeof body.address !== 'string' || !StrKey.isValidEd25519PublicKey(body.address)) {
        throw new FaucetError(400, 'Expected only a public Stellar G address. Never send a secret key.')
      }
      const receipt = await grant(body.address)
      return send(receipt.status === 'pending' ? 202 : 200, { ...receipt, address: body.address, network: 'Stellar Testnet', code: 'USDC', issuer })
    } catch (error) {
      return send(error instanceof FaucetError ? error.status : 503, { error: error instanceof FaucetError ? error.message : 'The local Testnet faucet is unavailable. No success receipt was confirmed.' })
    }
  }
}

export function localTestFaucetPlugin() {
  return {
    name: 'sweldo-local-test-faucet',
    apply: 'serve',
    configureServer(server) {
      const { mode, env, root } = server.config
      if (mode !== 'week4' || env.VITE_ASSET_CODE !== 'USDC' || !StrKey.isValidEd25519PublicKey(env.VITE_ASSET_ISSUER ?? '')) return
      const base = pathToFileURL(root.endsWith('/') ? root : root + '/')
      server.middlewares.use(faucetMiddleware({ issuer: env.VITE_ASSET_ISSUER, grant: controlledTestUsdc(base, env.VITE_ASSET_ISSUER) }))
    },
  }
}

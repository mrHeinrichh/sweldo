import test from 'node:test'
import assert from 'node:assert/strict'
import { createServer, request as httpRequest } from 'node:http'
import { Account, Keypair, Networks } from '@stellar/stellar-sdk'
import { controlledTestUsdc, faucetMiddleware, FAUCET_PATH, localTestFaucetPlugin } from './local-test-faucet.mjs'

const issuer = Keypair.random()
const address = Keypair.random().publicKey()
const hash = 'a'.repeat(64)

async function endpoint(t, grant = async () => ({ status: 'funded', amount: '25', hash })) {
  const handle = faucetMiddleware({ issuer: issuer.publicKey(), grant })
  const server = createServer((req, res) => handle(req, res, () => { res.writeHead(404); res.end() }))
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve))
  t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve) }))
  const url = `http://127.0.0.1:${server.address().port}${FAUCET_PATH}`
  const status = await (await fetch(url)).json()
  const headers = { 'Content-Type': 'application/json', 'X-Sweldo-Test-Faucet-Token': status.token }
  return { url, status, headers }
}

test('reading local capabilities never funds a wallet or exposes an issuer secret', async (t) => {
  let calls = 0
  const { status } = await endpoint(t, async () => { calls++; assert.fail('GET must not fund') })
  assert.equal(calls, 0)
  assert.equal(status.network, 'Stellar Testnet')
  assert.equal(status.issuer, issuer.publicKey())
  assert.equal(status.amount, '25')
  assert.equal(JSON.stringify(status).includes(issuer.secret()), false)
})

test('only an explicit validated POST dispenses the fixed controlled test asset', async (t) => {
  let received
  const { url, headers } = await endpoint(t, async (target) => { received = target; return { status: 'funded', amount: '25', hash } })
  const response = await fetch(url, { method: 'POST', headers, body: JSON.stringify({ address }) })
  assert.equal(response.status, 200)
  assert.equal(received, address)
  assert.deepEqual(await response.json(), { status: 'funded', amount: '25', hash, address, network: 'Stellar Testnet', code: 'USDC', issuer: issuer.publicKey() })
})

test('external origins, hostnames and missing request tokens cannot dispense funds', async (t) => {
  const { url, headers } = await endpoint(t, async () => assert.fail('must not fund'))
  for (const extra of [{ Origin: 'https://untrusted.example' }, { Host: 'untrusted.example' }, { 'X-Sweldo-Test-Faucet-Token': 'wrong' }, { 'X-Sweldo-Test-Faucet-Token': String.fromCharCode(0xe9).repeat(64) }]) {
    const status = await new Promise((resolve, reject) => {
      const request = httpRequest(url, { method: 'POST', headers: { ...headers, ...extra } }, (response) => {
        response.resume()
        resolve(response.statusCode)
      })
      request.on('error', reject)
      request.end(JSON.stringify({ address }))
    })
    assert.equal(status, 403)
  }
})

test('local Flutter browser origins can read capabilities, but remote origins cannot', async (t) => {
  const { url } = await endpoint(t)
  const allowed = await fetch(url, { headers: { Origin: 'http://localhost:5180' } })
  assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:5180')
  const denied = await fetch(url, { headers: { Origin: 'https://untrusted.example' } })
  assert.equal(denied.status, 403)
  assert.equal(denied.headers.get('access-control-allow-origin'), null)
})

test('requests cannot choose amounts, issuers, secrets or invalid wallet addresses', async (t) => {
  const { url, headers } = await endpoint(t, async () => assert.fail('must not fund'))
  for (const body of [{ address, amount: '5000' }, { address, issuer: address }, { address: issuer.secret() }, { address: 123 }, null]) {
    const response = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) })
    assert.equal(response.status, 400)
  }
})

test('uncertain funding is reported as pending, never as confirmed success', async (t) => {
  const { url, headers } = await endpoint(t, async () => ({ status: 'pending', amount: '25', hash }))
  const response = await fetch(url, { method: 'POST', headers, body: JSON.stringify({ address }) })
  assert.equal(response.status, 202)
  assert.equal((await response.json()).status, 'pending')
})

test('the faucet is excluded from builds and from other Vite modes', () => {
  const plugin = localTestFaucetPlugin()
  assert.equal(plugin.apply, 'serve')
  for (const mode of ['production', 'week3', 'development']) plugin.configureServer({
    config: { mode, env: { VITE_ASSET_CODE: 'USDC', VITE_ASSET_ISSUER: issuer.publicKey() } },
    middlewares: { use: () => assert.fail('must not register a faucet') },
  })
})

function backend(overrides = {}) {
  const sent = []
  const evidence = { network: 'Stellar Testnet', assets: { usdc: { code: 'USDC', issuer: issuer.publicKey() } } }
  const state = { network: 'Stellar Testnet', accounts: { usdcIssuer: { publicKey: issuer.publicKey(), secret: issuer.secret() } } }
  const fake = {
    loadAccount: async (key) => key === issuer.publicKey() ? new Account(key, '1') : ({ balances: [{ asset_code: 'USDC', asset_issuer: issuer.publicKey(), balance: '0.0000000' }] }),
    fetchBaseFee: async () => '100',
    submitTransaction: async (transaction) => { sent.push(transaction); return { hash: transaction.hash().toString('hex') } },
    ...overrides,
  }
  const grant = controlledTestUsdc(new URL('file:///unused/'), issuer.publicKey(), {
    server: fake,
    readFile: async (url) => JSON.stringify(url.pathname.endsWith('week1-result.json') ? evidence : state),
  })
  return { grant, sent }
}

test('the backend only issues 25 controlled USDC on Testnet and deduplicates requests', async () => {
  const { grant, sent } = backend()
  const results = await Promise.all([grant(address), grant(address)])
  assert.equal(sent.length, 1)
  assert.equal(sent[0].networkPassphrase, Networks.TESTNET)
  assert.equal(sent[0].operations[0].destination, address)
  assert.equal(sent[0].operations[0].asset.getIssuer(), issuer.publicKey())
  assert.equal(sent[0].operations[0].amount, '25.0000000')
  assert.equal(results[0].status, 'funded')
  await assert.rejects(grant(address), /Wait a minute/)
  assert.equal(sent.length, 1)
})

test('trustlines and existing balances are checked before sending', async () => {
  const absent = backend({ loadAccount: async () => ({ balances: [] }) })
  await assert.rejects(absent.grant(address), /Enable USDC/)
  assert.equal(absent.sent.length, 0)
  const funded = backend({ loadAccount: async () => ({ balances: [{ asset_code: 'USDC', asset_issuer: issuer.publicKey(), balance: '25' }] }) })
  assert.equal((await funded.grant(address)).status, 'already-funded')
  assert.equal(funded.sent.length, 0)
})

test('an unconfirmed network submission is never automatically sent again', async () => {
  let submissions = 0
  const { grant } = backend({ submitTransaction: async () => { submissions++; throw new Error('network timeout') } })
  assert.equal((await grant(address)).status, 'pending')
  assert.equal((await grant(address)).status, 'pending')
  assert.equal(submissions, 1)
})

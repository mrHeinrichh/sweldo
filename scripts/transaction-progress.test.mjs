import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import { Account, Keypair } from '@stellar/stellar-sdk'
import { createServer } from 'vite'

const vite = await createServer({
  configFile: false,
  mode: 'test', logLevel: 'error',
  optimizeDeps: { noDiscovery: true, include: [] },
  server: { middlewareMode: true, hmr: false, ws: false, watch: null },
  plugins: [{
    name: 'transaction-progress-test-wallet', enforce: 'pre',
    resolveId(source, importer) {
      if (importer?.endsWith('/src/lib/stellar.ts') && source === './wallets') return '\0progress-wallet'
    },
    load(id) {
      if (id === '\0progress-wallet') return 'export const signXdr = (...args) => globalThis.__sweldoProgressSign(...args)'
    },
  }],
})
after(async () => {
  delete globalThis.__sweldoProgressSign
  await vite.close()
})
const { claimBalance, server } = await vite.ssrLoadModule('/src/lib/stellar.ts')
const address = Keypair.random().publicKey()
const balanceId = `00000000${'ab'.repeat(32)}`
const deferred = () => {
  let resolve
  const promise = new Promise((done) => { resolve = done })
  return { promise, resolve }
}
const turn = () => new Promise((resolve) => setImmediate(resolve))

test('progress advances only when account preparation, wallet approval and ledger submission finish', async () => {
  const account = deferred()
  const approval = deferred()
  const submission = deferred()
  const phases = []
  server.loadAccount = () => account.promise
  globalThis.__sweldoProgressSign = async (xdr) => { await approval.promise; return xdr }
  server.submitTransaction = () => submission.promise

  const result = claimBalance(address, balanceId, (phase) => phases.push(phase))
  assert.deepEqual(phases, ['preparing'])
  account.resolve(new Account(address, '1'))
  await turn()
  assert.deepEqual(phases, ['preparing', 'approval'])
  approval.resolve()
  await turn()
  assert.deepEqual(phases, ['preparing', 'approval', 'submitting'])
  submission.resolve({ hash: 'confirmed-hash' })
  assert.equal((await result).hash, 'confirmed-hash')
  assert.deepEqual(phases, ['preparing', 'approval', 'submitting', 'receipt'])
})

test('a rejected wallet approval never reports submission or receipt progress', async () => {
  const phases = []
  server.loadAccount = async () => new Account(address, '1')
  globalThis.__sweldoProgressSign = async () => { throw new Error('Approval cancelled') }
  server.submitTransaction = () => assert.fail('Rejected transactions must never submit')
  await assert.rejects(claimBalance(address, balanceId, (phase) => phases.push(phase)), /cancelled/)
  assert.deepEqual(phases, ['preparing', 'approval'])
})

test('a failed ledger submission never reports a completed receipt', async () => {
  const phases = []
  server.loadAccount = async () => new Account(address, '1')
  globalThis.__sweldoProgressSign = async (xdr) => xdr
  server.submitTransaction = async () => { throw new Error('Ledger unavailable') }
  await assert.rejects(claimBalance(address, balanceId, (phase) => phases.push(phase)), /unavailable/)
  assert.deepEqual(phases, ['preparing', 'approval', 'submitting'])
})

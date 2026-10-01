import assert from 'node:assert/strict'
import test from 'node:test'
import { Account, Asset, Keypair, Networks } from '@stellar/stellar-sdk'
import {
  amountUnits, buildClaimConversion, configuredConversion, conversionError,
  minimumReceived, quoteClaimConversion, supportsConversion,
} from '../src/lib/claim-convert.ts'

const address = (byte) => Keypair.fromRawEd25519Seed(Buffer.alloc(32, byte)).publicKey()
const worker = address(1)
const pair = { source: new Asset('USDC', address(2)), destination: new Asset('PHPT', address(3)) }
const balanceId = `00000000${'a'.repeat(64)}`
const now = Date.now()
const payout = {
  id: balanceId, balance_id: balanceId, asset: `${pair.source.code}:${pair.source.issuer}`, amount: '25',
  claimants: [{ destination: worker, predicate: { not: { abs_before: new Date(now - 60_000).toISOString() } } }],
}
const route = {
  source_asset_code: 'USDC', source_asset_issuer: pair.source.issuer, source_amount: '25.0000000',
  destination_asset_code: 'PHPT', destination_asset_issuer: pair.destination.issuer, destination_amount: '25.0000000', path: [],
}
function trustline(asset, extra = {}) {
  return { asset_type: 'credit_alphanum4', asset_code: asset.code, asset_issuer: asset.issuer,
    balance: '0', limit: '1000', buying_liabilities: '0', is_authorized: true, ...extra }
}
function account(balances = []) {
  return Object.assign(new Account(worker, '1'), { account_id: worker, balances })
}
function server({ record = payout, balances = [], routes = [route], time = now } = {}) {
  return {
    loadAccount: async () => account(balances),
    claimableBalances: () => ({ claimableBalance: () => ({ call: async () => record }) }),
    ledgers: () => ({ order: () => ({ limit: () => ({ call: async () => ({ records: [{ closed_at: new Date(time).toISOString() }] }) }) }) }),
    strictSendPaths: () => ({ call: async () => ({ records: routes }) }),
  }
}
async function quote(options) { return quoteClaimConversion(server(options), worker, balanceId, pair) }

test('claims and converts atomically, adding both missing trustlines first', async () => {
  const q = await quote()
  const tx = buildClaimConversion(account(), payout, q, '100')
  assert.deepEqual(tx.operations.map((op) => op.type), ['changeTrust', 'changeTrust', 'claimClaimableBalance', 'pathPaymentStrictSend'])
  assert.equal(tx.operations[2].balanceId, balanceId)
  const payment = tx.operations[3]
  assert.equal(payment.destination, worker)
  assert.equal(payment.sendAmount, '25.0000000')
  assert.equal(payment.destMin, '24.7500000')
  assert.equal(tx.networkPassphrase, Networks.TESTNET)
  assert.equal(tx.fee, '400')
})
test('ready trustlines result in exactly claim and path-payment operations', async () => {
  const balances = [trustline(pair.source), trustline(pair.destination)]
  const q = await quote({ balances })
  assert.equal(q.missingTrustlines.length, 0)
  assert.deepEqual(buildClaimConversion(account(balances), payout, q, '100').operations.map((op) => op.type), ['claimClaimableBalance', 'pathPaymentStrictSend'])
})
test('adds only the missing PHPT trustline', async () => {
  const q = await quote({ balances: [trustline(pair.source)] })
  assert.deepEqual(q.missingTrustlines.map((asset) => asset.code), ['PHPT'])
})
test('finds the best exact issuer route and ignores wrong issuers', async () => {
  const q = await quote({ routes: [{ ...route, destination_amount: '500', destination_asset_issuer: address(4) }, route, { ...route, destination_amount: '26' }] })
  assert.equal(q.expectedAmount, '26')
  assert.equal(q.minimumAmount, '25.74')
})
test('refuses missing liquidity before any wallet signing', async () => {
  await assert.rejects(quote({ routes: [] }), /No USDC to PHPT liquidity/)
})
test('refuses a path quote for a different input amount', async () => {
  await assert.rejects(quote({ routes: [{ ...route, source_amount: '24' }] }), /No USDC to PHPT liquidity/)
})
test('refuses locked payouts using ledger close time', async () => {
  await assert.rejects(quote({ time: now - 120_000 }), /still locked/)
})
test('finds the worker claimant even when employer is first', async () => {
  const q = await quote({ record: { ...payout, claimants: [{ destination: address(4), predicate: { abs_before: '1' } }, ...payout.claimants] } })
  assert.equal(q.address, worker)
})
test('refuses a wallet that is not a claimant', async () => {
  await assert.rejects(quote({ record: { ...payout, claimants: [] } }), /not a claimant/)
})
test('fails closed on an unknown predicate', async () => {
  await assert.rejects(quote({ record: { ...payout, claimants: [{ destination: worker, predicate: { rel_before: '60' } }] } }), /not supported/)
})
test('checks trustline authorization', async () => {
  await assert.rejects(quote({ balances: [trustline(pair.destination, { is_authorized: false })] }), /not authorized/)
})
test('checks destination trustline capacity including buying liabilities', async () => {
  await assert.rejects(quote({ balances: [trustline(pair.destination, { limit: '100', balance: '70', buying_liabilities: '10' })] }), /limit is too low/)
})
test('checks source trustline capacity before claiming', async () => {
  await assert.rejects(quote({ balances: [trustline(pair.source, { limit: '10' })] }), /USDC trustline limit/)
})
test('rechecks trustlines before building the transaction', async () => {
  const q = await quote()
  assert.throws(() => buildClaimConversion(account([trustline(pair.destination, { is_authorized: false })]), payout, q, '100'), /not authorized/)
})
test('rejects an expired quote', async () => {
  const q = await quote()
  assert.throws(() => buildClaimConversion(account(), payout, q, '100', q.expiresAt), /quote expired/)
})
test('rejects a changed payout or connected account', async () => {
  const q = await quote()
  assert.throws(() => buildClaimConversion(account(), { ...payout, amount: '26' }, q, '100'), /changed/)
  assert.throws(() => buildClaimConversion(Object.assign(account(), { account_id: address(4) }), payout, q, '100'), /changed/)
})
test('uses fixed-point arithmetic for minimum received', () => {
  assert.equal(minimumReceived('25'), '24.75')
  assert.equal(minimumReceived('0.0000101'), '0.0000099')
  assert.equal(amountUnits('100000000.0000001'), 1000000000000001n)
  assert.throws(() => minimumReceived('0.0000001'), /too small/)
  for (const value of ['-1', 'NaN', '1e2', '1.00000001', '922337203685.4775808']) assert.throws(() => amountUnits(value))
})
test('configuration matches full issuer identity and preserves XLM-only mode', () => {
  assert.equal(configuredConversion({}), null)
  assert.equal(supportsConversion(payout, pair), true)
  assert.equal(supportsConversion({ ...payout, asset: `USDC:${address(4)}` }, pair), false)
  assert.equal(supportsConversion({ ...payout, asset: 'native' }, pair), false)
})
test('explains slippage, liquidity, reserve, and timeout failures', () => {
  const error = (code) => ({ response: { data: { extras: { result_codes: { transaction: 'tx_failed', operations: [code] } } } } })
  assert.match(conversionError(error('op_under_dest_min')), /1% limit/)
  assert.match(conversionError(error('op_too_few_offers')), /enough liquidity/)
  assert.match(conversionError(error('op_low_reserve')), /Testnet XLM/)
  assert.match(conversionError({ response: { data: { extras: { result_codes: { transaction: 'tx_too_late' } } } } }), /expired while signing/)
})

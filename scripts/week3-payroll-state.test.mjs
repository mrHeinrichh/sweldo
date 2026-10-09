import test from 'node:test'
import assert from 'node:assert/strict'
import { horizonRecords, payrollTerms, reconstructPayroll } from '../src/lib/payroll-ledger.ts'
import { cancellableBalanceIds } from '../src/state/schedules-store.ts'
import { parseRoster } from '../src/lib/roster-import.ts'
import { CANCEL_HASH, CLAIM_HASH, CREATES, EMPLOYER, fixtureReader, IDS, NOW, OTHER_WORKER, WORKER } from './fixtures/week3-horizon.mjs'

test('a fresh process reconstructs amounts, balance IDs, claims and cancellation without browser storage', async () => {
  const result = await reconstructPayroll(EMPLOYER, { read: fixtureReader, now: NOW })
  assert.equal(result.schedules.length, 2)
  const schedule = result.schedules.find((item) => item.employee === WORKER)
  assert.equal(schedule.total, '6')
  assert.deepEqual(schedule.balanceIds, IDS.slice(0, 3))
  assert.deepEqual(schedule.payouts.map((payout) => payout.status), ['claimed', 'claimable', 'scheduled'])
  assert.equal(schedule.payouts[0].settlementHash, CLAIM_HASH)
  const cancelled = result.schedules.find((item) => item.employee === OTHER_WORKER)
  assert.equal(cancelled.cancelledPayouts, 1)
  assert.equal(cancelled.cancelHash, CANCEL_HASH)
  assert.equal(result.warnings.length, 0)
})

test('cancellation uses each verified deadline, including irregular schedules and the exact boundary', async () => {
  const { schedules } = await reconstructPayroll(EMPLOYER, { read: fixtureReader, now: NOW })
  const schedule = schedules.find((item) => item.employee === WORKER)
  assert.equal(schedule.intervalSeconds, undefined)
  const active = new Set(IDS)
  assert.deepEqual(cancellableBalanceIds(schedule, active, NOW), [IDS[2]])
  assert.deepEqual(cancellableBalanceIds(schedule, active, new Date(schedule.payouts[2].unlockAt)), [])
})

test('a missing live balance without a successful claim stays unverified', async () => {
  const read = async (path, allowMissing) => path === `/claimable_balances/${IDS[2]}` ? null : fixtureReader(path, allowMissing)
  const result = await reconstructPayroll(EMPLOYER, { read, now: NOW })
  const schedule = result.schedules.find((item) => item.employee === WORKER)
  assert.equal(schedule.payouts[2].status, 'unknown')
  assert.deepEqual(cancellableBalanceIds(schedule, new Set(IDS), NOW), [])
  assert.equal(result.warnings.length, 1)
})

test('a failed claim does not mark a live payout claimed', async () => {
  const read = async (path) => {
    const response = await fixtureReader(path)
    if (path.includes(IDS[1]) && path.includes('/operations')) response._embedded.records.unshift({
      type: 'claim_claimable_balance', balance_id: IDS[1], claimant: WORKER, transaction_successful: false,
    })
    return response
  }
  const result = await reconstructPayroll(EMPLOYER, { read, now: NOW })
  assert.equal(result.schedules.find((item) => item.employee === WORKER).payouts[1].status, 'claimable')
})

test('history pagination recovers payroll beyond the first 100 unrelated operations', async () => {
  const read = async (path) => {
    if (path.startsWith(`/accounts/${EMPLOYER}/operations`)) return {
      _embedded: { records: Array.from({ length: 100 }, (_, id) => ({ id: String(id), type: 'payment' })) },
      _links: { next: { href: '/fixture-page-2' } },
    }
    if (path === '/fixture-page-2') return fixtureReader(`/accounts/${EMPLOYER}/operations`)
    return fixtureReader(path)
  }
  const result = await reconstructPayroll(EMPLOYER, { read, now: NOW })
  assert.equal(result.schedules.length, 2)
})

test('pagination cycles and unavailable history fail instead of reporting a complete dashboard', async () => {
  await assert.rejects(horizonRecords(async () => ({ _embedded: { records: [1] }, _links: { next: { href: '/same' } } }), '/same'), /incomplete/)
  await assert.rejects(horizonRecords(async (path) => path === '/first'
    ? { _embedded: { records: [1] }, _links: { next: { href: '/missing-next' } } } : null, '/first', true), /incomplete/)
  await assert.rejects(reconstructPayroll(EMPLOYER, { read: async () => { throw new Error('Horizon offline') } }), /offline/)
})

test('unsupported predicates, another funding wallet and failed funding are excluded', () => {
  assert.equal(payrollTerms(CREATES[0], OTHER_WORKER), null)
  assert.equal(payrollTerms({ ...CREATES[0], transaction_successful: false }, EMPLOYER), null)
  const changed = structuredClone(CREATES[0])
  changed.claimants[1].predicate = { unconditional: true }
  assert.equal(payrollTerms(changed, EMPLOYER), null)
  changed.claimants[1].predicate = { ...CREATES[0].claimants[1].predicate, or: [] }
  assert.equal(payrollTerms(changed, EMPLOYER), null)
})

test('missing creation effects are a hard failure and invalid addresses never query Horizon', async () => {
  const read = async (path) => path.includes('/effects') ? { _embedded: { records: [] } } : fixtureReader(path)
  await assert.rejects(reconstructPayroll(EMPLOYER, { read }), /balance ID/)
  await assert.rejects(reconstructPayroll('invalid', { read: async () => assert.fail('must not query') }), /public key/)
})

test('unfunded employer returns an empty supported schedule list', async () => {
  const result = await reconstructPayroll(EMPLOYER, { read: async () => null, now: NOW })
  assert.deepEqual(result.schedules, [])
})

const csv = `wallet,name,amount,cadence\n${WORKER},"Ana, Santos",6,minute\n${OTHER_WORKER},Marco Reyes,9,minute`
test('quoted CSV and tab-separated paste import the same validated roster', () => {
  const result = parseRoster(csv, 3)
  assert.equal(result.rows[0].name, 'Ana, Santos')
  assert.equal(result.cadence, 'minute')
  assert.deepEqual(parseRoster(csv.replace('"Ana, Santos"', 'Ana Santos').replaceAll(',', '\t'), 3).rows[1], result.rows[1])
})

test('CSV import rejects invalid wallets, duplicates, mixed cadence and incomplete rows', () => {
  assert.throws(() => parseRoster(csv.replace(WORKER, 'Ginvalid'), 3), /Row 2/)
  assert.throws(() => parseRoster(csv.replace(OTHER_WORKER, WORKER), 3), /more than once/)
  assert.throws(() => parseRoster(csv.replace('9,minute', '9,week'), 3), /one cadence/)
  assert.throws(() => parseRoster(csv.replace('9,minute', '9'), 3), /four columns/)
  assert.throws(() => parseRoster(csv.replace('9,minute', '9,hour'), 3), /cadence must/)
})

test('CSV import enforces operation capacity, exact amounts, required headers and file size', () => {
  assert.throws(() => parseRoster(csv, 51), /1-50/)
  assert.throws(() => parseRoster(`${csv}\n${EMPLOYER},Third worker,6,minute`, 50), /150 operations/)
  assert.throws(() => parseRoster(csv.replace('6,minute', '0.00000001,minute'), 3), /seven decimal/)
  assert.throws(() => parseRoster(csv.replace('6,minute', '1,minute'), 3), /split evenly/)
  assert.throws(() => parseRoster(csv.replace('6,minute', '0,minute'), 3), /split evenly/)
  assert.throws(() => parseRoster(csv.replace('wallet,name', 'address,name'), 3), /header/)
  assert.throws(() => parseRoster('wallet,name,amount,cadence', 3), /at least one/)
  assert.throws(() => parseRoster('x'.repeat(100_001), 3), /100 KB/)
})

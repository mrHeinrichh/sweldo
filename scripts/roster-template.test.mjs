import test from 'node:test'
import assert from 'node:assert/strict'
import { Account, Keypair, MuxedAccount } from '@stellar/stellar-sdk'
import { createRosterTemplate, ROSTER_HEADER, rosterTemplateRows } from '../src/lib/roster-template.ts'
import { parseRoster, RosterError } from '../src/lib/roster-import.ts'

test('downloadable examples cannot import placeholder recipients, and say which rows to fix', () => {
  for (const payouts of [1, 3, 7, 50]) {
    const text = createRosterTemplate(payouts, 'week')
    assert.equal(text.split('\r\n')[0], ROSTER_HEADER)
    assert.throws(() => parseRoster(text, payouts), (error) => {
      assert.ok(error instanceof RosterError)
      assert.equal(error.issues.length, 2)
      assert.match(error.issues[0], /^Row 2: replace REPLACE_WITH_EMPLOYEE_1_G_ADDRESS with the employee’s Stellar wallet address/)
      assert.match(error.issues[1], /^Row 3: replace REPLACE_WITH_EMPLOYEE_2_G_ADDRESS with the employee’s Stellar wallet address/)
      return true
    })
  }
})

test('the on-screen sample and the downloaded file are the same cells', () => {
  const rows = rosterTemplateRows(8, 'month')
  assert.equal(createRosterTemplate(8, 'month'), `${rows.map((row) => row.join(',')).join('\r\n')}\r\n`)
  assert.deepEqual(rows[1].slice(1), ['Employee 1', '800', 'month'])
})

test('replacing sample wallets gives valid totals at every supported payout count and cadence', () => {
  const first = Keypair.random().publicKey()
  const second = Keypair.random().publicKey()
  for (let payouts = 1; payouts <= 50; payouts += 1) {
    for (const cadence of ['minute', 'day', 'week', 'month']) {
      const text = createRosterTemplate(payouts, cadence)
        .replace('REPLACE_WITH_EMPLOYEE_1_G_ADDRESS', first)
        .replace('REPLACE_WITH_EMPLOYEE_2_G_ADDRESS', second)
      const roster = parseRoster(text, payouts)
      assert.equal(roster.cadence, cadence)
      assert.equal(roster.rows.length, 2)
      assert.equal(roster.rows[0].total, String(payouts * 100))
      assert.equal(roster.rows[1].total, String(payouts * 200))
    }
  }
})

test('unsupported payout counts cannot create misleading templates', () => {
  for (const payouts of [0, 51, 1.5, Number.NaN]) {
    assert.throws(() => createRosterTemplate(payouts, 'minute'), /1-50 payouts/)
  }
})

const ANA = Keypair.random().publicKey()
const MARCO = Keypair.random().publicKey()
const LIZA = Keypair.random().publicKey()

test('every broken row is reported at once', () => {
  const text = [
    ROSTER_HEADER,
    `${ANA},Ana,800,week`,
    `${Keypair.random().secret()},Marco,800,week`,
    `${LIZA},Liza,1 600 XLM,week`,
    `${ANA},Ana again,800,week`,
    `${MARCO},Marco,800,fortnight`,
  ].join('\n')
  assert.throws(() => parseRoster(text, 8), (error) => {
    assert.ok(error instanceof RosterError)
    assert.equal(error.issues.length, 4)
    assert.match(error.issues[0], /^Row 3: this is a secret key/)
    assert.match(error.issues[1], /^Row 4: write the amount as a plain number/)
    assert.match(error.issues[2], /^Row 5: the same wallet appears more than once \(also in row 2\)/)
    assert.match(error.issues[3], /^Row 6: cadence must be/)
    return true
  })
})

test('spreadsheet habits are accepted: cadence words, grouped amounts, blank names, any column order', () => {
  const text = [
    'Name,Cadence,Wallet,Amount',
    `Ana Santos,Weekly,${ANA},"1,600"`,
    `,every week,${MARCO},"12,000.80"`,
  ].join('\r\n')
  const roster = parseRoster(text, 8)
  assert.equal(roster.cadence, 'week')
  assert.deepEqual(roster.rows.map((row) => [row.name, row.total]), [['Ana Santos', '1600'], ['', '12000.8']])
  // A decimal comma is never read as a thousands separator.
  assert.throws(() => parseRoster(`${ROSTER_HEADER}\n${ANA},Ana,"1,5",week`, 1), /plain number/)
})

test('the header problem names what is missing or extra', () => {
  assert.throws(() => parseRoster(`wallet,name,total,cadence\n${ANA},Ana,8,week`, 1), /missing amount; remove total/)
  assert.throws(() => parseRoster(`wallet,name,amount\n${ANA},Ana,8`, 1), /missing cadence/)
})

test('mixed cadences and muxed addresses are explained', () => {
  assert.throws(() => parseRoster(`${ROSTER_HEADER}\n${ANA},Ana,8,daily\n${MARCO},Marco,8,month`, 1), /found day and month/)
  const muxed = new MuxedAccount(new Account(ANA, '0'), '42').accountId()
  assert.throws(() => parseRoster(`${ROSTER_HEADER}\n${muxed},Ana,8,week`, 1), /muxed/)
})

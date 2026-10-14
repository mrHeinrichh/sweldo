import test from 'node:test'
import assert from 'node:assert/strict'
import { friendlyError } from '../src/state/errors.ts'

const rejection = (codes) => ({ response: { data: { extras: { result_codes: codes } } } })

test('missing payroll assets are not described as an XLM reserve problem', () => {
  const message = friendlyError(rejection({ transaction: 'tx_failed', operations: ['op_success', 'op_underfunded'] }))
  assert.match(message, /selected payroll asset/)
  assert.match(message, /trustline; it does not add funds/)
  assert.doesNotMatch(message, /XLM|reserve/)
})

for (const codes of [{ transaction: 'tx_insufficient_balance' }, { transaction: 'tx_failed', operations: ['op_low_reserve'] }]) {
  test(`XLM funding errors explain fees and reserves: ${codes.transaction} ${codes.operations ?? ''}`, () => {
    assert.equal(friendlyError(rejection(codes)), 'Not enough available Testnet XLM for fees and reserves. Add test XLM or reduce the number of payouts.')
  })
}

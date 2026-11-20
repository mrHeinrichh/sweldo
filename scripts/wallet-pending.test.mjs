import test from 'node:test'
import assert from 'node:assert/strict'
import { pendingWallet } from '../src/lib/wallets/pending.ts'

const deferred = () => {
  let resolve, reject
  const promise = new Promise((yes, no) => { resolve = yes; reject = no })
  return { promise, resolve, reject }
}

test('wallet connection returns its result when approval arrives', async () => {
  const controller = new AbortController()
  assert.equal(await pendingWallet(Promise.resolve('connected'), controller.signal), 'connected')
})

test('a stalled wallet wait ends with an actionable timeout reason', async () => {
  const controller = new AbortController()
  const approval = deferred()
  const timeout = new Error('Your wallet has not replied. Try connecting again.')
  const result = pendingWallet(approval.promise, controller.signal)
  controller.abort(timeout)
  await assert.rejects(result, (error) => error === timeout)
  approval.resolve('late connection')
  await assert.rejects(result, (error) => error === timeout)
})

test('cancelled connections cannot become connected after late approval', async () => {
  const controller = new AbortController()
  const approval = deferred()
  const result = pendingWallet(approval.promise, controller.signal)
  controller.abort()
  await assert.rejects(result, { name: 'AbortError' })
  approval.resolve('late connection')
  await assert.rejects(result, { name: 'AbortError' })
})

test('already cancelled work still handles a late adapter rejection', async () => {
  const controller = new AbortController()
  controller.abort()
  const approval = deferred()
  await assert.rejects(pendingWallet(approval.promise, controller.signal), { name: 'AbortError' })
  approval.reject(new Error('Late wallet rejection'))
  // Node's test runner fails this test if a late adapter rejection is unhandled.
  await new Promise((resolve) => setImmediate(resolve))
})

test('wallet adapter failures propagate so the picker can recover', async () => {
  const controller = new AbortController()
  const error = new Error('Connection declined')
  await assert.rejects(pendingWallet(Promise.reject(error), controller.signal), (actual) => actual === error)
})

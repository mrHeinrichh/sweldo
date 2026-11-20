import test from 'node:test'
import assert from 'node:assert/strict'
import { StrKey } from '@stellar/stellar-sdk'
import { claimableBalanceExplorerId, explorer } from '../src/lib/explorer.ts'

const hash = 'db1108ff108a807150d02b8672d9a8c0e808bff918cdbe5c7605e63a7f565df5'
const horizonId = `00000000${hash}`
const strkey = 'BAANWEII74IIVADRKDICXBTS3GUMB2AIX74RRTN6LR3ALZR2P5LF35OVGE'

test('individual balance receipts convert Horizon XDR IDs to canonical explorer StrKeys', () => {
  assert.equal(claimableBalanceExplorerId(horizonId), strkey)
  assert.equal(explorer.claimableBalance(horizonId), `https://stellar.expert/explorer/testnet/claimable-balance/${strkey}`)
  assert.equal(StrKey.decodeClaimableBalance(strkey).toString('hex'), `00${hash}`)
  assert.equal(horizonId.length, 72, 'ledger IDs retain their Horizon representation')
})

test('bare hashes, uppercase hex and canonical StrKeys link to the same individual balance', () => {
  for (const id of [hash, horizonId.toUpperCase(), strkey]) {
    assert.equal(explorer.claimableBalance(id), explorer.claimableBalance(horizonId))
  }
})

test('bulk transaction receipts continue to link to the transaction hash', () => {
  assert.equal(explorer.transaction(hash), `https://stellar.expert/explorer/testnet/tx/${hash}`)
})

test('invalid balance widths and unsupported discriminants cannot produce misleading links', () => {
  for (const id of ['', 'invalid', `00000001${hash}`, hash.slice(2)]) {
    assert.throws(() => claimableBalanceExplorerId(id), /Invalid claimable balance ID/)
  }
})

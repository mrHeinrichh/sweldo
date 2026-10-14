import test from 'node:test'
import assert from 'node:assert/strict'
import { Account, Asset, Keypair, Networks, Operation, TransactionBuilder } from '@stellar/stellar-sdk'
import { requireTestnetAccount, reviewedTransaction, verifiedSignature } from '../src/lib/wallets/signing.ts'

const key = Keypair.random()
const other = Keypair.random()
const address = key.publicKey()
const recipient = other.publicKey()
const account = { address, network: 'TESTNET', networkPassphrase: Networks.TESTNET }
const build = (amount = '1') => new TransactionBuilder(new Account(address, '1'), { fee: '100', networkPassphrase: Networks.TESTNET })
  .addOperation(Operation.payment({ destination: recipient, asset: Asset.native(), amount })).setTimeout(180).build()
const signed = (transaction, signer = key) => { transaction.sign(signer); return transaction.toXDR() }

test('valid selected-account Testnet signatures preserve the reviewed envelope', () => {
  const transaction = build()
  const original = transaction.toXDR()
  requireTestnetAccount(account, address)
  assert.equal(verifiedSignature(original, signed(transaction), address), transaction.toXDR())
})
test('wrong network, account or transaction source cannot pass review', () => {
  assert.throws(() => requireTestnetAccount({ ...account, networkPassphrase: Networks.PUBLIC }, address), /Testnet/)
  assert.throws(() => requireTestnetAccount(account, recipient), /account changed/)
  assert.throws(() => reviewedTransaction(build().toXDR(), recipient, Networks.TESTNET), /source/)
  assert.throws(() => reviewedTransaction(build().toXDR(), address, Networks.PUBLIC), /Testnet/)
})
test('empty, unsigned or malformed wallet envelopes cannot be submitted', () => {
  const original = build().toXDR()
  assert.throws(() => verifiedSignature(original, '', address), /cancelled/)
  assert.throws(() => verifiedSignature(original, original, address), /No valid Testnet signature/)
  assert.throws(() => verifiedSignature(original, 'bad', address))
})
test('changed operations, wrong reported signer and mainnet signatures are rejected', () => {
  const transaction = build()
  const original = transaction.toXDR()
  assert.throws(() => verifiedSignature(original, signed(build('2')), address), /differs/)
  assert.throws(() => verifiedSignature(original, signed(transaction), address, recipient), /account changed/)
  const mainnet = TransactionBuilder.fromXDR(original, Networks.PUBLIC)
  assert.throws(() => verifiedSignature(original, signed(mainnet), address), /No valid Testnet signature/)
})
test('a different account signature cannot satisfy the expected signer', () => {
  const transaction = build()
  const original = transaction.toXDR()
  assert.throws(() => verifiedSignature(original, signed(transaction, other), address), /No valid Testnet signature/)
})

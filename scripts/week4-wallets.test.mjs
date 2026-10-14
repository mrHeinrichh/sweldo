import test from 'node:test'
import assert from 'node:assert/strict'
import { Account, Asset, Claimant, Contract, Keypair, Networks, Operation, TransactionBuilder } from '@stellar/stellar-sdk'
import { kitAccount, signWithKit } from '../src/lib/wallets/signing.ts'
import { verificationManifest, verifyReceipt } from '../src/lib/week4-evidence.ts'

const key = Keypair.random()
const other = Keypair.random()
const address = key.publicKey()
const recipient = other.publicKey()
const account = { address, network: 'TESTNET', networkPassphrase: Networks.TESTNET }
const balanceId = '00000000' + 'a'.repeat(64)
const build = (operation = Operation.payment({ destination: recipient, asset: Asset.native(), amount: '1' })) =>
  new TransactionBuilder(new Account(address, '1'), { fee: '100', networkPassphrase: Networks.TESTNET })
    .addOperation(operation).setTimeout(180).build()
const signed = (transaction, signer = key) => { transaction.sign(signer); return transaction.toXDR() }

function transport(overrides = {}) {
  return {
    address: async () => ({ address }),
    network: async () => ({ network: 'TESTNET', networkPassphrase: Networks.TESTNET }),
    sign: async (xdr, options) => {
      assert.equal(options.address, address)
      assert.equal(options.networkPassphrase, Networks.TESTNET)
      return { signedTxXdr: signed(TransactionBuilder.fromXDR(xdr, options.networkPassphrase)), signerAddress: address }
    },
    ...overrides,
  }
}

for (const wallet of ['freighter-extension', 'xbull']) {
  test(`${wallet} delegates address and transaction signing with explicit Testnet options`, async () => {
    const original = build().toXDR()
    const result = await signWithKit(transport(), wallet, original, address, Networks.TESTNET)
    assert.equal(TransactionBuilder.fromXDR(result, Networks.TESTNET).hash().toString('hex'), TransactionBuilder.fromXDR(original, Networks.TESTNET).hash().toString('hex'))
  })
  test(`${wallet} signs the existing funding, claim, conversion, cancellation and Soroban envelopes`, async () => {
    const operations = [
      Operation.createClaimableBalance({ asset: Asset.native(), amount: '1', claimants: [new Claimant(recipient)] }),
      Operation.claimClaimableBalance({ balanceId }),
      Operation.pathPaymentStrictSend({ sendAsset: new Asset('USDC', recipient), sendAmount: '1', destination: address, destAsset: new Asset('PHPT', recipient), destMin: '50', path: [] }),
      new Contract('CDAGOOIBW7EUHHHOXXNMFT23YWPE5F352HGKJOFCURU6S2KDG3XQLHUC').call('record_schedule'),
    ]
    for (const op of operations) await signWithKit(transport(), wallet, build(op).toXDR(), address, Networks.TESTNET)
  })
}

test('xBull does not invent a wallet-reported network or call unsupported getNetwork', async () => {
  const value = await kitAccount(transport({ network: async () => assert.fail('xBull does not report its network') }), 'xbull')
  assert.deepEqual(value, account)
})
test('Freighter reads the actual network and rejects mainnet before signing', async () => {
  const api = transport({ network: async () => ({ network: 'PUBLIC', networkPassphrase: Networks.PUBLIC }), sign: async () => assert.fail('must not sign') })
  await assert.rejects(signWithKit(api, 'freighter-extension', build().toXDR(), address, Networks.TESTNET), /Testnet/)
})
test('no wallet receives a mainnet signing request', async () => {
  const api = transport({ sign: async () => assert.fail('must not sign') })
  await assert.rejects(signWithKit(api, 'xbull', build().toXDR(), address, Networks.PUBLIC), /Testnet/)
})
test('a switched account is rejected before signing', async () => {
  await assert.rejects(signWithKit(transport({ address: async () => ({ address: recipient }), sign: async () => assert.fail('must not sign') }), 'xbull', build().toXDR(), address, Networks.TESTNET), /account changed/)
})
test('invalid public keys and rejected connections are not treated as connected', async () => {
  await assert.rejects(kitAccount(transport({ address: async () => ({ address: 'bad' }) }), 'xbull'), /valid Stellar/)
  await assert.rejects(kitAccount(transport({ address: async () => { throw new Error('Rejected') } }), 'xbull'), /Rejected/)
})

const receipt = { wallet: 'xbull', kind: 'claim-convert', account: address, hash: 'a'.repeat(64) }
const assets = { usdc: { code: 'USDC', issuer: recipient }, phpt: { code: 'PHPT', issuer: recipient } }
const manifest = { network: 'Stellar Testnet', assets, receipts: [receipt] }
const operations = [
  { type: 'claim_claimable_balance', source_account: address, claimant: address },
  { type: 'path_payment_strict_send', source_account: address, from: address, to: address, source_asset_code: 'USDC', source_asset_issuer: recipient, asset_code: 'PHPT', asset_issuer: recipient, amount: '50', destination_min: '49' },
]
test('evidence needs actual hashes, distinct receipts, supported wallets and exact issuers', () => {
  assert.deepEqual(verificationManifest(manifest), manifest)
  assert.throws(() => verificationManifest({ ...manifest, receipts: [] }), /Empty/)
  assert.throws(() => verificationManifest({ ...manifest, network: 'Mainnet' }), /Testnet/)
  assert.throws(() => verificationManifest({ ...manifest, receipts: [receipt, receipt] }), /twice/)
  assert.throws(() => verificationManifest({ ...manifest, receipts: [{ ...receipt, wallet: 'unsupported' }] }), /supported wallet/)
  assert.throws(() => verificationManifest({ ...manifest, assets: {} }), /issuers/)
})
test('conversion receipts verify successful source account, issuer pair and a self-directed PHPT payment', () => {
  const tx = { successful: true, source_account: address }
  assert.equal(verifyReceipt(receipt, tx, operations, assets), true)
  assert.equal(verifyReceipt(receipt, { ...tx, successful: false }, operations, assets), false)
  assert.equal(verifyReceipt(receipt, { ...tx, source_account: recipient }, operations, assets), false)
  assert.equal(verifyReceipt(receipt, tx, [operations[0], { ...operations[1], asset_issuer: address }], assets), false)
  assert.equal(verifyReceipt(receipt, tx, [operations[0], { ...operations[1], to: recipient }], assets), false)
  assert.equal(verifyReceipt(receipt, tx, [operations[0], { ...operations[1], amount: '0' }], assets), false)
})

import test from 'node:test'
import assert from 'node:assert/strict'
import { Account, Asset, Claimant, Keypair, Networks, Operation, TransactionBuilder } from '@stellar/stellar-sdk'
import { payrollAssetOptions, payoutTotals } from '../src/lib/payroll-assets.ts'
import { configuredConversion, supportsConversion } from '../src/lib/claim-convert.ts'

const issuer = Keypair.random().publicKey()
const otherIssuer = Keypair.random().publicKey()
const options = payrollAssetOptions('USDC', issuer)

test('XLM is the default even when controlled Test-USDC is configured', () => {
  assert.deepEqual(options.map((option) => option.label), ['XLM (Testnet)', 'Test-USDC'])
  assert.equal(options[0].asset.isNative(), true)
  assert.equal(options[1].id, `USDC:${issuer}`)
})

test('missing or invalid configuration cannot enable an arbitrary payroll asset', () => {
  for (const [code, key] of [['', ''], ['PHPT', issuer], ['USDC', 'bad'], ['XLM', issuer]]) {
    assert.deepEqual(payrollAssetOptions(code, key).map((option) => option.id), ['native'])
  }
})

for (const option of options) {
  test(`${option.label} remains the exact selected asset in the claimable balance envelope`, () => {
    const source = Keypair.random().publicKey()
    const tx = new TransactionBuilder(new Account(source, '1'), { fee: '100', networkPassphrase: Networks.TESTNET })
      .addOperation(Operation.createClaimableBalance({ asset: option.asset, amount: '1', claimants: [new Claimant(issuer)] }))
      .setTimeout(180).build()
    const decoded = TransactionBuilder.fromXDR(tx.toXDR(), Networks.TESTNET).operations[0]
    assert.equal(decoded.asset.equals(option.asset), true)
  })
}

test('mixed payrolls keep XLM, USDC and different issuers in separate totals', () => {
  const payouts = [
    { asset: 'native', amount: '2' },
    { asset: `USDC:${issuer}`, amount: '3' },
    { asset: 'native', amount: '0.5' },
    { asset: `USDC:${otherIssuer}`, amount: '7' },
  ]
  const original = structuredClone(payouts)
  assert.deepEqual(payoutTotals(payouts), [
    { asset: 'native', assetCode: 'XLM', units: 25000000n },
    { asset: `USDC:${issuer}`, assetCode: 'USDC', units: 30000000n },
    { asset: `USDC:${otherIssuer}`, assetCode: 'USDC', units: 70000000n },
  ])
  assert.deepEqual(payouts, original)
  assert.deepEqual(payoutTotals([]), [])
})

test('changing the draft asset cannot make XLM or an unrelated issuer convertible to PHPT', () => {
  const pair = configuredConversion({ VITE_ASSET_CODE: 'USDC', VITE_ASSET_ISSUER: issuer, VITE_PHPT_ISSUER: otherIssuer })
  assert.ok(pair)
  const payout = { balance_id: 'balance', asset: `USDC:${issuer}`, amount: '1', claimants: [] }
  assert.equal(supportsConversion(payout, pair), true)
  assert.equal(supportsConversion({ ...payout, asset: 'native' }, pair), false)
  assert.equal(supportsConversion({ ...payout, asset: `USDC:${otherIssuer}` }, pair), false)
  assert.equal(options[0].asset.equals(Asset.native()), true)
})

import test from 'node:test'
import assert from 'node:assert/strict'
import { Account, Keypair, MuxedAccount } from '@stellar/stellar-sdk'
import { parseWalletQr } from '../src/lib/wallet-qr.ts'

const address = 'GCALNQQBXAPZ2WIRSDDBMSTAKCUH5SG6U76YBFLQLIXJTF7FE5AX7AOO'
const uri = `web+stellar:pay?destination=${address}`

test('wallet QR accepts only a complete checksum-valid public address', () => {
  assert.equal(parseWalletQr(address), address)
  assert.equal(parseWalletQr(` \n${address}\t `), address)
  for (const input of [address.slice(0, -1) + 'A', address.toLowerCase(), address + address, `${address}\n${address}`]) {
    assert.throws(() => parseWalletQr(input), /valid G… public address/)
  }
})

test('SEP-7 payment QR reads one destination and does not import payment instructions', () => {
  assert.equal(parseWalletQr(uri), address)
  assert.equal(parseWalletQr(`web+stellar:pay?%64estination=%47${address.slice(1)}`), address)
  assert.equal(parseWalletQr(`${uri}&amount=999&asset_code=USDC&asset_issuer=${address}&msg=Pay+me`), address)
  // A callback containing another address must never replace the destination.
  const callback = encodeURIComponent(`url:https://example.com/${Keypair.random().publicKey()}`)
  assert.equal(parseWalletQr(`${uri}&callback=${callback}`), address)
})

test('QR import rejects arbitrary URLs and look-alike schemes', () => {
  for (const input of [`M${'A'.repeat(68)}`, `https://example.com/${address}`, `https://example.com?destination=${address}`, `stellar:${address}`, `web+stellar:tx?destination=${address}`, `web+stellar://pay?destination=${address}`, `web+stellar:PAY?destination=${address}`, `address=${address}`, 'worker*', '*example.com']) {
    assert.throws(() => parseWalletQr(input), /valid G… public address/)
  }
})

test('secret keys, muxed and federation addresses get a message that says what was scanned', () => {
  const secret = Keypair.random().secret()
  for (const input of [secret, `web+stellar:pay?destination=${secret}`]) {
    assert.throws(() => parseWalletQr(input), (error) => {
      assert.match(error.message, /secret key, not a wallet address\. Nothing was saved/)
      assert.ok(!error.message.includes(secret))
      return true
    })
  }
  const muxed = new MuxedAccount(new Account(address, '0'), '7').accountId()
  assert.throws(() => parseWalletQr(muxed), /muxed \(M…\) address/)
  for (const input of ['ana*lobstr.co', 'worker*example.com', `web+stellar:pay?destination=${encodeURIComponent('ana*lobstr.co')}`]) {
    assert.throws(() => parseWalletQr(input), /name\*domain address/)
  }
})

test('ambiguous destinations, duplicate fields and URI fragments are rejected', () => {
  for (const input of [`${uri}&destination=${address}`, `${uri}&%64estination=${address}`, `${uri}&Destination=${address}`, `${uri}&amount=1&amount=2`, `${uri}#ignored`, `web+stellar:pay?Destination=${address}`, 'web+stellar:pay?amount=1', `web+stellar:pay?destination=%20${address}`]) {
    assert.throws(() => parseWalletQr(input))
  }
})

test('memo-bearing QR requests cannot silently lose required payment routing', () => {
  for (const field of ['memo=123', 'memo=', 'memo_type=MEMO_ID', '%6Demo=123', 'MEMO=123']) {
    assert.throws(() => parseWalletQr(`${uri}&${field}`), /requires a memo/)
  }
})

test('malformed escapes, invalid UTF-8, embedded whitespace and oversized QR payloads are rejected', () => {
  for (const input of ['', `${uri}&msg=%`, `${uri}&msg=%GG`, `${uri}&msg=%FF`, `${uri}&msg=hello world`, `${uri}&`, `${uri}&msg`, `${uri}&msg=${'a'.repeat(8192)}`]) {
    assert.throws(() => parseWalletQr(input), /valid G… public address/)
  }
})

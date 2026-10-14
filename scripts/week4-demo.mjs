#!/usr/bin/env node
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { Horizon, StrKey } from '@stellar/stellar-sdk'
import { verificationManifest, verifyReceipt } from '../src/lib/week4-evidence.ts'

const root = new URL('../', import.meta.url)
const local = new URL('.sweldo-local/', root)
const [command, file] = process.argv.slice(2)
const server = new Horizon.Server('https://horizon-testnet.stellar.org')

async function configure() {
  const evidence = JSON.parse(await readFile(new URL('week1-result.json', local), 'utf8'))
  if (evidence.network !== 'Stellar Testnet') throw new Error('Only the existing Week 1 Testnet configuration is supported.')
  const { usdc, phpt } = evidence.assets ?? {}
  if (usdc?.code !== 'USDC' || phpt?.code !== 'PHPT'
    || !StrKey.isValidEd25519PublicKey(usdc.issuer) || !StrKey.isValidEd25519PublicKey(phpt.issuer)) {
    throw new Error('Valid public Week 1 asset issuers are needed. No secret keys are read by this command.')
  }
  await writeFile(new URL('.env.week4.local', root), [
    '# Local Week 4 configuration: public Testnet asset identities only.',
    `VITE_ASSET_CODE=${usdc.code}`, `VITE_ASSET_ISSUER=${usdc.issuer}`, `VITE_PHPT_ISSUER=${phpt.issuer}`, '',
  ].join('\n'), { mode: 0o600 })
  await writeFile(new URL('week4-receipts.json', local), JSON.stringify({
    network: 'Stellar Testnet', assets: { usdc, phpt }, receipts: [],
    demoVideoUrl: '', liveUrl: '', week4PrUrl: '',
  }, null, 2) + '\n', { flag: 'wx', mode: 0o600 }).catch((error) => { if (error.code !== 'EEXIST') throw error })
  console.log('Created .env.week4.local using public Week 1 asset evidence. No transactions were sent.')
  console.log('Start npm run week4:dev. Existing .env.local registry settings remain in effect.')
  console.log('Receipt template: .sweldo-local/week4-receipts.json. Existing receipts are never overwritten.')
}

async function verify() {
  if (!file) throw new Error('Use npm run week4:verify -- PATH_TO_COMPLETED_RECEIPT_JSON')
  const manifest = verificationManifest(JSON.parse(await readFile(file, 'utf8')))
  const receipts = []
  for (const receipt of manifest.receipts) {
    const tx = await server.transactions().transaction(receipt.hash).call()
    const operations = await server.operations().forTransaction(receipt.hash).limit(100).call()
    let passed = verifyReceipt(receipt, tx, operations.records, manifest.assets)
    if (passed && receipt.kind === 'cancellation') {
      // A native claim operation is a cancellation only if the claimant was the employer.
      const claims = operations.records.filter((op) => op.type === 'claim_claimable_balance')
      passed = claims.length > 0
      for (const claim of claims) {
        const history = await server.operations().forClaimableBalance(claim.balance_id).limit(100).call()
        const creation = history.records.find((op) => op.type === 'create_claimable_balance')
        const employer = creation?.source_account
        const predicate = creation?.claimants?.find((c) => c.destination === receipt.account)?.predicate
        passed &&= employer === receipt.account && !!predicate?.abs_before
          && Date.parse(tx.created_at) < Date.parse(predicate.abs_before)
      }
    }
    receipts.push({ ...receipt, passed, ledger: tx.ledger, createdAt: tx.created_at,
      url: `https://stellar.expert/explorer/testnet/tx/${receipt.hash}` })
    console.log(`${passed ? 'PASS' : 'FAIL'} ${receipt.wallet}: ${receipt.kind}\n${receipts.at(-1).url}`)
  }
  const coverage = {
    freighter: receipts.some((r) => r.passed && r.wallet === 'freighter'),
    xbull: receipts.some((r) => r.passed && r.wallet === 'xbull'),
    funding: receipts.some((r) => r.passed && r.kind === 'funding'),
    claimAndConvert: receipts.some((r) => r.passed && r.kind === 'claim-convert'),
  }
  const passed = receipts.every((r) => r.passed) && Object.values(coverage).every(Boolean)
  await mkdir(local, { recursive: true })
  const output = new URL('week4-verification.json', local)
  await writeFile(output, JSON.stringify({ network: 'Stellar Testnet', verifiedAt: new Date().toISOString(), passed, coverage, receipts,
    note: 'Ledger receipts cannot prove which wallet application signed. Provide real recordings of both wallets. Local verification does not certify deployment, PR, or video completion.' }, null, 2) + '\n', { mode: 0o600 })
  console.log(`Public receipt report: ${fileURLToPath(output)}`)
  console.log('Wallet identity must also be demonstrated in your actual recording; it is not encoded on the ledger.')
  if (!passed) process.exitCode = 1
}

try {
  if (command === 'configure') await configure()
  else if (command === 'verify') await verify()
  else throw new Error('Choose configure or verify. Neither command sends transactions.')
} catch (error) {
  console.error(error.message)
  process.exitCode = 1
}

#!/usr/bin/env node
import { chmod, readFile, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { Asset, Claimant, Horizon, Keypair, Networks, Operation, StrKey, TransactionBuilder } from '@stellar/stellar-sdk'

const root = new URL('../', import.meta.url)
const local = new URL('.sweldo-local/', root)
const server = new Horizon.Server('https://horizon-testnet.stellar.org')
const explorer = 'https://stellar.expert/explorer/testnet/tx/'
const [command, ...args] = process.argv.slice(2)
const option = (name) => args[args.indexOf(name) + 1]

async function json(name) { return JSON.parse(await readFile(new URL(name, local), 'utf8')) }
async function save(name, data) {
  const file = new URL(name, local)
  await writeFile(file, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 })
  await chmod(file, 0o600)
}

async function configuration() {
  const evidence = await json('week1-result.json')
  if (evidence.network !== 'Stellar Testnet') throw new Error('Only the Week 1 Stellar Testnet setup is supported.')
  const usdc = evidence.assets?.usdc
  const phpt = evidence.assets?.phpt
  if (usdc?.code !== 'USDC' || phpt?.code !== 'PHPT'
      || !StrKey.isValidEd25519PublicKey(usdc.issuer) || !StrKey.isValidEd25519PublicKey(phpt.issuer)) {
    throw new Error('Week 1 evidence does not contain valid test asset issuers.')
  }
  return { evidence, usdc: new Asset('USDC', usdc.issuer), phpt: new Asset('PHPT', phpt.issuer) }
}

async function configure() {
  const { usdc, phpt } = await configuration()
  const file = new URL('.env.week2.local', root)
  await writeFile(file, [
    '# Generated from public Week 1 evidence. Test assets only; no secret keys.',
    `VITE_ASSET_CODE=${usdc.code}`, `VITE_ASSET_ISSUER=${usdc.issuer}`, `VITE_PHPT_ISSUER=${phpt.issuer}`, '',
  ].join('\n'), { mode: 0o600 })
  console.log(`Local configuration ready: ${fileURLToPath(file)}`)
  console.log('No network transactions were sent. Start with npm run week2:dev.')
}

async function prepare() {
  if (!args.includes('--testnet') || !args.includes('--worker')) {
    throw new Error('This command submits a Testnet transaction. Use: npm run week2:prepare -- --testnet --worker G... [--delay 60]')
  }
  const worker = option('--worker')
  if (!StrKey.isValidEd25519PublicKey(worker ?? '')) throw new Error('Supply the public G... address of your Freighter Testnet worker account.')
  const delay = args.includes('--delay') ? Number(option('--delay')) : 60
  if (!Number.isInteger(delay) || delay < 10 || delay > 3600) throw new Error('Delay must be an integer from 10 to 3600 seconds.')
  const { evidence, usdc, phpt } = await configuration()
  const state = await json('week1-testnet.json')
  if (state.network !== 'Stellar Testnet') throw new Error('Refusing a non-Testnet state file.')
  if (state.accounts.usdcIssuer.publicKey !== usdc.issuer || state.accounts.phptIssuer.publicKey !== phpt.issuer) {
    throw new Error('Week 1 state and evidence disagree. Re-run Week 1 setup before preparing the demo.')
  }
  const employer = state.accounts.worker
  if (worker === employer.publicKey) throw new Error('Use a separate Freighter worker account for the demo.')
  const signingKey = Keypair.fromSecret(employer.secret)
  if (signingKey.publicKey() !== employer.publicKey || employer.publicKey !== evidence.accounts.worker) throw new Error('Invalid local demo funding account.')
  await server.loadAccount(worker).catch(() => { throw new Error('The worker account must be funded on Testnet first. Use Friendbot in Freighter.') })
  const account = await server.loadAccount(employer.publicKey)
  const line = account.balances.find((balance) => balance.asset_code === usdc.code && balance.asset_issuer === usdc.issuer)
  if (!line || Number(line.balance) - Number(line.selling_liabilities ?? '0') < 25) throw new Error('The Week 1 worker needs at least 25 test-USDC. Re-run Week 1 setup.')
  const routes = await server.strictSendPaths(usdc, '25', [phpt]).call()
  if (!routes.records.length) throw new Error('No USDC to PHPT liquidity is available. Restore the Week 1 offer first.')
  const unlockAt = Math.floor(Date.now() / 1000) + delay
  const tx = new TransactionBuilder(account, { fee: String(await server.fetchBaseFee()), networkPassphrase: Networks.TESTNET })
    .addOperation(Operation.createClaimableBalance({
      asset: usdc, amount: '25', claimants: [
        new Claimant(worker, Claimant.predicateNot(Claimant.predicateBeforeAbsoluteTime(String(unlockAt)))),
        new Claimant(employer.publicKey, Claimant.predicateBeforeAbsoluteTime(String(unlockAt))),
      ],
    })).setTimeout(180).build()
  tx.sign(signingKey)
  const result = await server.submitTransaction(tx)
  const receipt = {
    network: 'Stellar Testnet', worker, employer: employer.publicKey, amount: '25',
    usdc: { code: usdc.code, issuer: usdc.issuer }, phpt: { code: phpt.code, issuer: phpt.issuer },
    balanceId: tx.getClaimableBalanceId(0), unlockAt: new Date(unlockAt * 1000).toISOString(),
    fundingHash: result.hash, fundingUrl: `${explorer}${result.hash}`,
  }
  await save('week2-payout.json', receipt)
  console.log(JSON.stringify(receipt, null, 2))
  console.log('Now open the LOCAL app, connect this worker in Freighter Testnet, choose For employees, and wait for payday.')
}

async function verify() {
  const hash = args[0]
  if (!/^[a-f0-9]{64}$/i.test(hash ?? '')) throw new Error('Use: npm run week2:verify -- TRANSACTION_HASH')
  const expected = await json('week2-payout.json')
  if (expected.network !== 'Stellar Testnet') throw new Error('Expected a Testnet demo payout.')
  const [tx, operations] = await Promise.all([
    server.transactions().transaction(hash).call(), server.operations().forTransaction(hash).limit(100).call(),
  ])
  const claim = operations.records.find((record) => record.type === 'claim_claimable_balance' && record.balance_id === expected.balanceId)
  const conversion = operations.records.find((record) => record.type === 'path_payment_strict_send'
    && record.source_asset_code === expected.usdc.code && record.source_asset_issuer === expected.usdc.issuer
    && record.asset_code === expected.phpt.code && record.asset_issuer === expected.phpt.issuer)
  const checks = {
    successful: tx.successful === true,
    scheduledPayoutClaimed: !!claim && claim.source_account === expected.worker,
    convertedInSameTransaction: !!conversion && conversion.source_account === expected.worker && conversion.to === expected.worker
      && conversion.from === expected.worker && Number(conversion.source_amount) === Number(expected.amount),
    receivedPHPT: !!conversion && Number(conversion.amount) > 0 && Number(conversion.amount) >= Number(conversion.destination_min),
  }
  const result = {
    verifiedAt: new Date().toISOString(), network: 'Stellar Testnet', passed: Object.values(checks).every(Boolean), checks,
    transactionHash: hash, transactionUrl: `${explorer}${hash}`, balanceId: expected.balanceId,
    worker: expected.worker, sentAmount: conversion?.source_amount ?? null, receivedPHPT: conversion?.amount ?? null,
    fundingUrl: expected.fundingUrl,
  }
  await save('week2-result.json', result)
  for (const [name, passed] of Object.entries(checks)) console.log(`${passed ? 'PASS' : 'FAIL'}  ${name}`)
  console.log(result.transactionUrl)
  if (!result.passed) process.exitCode = 1
}

try {
  if (command === 'configure') await configure()
  else if (command === 'prepare') await prepare()
  else if (command === 'verify') await verify()
  else throw new Error('Choose configure, prepare, or verify.')
} catch (error) {
  console.error(error?.response?.data?.extras?.result_codes ?? error.message)
  process.exitCode = 1
}

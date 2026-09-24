#!/usr/bin/env node

import { chmod, mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  Asset,
  Horizon,
  Keypair,
  Networks,
  Operation,
  TransactionBuilder,
} from '@stellar/stellar-sdk'

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const localDirectory = path.join(projectRoot, '.sweldo-local')
const statePath = path.join(localDirectory, 'week1-testnet.json')
const evidencePath = path.join(localDirectory, 'week1-result.json')

const HORIZON_URL = 'https://horizon-testnet.stellar.org'
const FRIENDBOT_URL = 'https://friendbot.stellar.org'
const NETWORK_PASSPHRASE = Networks.TESTNET
const EXPLORER_URL = 'https://stellar.expert/explorer/testnet'
const STARTING_XLM = '20'
const PHPT_LIQUIDITY = '4000'
const WORKER_USDC = '500'
const DEFAULT_SEND_AMOUNT = '25'

const server = new Horizon.Server(HORIZON_URL)

function createAccount() {
  const keypair = Keypair.random()
  return {
    publicKey: keypair.publicKey(),
    secret: keypair.secret(),
  }
}

function createState() {
  return {
    version: 1,
    network: 'Stellar Testnet',
    createdAt: new Date().toISOString(),
    accounts: {
      funding: createAccount(),
      phptIssuer: createAccount(),
      usdcIssuer: createAccount(),
      liquidityProvider: createAccount(),
      worker: createAccount(),
    },
    setup: {
      transactionHashes: [],
    },
    demos: [],
  }
}

async function saveJson(filePath, value) {
  await mkdir(localDirectory, { recursive: true })
  await writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 })
  await chmod(filePath, 0o600)
}

async function loadState({ create = false } = {}) {
  try {
    const state = JSON.parse(await readFile(statePath, 'utf8'))
    if (state.network !== 'Stellar Testnet') {
      throw new Error('Refusing to use a Week 1 state file that is not marked Stellar Testnet.')
    }
    return state
  } catch (error) {
    if (!create || error?.code !== 'ENOENT') throw error
    const state = createState()
    await saveJson(statePath, state)
    return state
  }
}

function keypair(account) {
  return Keypair.fromSecret(account.secret)
}

function transactionLink(hash) {
  return `${EXPLORER_URL}/tx/${hash}`
}

function assetSummary(asset) {
  return {
    code: asset.getCode(),
    issuer: asset.getIssuer(),
  }
}

function publicAccounts(state) {
  return Object.fromEntries(
    Object.entries(state.accounts).map(([role, account]) => [role, account.publicKey]),
  )
}

function scaledAmount(value) {
  const [whole = '0', fraction = ''] = String(value).trim().split('.')
  if (!/^\d+$/.test(whole) || (fraction && !/^\d+$/.test(fraction))) {
    throw new Error(`Invalid Stellar amount: ${value}`)
  }
  return BigInt(whole) * 10_000_000n + BigInt(fraction.padEnd(7, '0').slice(0, 7))
}

function formatAmount(value) {
  const negative = value < 0n
  const absolute = negative ? -value : value
  const whole = absolute / 10_000_000n
  const fraction = (absolute % 10_000_000n).toString().padStart(7, '0').replace(/0+$/, '')
  return `${negative ? '-' : ''}${whole}${fraction ? `.${fraction}` : ''}`
}

function minimumWithSlippage(quotedAmount) {
  return formatAmount((scaledAmount(quotedAmount) * 99n) / 100n)
}

function responseError(error) {
  const resultCodes = error?.response?.data?.extras?.result_codes
  const detail = error?.response?.data?.detail
  if (resultCodes) return `${error.message}: ${JSON.stringify(resultCodes)}`
  if (detail) return `${error.message}: ${detail}`
  return error instanceof Error ? error.message : String(error)
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

async function accountExists(publicKey) {
  try {
    await server.loadAccount(publicKey)
    return true
  } catch (error) {
    if (error?.response?.status === 404) return false
    throw error
  }
}

async function submit(account, operations) {
  const source = await server.loadAccount(account.publicKey)
  const fee = String(await server.fetchBaseFee())
  let builder = new TransactionBuilder(source, {
    fee,
    networkPassphrase: NETWORK_PASSPHRASE,
  })
  for (const operation of operations) builder = builder.addOperation(operation)
  const transaction = builder.setTimeout(180).build()
  transaction.sign(keypair(account))
  return server.submitTransaction(transaction)
}

async function fundBootstrap(state) {
  const funding = state.accounts.funding
  if (await accountExists(funding.publicKey)) return

  const response = await fetch(`${FRIENDBOT_URL}?addr=${encodeURIComponent(funding.publicKey)}`)
  if (!response.ok) {
    throw new Error(`Friendbot could not fund the local Testnet bootstrap account: ${await response.text()}`)
  }
}

async function createManagedAccounts(state) {
  const managed = Object.entries(state.accounts).filter(([role]) => role !== 'funding')
  const missing = []
  for (const [role, account] of managed) {
    if (!(await accountExists(account.publicKey))) missing.push([role, account])
  }
  if (missing.length === 0) return null

  const result = await submit(
    state.accounts.funding,
    missing.map(([, account]) => Operation.createAccount({
      destination: account.publicKey,
      startingBalance: STARTING_XLM,
    })),
  )
  return result.hash
}

function balanceLine(account, asset) {
  return account.balances.find((balance) => (
    balance.asset_type !== 'native'
      && balance.asset_code === asset.getCode()
      && balance.asset_issuer === asset.getIssuer()
  ))
}

async function assetBalance(publicKey, asset) {
  const account = await server.loadAccount(publicKey)
  return balanceLine(account, asset)?.balance ?? '0'
}

async function ensureTrustlines(account, assets) {
  const record = await server.loadAccount(account.publicKey)
  const missing = assets.filter((asset) => !balanceLine(record, asset))
  if (missing.length === 0) return null
  const result = await submit(
    account,
    missing.map((asset) => Operation.changeTrust({ asset })),
  )
  return result.hash
}

async function issueAtLeast(issuer, destination, asset, targetAmount) {
  const current = scaledAmount(await assetBalance(destination.publicKey, asset))
  const target = scaledAmount(targetAmount)
  if (current >= target) return null
  const amount = formatAmount(target - current)
  const result = await submit(issuer, [Operation.payment({
    destination: destination.publicKey,
    asset,
    amount,
  })])
  return result.hash
}

function horizonAssetMatches(record, asset) {
  if (asset.isNative()) return record.asset_type === 'native'
  return record.asset_code === asset.getCode() && record.asset_issuer === asset.getIssuer()
}

async function ensureLiquidityOffer(state, phpt, usdc) {
  const provider = state.accounts.liquidityProvider
  const page = await server.offers().forAccount(provider.publicKey).limit(200).call()
  const existing = page.records.find((offer) => (
    horizonAssetMatches(offer.selling, phpt) && horizonAssetMatches(offer.buying, usdc)
  ))
  if (existing) {
    return { id: existing.id, amount: existing.amount, hash: null }
  }

  const result = await submit(provider, [Operation.manageSellOffer({
    selling: phpt,
    buying: usdc,
    amount: PHPT_LIQUIDITY,
    price: '1',
  })])
  const refreshed = await server.offers().forAccount(provider.publicKey).limit(200).call()
  const created = refreshed.records.find((offer) => (
    horizonAssetMatches(offer.selling, phpt) && horizonAssetMatches(offer.buying, usdc)
  ))
  if (!created) throw new Error('The PHPT/USDC liquidity offer was submitted but could not be found.')
  return { id: created.id, amount: created.amount, hash: result.hash }
}

async function writeEvidence(state, extra = {}) {
  const phpt = new Asset('PHPT', state.accounts.phptIssuer.publicKey)
  const usdc = new Asset('USDC', state.accounts.usdcIssuer.publicKey)
  const evidence = {
    generatedAt: new Date().toISOString(),
    network: state.network,
    horizonUrl: HORIZON_URL,
    warning: 'Test assets only. The USDC asset is controlled for this demo and has no real value.',
    accounts: publicAccounts(state),
    assets: {
      phpt: assetSummary(phpt),
      usdc: assetSummary(usdc),
    },
    setup: state.setup,
    latestDemo: state.demos.at(-1) ?? null,
    ...extra,
  }
  await saveJson(evidencePath, evidence)
}

async function setup() {
  const state = await loadState({ create: true })
  const phpt = new Asset('PHPT', state.accounts.phptIssuer.publicKey)
  const usdc = new Asset('USDC', state.accounts.usdcIssuer.publicKey)
  const hashes = []

  console.log('Setting up controlled Week 1 assets on Stellar Testnet...')
  await fundBootstrap(state)

  const accountsHash = await createManagedAccounts(state)
  if (accountsHash) hashes.push(accountsHash)

  for (const [account, assets] of [
    [state.accounts.liquidityProvider, [phpt, usdc]],
    [state.accounts.worker, [phpt, usdc]],
  ]) {
    const hash = await ensureTrustlines(account, assets)
    if (hash) hashes.push(hash)
  }

  const phptHash = await issueAtLeast(
    state.accounts.phptIssuer,
    state.accounts.liquidityProvider,
    phpt,
    PHPT_LIQUIDITY,
  )
  if (phptHash) hashes.push(phptHash)

  const usdcHash = await issueAtLeast(
    state.accounts.usdcIssuer,
    state.accounts.worker,
    usdc,
    WORKER_USDC,
  )
  if (usdcHash) hashes.push(usdcHash)

  const offer = await ensureLiquidityOffer(state, phpt, usdc)
  if (offer.hash) hashes.push(offer.hash)

  state.setup = {
    completedAt: new Date().toISOString(),
    offerId: offer.id,
    offerAmount: offer.amount,
    price: '1 USDC = 1 PHPT',
    transactionHashes: [...new Set([...(state.setup.transactionHashes ?? []), ...hashes])],
  }
  await saveJson(statePath, state)
  await writeEvidence(state)

  console.log('\nWeek 1 setup complete.')
  console.log(`PHPT issuer: ${state.accounts.phptIssuer.publicKey}`)
  console.log(`Test-USDC issuer: ${state.accounts.usdcIssuer.publicKey}`)
  console.log(`Liquidity provider: ${state.accounts.liquidityProvider.publicKey}`)
  console.log(`Worker: ${state.accounts.worker.publicKey}`)
  console.log(`Offer: ${offer.id} (${offer.amount} PHPT available at 1:1)`)
  if (hashes.length > 0) {
    console.log('\nNew setup transactions:')
    for (const hash of hashes) console.log(`- ${transactionLink(hash)}`)
  } else {
    console.log('\nExisting local Testnet setup is still ready; no setup transaction was needed.')
  }
  return state
}

function pathAsset(record) {
  if (record.asset_type === 'native') return Asset.native()
  return new Asset(record.asset_code, record.asset_issuer)
}

async function findStrictSendPath(sourceAsset, sourceAmount, destinationAsset) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const paths = await server.strictSendPaths(sourceAsset, sourceAmount, [destinationAsset]).call()
    const quote = paths.records.find((record) => record.path.length === 0) ?? paths.records[0]
    if (quote) return quote
    if (attempt < 9) await wait(2_000)
  }
  return null
}

async function runDemo() {
  const state = await loadState()
  if (!state.setup?.offerId) {
    throw new Error('Week 1 setup is missing. Run `npm run week1:setup` first.')
  }

  const phpt = new Asset('PHPT', state.accounts.phptIssuer.publicKey)
  const usdc = new Asset('USDC', state.accounts.usdcIssuer.publicKey)
  const worker = state.accounts.worker
  const sendAmount = process.env.WEEK1_SEND_AMOUNT?.trim() || DEFAULT_SEND_AMOUNT
  if (scaledAmount(sendAmount) <= 0n) throw new Error('WEEK1_SEND_AMOUNT must be greater than zero.')

  const before = {
    usdc: await assetBalance(worker.publicKey, usdc),
    phpt: await assetBalance(worker.publicKey, phpt),
  }
  if (scaledAmount(before.usdc) < scaledAmount(sendAmount)) {
    throw new Error(`Worker has ${before.usdc} test-USDC but the demo needs ${sendAmount}. Run \`npm run week1:setup\` to top it up.`)
  }

  const quote = await findStrictSendPath(usdc, sendAmount, phpt)
  if (!quote) throw new Error('No viable Testnet path exists from the controlled USDC asset to PHPT.')

  const quotedReceive = quote.destination_amount
  const minimumReceive = minimumWithSlippage(quotedReceive)
  const result = await submit(worker, [Operation.pathPaymentStrictSend({
    sendAsset: usdc,
    sendAmount,
    destination: worker.publicKey,
    destAsset: phpt,
    destMin: minimumReceive,
    path: quote.path.map(pathAsset),
  })])

  const after = {
    usdc: await assetBalance(worker.publicKey, usdc),
    phpt: await assetBalance(worker.publicKey, phpt),
  }
  const received = formatAmount(scaledAmount(after.phpt) - scaledAmount(before.phpt))
  const spent = formatAmount(scaledAmount(before.usdc) - scaledAmount(after.usdc))
  const demo = {
    completedAt: new Date().toISOString(),
    transactionHash: result.hash,
    transactionUrl: transactionLink(result.hash),
    sendAsset: assetSummary(usdc),
    destinationAsset: assetSummary(phpt),
    sendAmount,
    quotedReceive,
    minimumReceive,
    actualSpent: spent,
    actualReceived: received,
    route: quote.path.map((asset) => ({
      code: asset.asset_type === 'native' ? 'XLM' : asset.asset_code,
      issuer: asset.asset_issuer ?? null,
    })),
    balances: { before, after },
  }
  state.demos.push(demo)
  await saveJson(statePath, state)
  await writeEvidence(state)

  console.log('\nUSDC -> PHPT path-payment result')
  console.log('Asset       Before        Change         After')
  console.log(`USDC        ${before.usdc.padEnd(13)} -${spent.padEnd(13)} ${after.usdc}`)
  console.log(`PHPT        ${before.phpt.padEnd(13)} +${received.padEnd(13)} ${after.phpt}`)
  console.log(`\nTransaction: ${transactionLink(result.hash)}`)
  console.log(`Local evidence: ${evidencePath}`)
  return demo
}

async function verify() {
  const state = await loadState()
  const demo = state.demos.at(-1)
  if (!demo) throw new Error('No Week 1 demo result exists. Run `npm run week1:demo` first.')

  const transaction = await server.transactions().transaction(demo.transactionHash).call()
  const phpt = new Asset('PHPT', state.accounts.phptIssuer.publicKey)
  const usdc = new Asset('USDC', state.accounts.usdcIssuer.publicKey)
  const offers = await server.offers().forAccount(state.accounts.liquidityProvider.publicKey).limit(200).call()
  const offer = offers.records.find((record) => (
    horizonAssetMatches(record.selling, phpt) && horizonAssetMatches(record.buying, usdc)
  ))

  const checks = {
    transactionSuccessful: transaction.successful === true,
    spentExpectedUSDC: scaledAmount(demo.actualSpent) === scaledAmount(demo.sendAmount),
    receivedAtLeastMinimum: scaledAmount(demo.actualReceived) >= scaledAmount(demo.minimumReceive),
    liquidityOfferStillOpen: Boolean(offer),
  }
  const passed = Object.values(checks).every(Boolean)
  await writeEvidence(state, {
    verification: {
      verifiedAt: new Date().toISOString(),
      passed,
      checks,
      remainingOfferAmount: offer?.amount ?? '0',
    },
  })

  console.log('\nWeek 1 verification')
  for (const [name, value] of Object.entries(checks)) {
    console.log(`${value ? 'PASS' : 'FAIL'}  ${name}`)
  }
  console.log(`Evidence: ${evidencePath}`)
  if (!passed) throw new Error('One or more Week 1 verification checks failed.')
}

async function main() {
  const command = process.argv[2] ?? 'all'
  if (command === 'setup') await setup()
  else if (command === 'demo') await runDemo()
  else if (command === 'verify') await verify()
  else if (command === 'all') {
    await setup()
    await runDemo()
    await verify()
  } else {
    throw new Error('Use one of: setup, demo, verify, all')
  }
}

main().catch((error) => {
  console.error(`\nWeek 1 command failed: ${responseError(error)}`)
  process.exitCode = 1
})

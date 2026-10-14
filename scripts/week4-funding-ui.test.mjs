import test, { after } from 'node:test'
import assert from 'node:assert/strict'
import { createElement } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { createServer } from 'vite'

const server = await createServer({
  mode: 'test', logLevel: 'error',
  server: { middlewareMode: true, hmr: false, watch: null },
  // The presentational view receives account state as props, not a live wallet.
  plugins: [{
    name: 'funding-view-test-account', enforce: 'pre',
    resolveId(source, importer) {
      if (importer?.endsWith('/src/features/account/AccountSetupPrompts.tsx') && source === '../../state/account') return '\0test-account'
    },
    load(id) {
      if (id === '\0test-account') return 'export function useAccount() { throw new Error("Render the view with explicit test state") }'
    },
  }],
})
after(() => server.close())
const { AccountSetupPromptsView } = await server.ssrLoadModule('/src/features/account/AccountSetupPrompts.tsx')
const notCalled = () => assert.fail('Rendering must not fund or sign')
const base = {
  address: 'test-public-address', assetCode: 'USDC',
  needsFunding: false, needsTrustline: false, funding: false, enabling: false,
  fundingAsset: false, fundingReceipt: null, error: null,
  balances: { xlm: 10000, asset: 0, reservedXlm: 1.5 }, faucet: {},
  fund: notCalled, enableAsset: notCalled, refresh: notCalled, fundAsset: notCalled,
}
const render = (change = {}, props = {}) => renderToStaticMarkup(createElement(AccountSetupPromptsView, {
  account: { ...base, ...change }, trustlineMessage: 'Add a trustline.', ...props,
}))

test('an empty, trusted USDC wallet can request test funding', () => {
  assert.match(render(), /Get 25 test-USDC/)
})

for (const amount of [0.0000001, 1, 24.99, 25, 100]) {
  test(`hide USDC funding controls when the wallet already holds ${amount}`, () => {
    const html = render({ balances: { ...base.balances, asset: amount } })
    assert.doesNotMatch(html, /Get 25 test-USDC|test-USDC available/)
  })
}

test('a funding receipt remains available after its button is hidden', () => {
  const html = render({ balances: { ...base.balances, asset: 25 }, fundingReceipt: { status: 'funded', hash: 'a'.repeat(64) } })
  assert.doesNotMatch(html, /Get 25 test-USDC/)
  assert.match(html, /Test-USDC received/)
  assert.match(html, /View funding transaction/)
})

test('unknown, non-finite, negative and non-USDC balances do not offer funding', () => {
  for (const balances of [null, { ...base.balances, asset: NaN }, { ...base.balances, asset: -1 }]) {
    assert.doesNotMatch(render({ balances }), /Get 25 test-USDC/)
  }
  assert.doesNotMatch(render({ assetCode: 'XLM' }), /Get 25 test-USDC/)
  assert.doesNotMatch(render({}, { showTestUsdcFunding: false }), /Get 25 test-USDC/)
})

test('pending funding stays visible with its transaction link and cannot be repeated', () => {
  const html = render({ fundingReceipt: { status: 'pending', hash: 'a'.repeat(64) } })
  assert.match(html, /disabled=""/)
  assert.match(html, /Funding confirmation pending/)
  assert.match(html, /View funding transaction/)
})

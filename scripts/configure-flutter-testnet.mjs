import { readFile, writeFile } from 'node:fs/promises'
import { StrKey } from '@stellar/stellar-sdk'

const evidence = JSON.parse(await readFile(new URL('../.sweldo-local/week1-result.json', import.meta.url), 'utf8'))
const { usdc, phpt } = evidence.assets ?? {}
if (evidence.network !== 'Stellar Testnet' || usdc?.code !== 'USDC' || phpt?.code !== 'PHPT'
  || !StrKey.isValidEd25519PublicKey(usdc.issuer) || !StrKey.isValidEd25519PublicKey(phpt.issuer)) {
  throw new Error('The verified public Week 1 Testnet asset identities are required.')
}
const path = new URL('../sweldo_flutter/config/testnet.local.json', import.meta.url)
const current = JSON.parse(await readFile(path, 'utf8').catch((error) => {
  if (error.code === 'ENOENT') return '{}'
  throw error
}))
await writeFile(path, JSON.stringify({ ...current,
  SWELDO_ASSET_CODE: usdc.code, SWELDO_ASSET_ISSUER: usdc.issuer, SWELDO_PHPT_ISSUER: phpt.issuer,
  SWELDO_TEST_FAUCET_URL: current.SWELDO_TEST_FAUCET_URL ?? 'http://localhost:5174',
}, null, 2) + '\n', { mode: 0o600 })
console.log('Flutter now uses the same controlled USDC/PHPT Testnet pair. Existing registry and WalletConnect settings were preserved. No transactions were sent.')

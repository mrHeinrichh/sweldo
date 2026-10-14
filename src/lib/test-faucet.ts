export const TEST_FAUCET_PATH = '/__sweldo_local/test-usdc'

export type TestFaucet = { network: 'Stellar Testnet'; code: 'USDC'; issuer: string; amount: '25'; token: string }
export type TestFundingReceipt = { status: 'funded' | 'already-funded' | 'pending'; amount: string; hash?: string }

export async function localTestFaucet(issuer: string): Promise<TestFaucet | null> {
  if (!import.meta.env.DEV || import.meta.env.MODE !== 'week4') return null
  try {
    const response = await fetch(TEST_FAUCET_PATH, { cache: 'no-store' })
    const result = await response.json()
    return response.ok && result.network === 'Stellar Testnet' && result.code === 'USDC' && result.issuer === issuer
      && result.amount === '25' && typeof result.token === 'string' ? result : null
  } catch { return null }
}

export async function requestTestUsdc(faucet: TestFaucet, address: string): Promise<TestFundingReceipt> {
  const response = await fetch(TEST_FAUCET_PATH, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Sweldo-Test-Faucet-Token': faucet.token },
    body: JSON.stringify({ address }),
  })
  const result = await response.json()
  if (!response.ok) throw new Error(result.error || 'Test funding was not confirmed.')
  if (!['funded', 'already-funded', 'pending'].includes(result.status) || result.address !== address
    || result.network !== 'Stellar Testnet' || result.issuer !== faucet.issuer
    || (result.status !== 'already-funded' && !/^[a-f0-9]{64}$/.test(result.hash ?? ''))) {
    throw new Error('Invalid Testnet funding receipt. Check the wallet before retrying.')
  }
  return result
}

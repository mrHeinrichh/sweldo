import { configuredConversion } from '../lib/claim-convert'
import { payrollAssetOptions } from '../lib/payroll-assets'

// Build-time configuration (VITE_*), the same switches as the Flutter
// app's --dart-define values. Leave the asset blank for the XLM demo.

const env = import.meta.env

export const config = {
  assetCode: env.VITE_ASSET_CODE?.trim() ?? '',
  assetIssuer: env.VITE_ASSET_ISSUER?.trim() ?? '',
  registryContractId: env.VITE_PAYROLL_REGISTRY_CONTRACT_ID?.trim() ?? '',
}

export const payrollAssets = payrollAssetOptions(config.assetCode, config.assetIssuer)
export const assetLabel = 'XLM'
export const hasRegistry = config.registryContractId.length > 0
export const conversionPair = configuredConversion(env)

export const MAX_OPERATIONS = 100
export const MAX_PAYOUTS_PER_EMPLOYEE = 50

const EXPLORER = 'https://stellar.expert/explorer/testnet'
export const explorer = {
  home: EXPLORER,
  transaction: (hash: string) => `${EXPLORER}/tx/${hash}`,
  claimableBalance: (id: string) => `${EXPLORER}/claimable-balance/${id}`,
  contract: (id: string) => `${EXPLORER}/contract/${id}`,
  account: (id: string) => `${EXPLORER}/account/${id}`,
}

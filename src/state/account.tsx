import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import type { Asset } from '@stellar/stellar-sdk'
import { addTrustline, fundWithFriendbot, getBalances, hasTrustline, isAccountFunded, type WalletBalances } from '../lib/stellar'
import { payrollAssets } from './config'
import { friendlyError } from './errors'
import { useWallet } from './wallet'
import { localTestFaucet, requestTestUsdc, type TestFaucet, type TestFundingReceipt } from '../lib/test-faucet'

// Port of AccountSetupCubit: the "Get free test XLM" and "Enable USDC"
// prompts, plus balances for the payroll coverage check.

type AccountState = {
  address: string | null
  balances: WalletBalances | null
  needsFunding: boolean
  needsTrustline: boolean
  funding: boolean
  enabling: boolean
  error: string | null
  faucet: TestFaucet | null
  fundingAsset: boolean
  fundingReceipt: TestFundingReceipt | null
}

type AccountContextValue = AccountState & {
  assetCode: string
  asset: Asset
  assetId: string
  selectAsset: (id: string) => boolean
  fund: () => void
  enableAsset: () => void
  refresh: () => void
  fundAsset: () => void
}

const EMPTY: AccountState = { address: null, balances: null, needsFunding: false, needsTrustline: false, funding: false, enabling: false, error: null, faucet: null, fundingAsset: false, fundingReceipt: null }
const AccountContext = createContext<AccountContextValue | null>(null)
type Scope = { address: string | null; asset: Asset }

export function AccountProvider({ children, assetOverride }: { children: ReactNode; assetOverride?: Asset }) {
  const { session } = useWallet()
  const [selected, setSelected] = useState(payrollAssets[0])
  const asset = assetOverride ?? selected.asset
  const address = session?.onTestnet ? session.address : null
  const scope = useMemo<Scope>(() => ({ address, asset }), [address, asset])
  const current = useRef(scope)
  current.current = scope
  const [snapshot, setSnapshot] = useState<{ scope: Scope | null; value: AccountState }>({ scope: null, value: EMPTY })
  const state = useMemo(() => snapshot.scope === scope ? snapshot.value : { ...EMPTY, address }, [snapshot, scope, address])
  const busy = useRef(false)
  const stateRef = useRef(state)
  stateRef.current = state
  // Discard reads for a previous wallet or asset, even after switching back.
  const patch = useCallback((target: Scope, next: Partial<AccountState>) => {
    if (current.current !== target) return
    setSnapshot((previous) => ({ scope: target, value: { ...(previous.scope === target ? previous.value : { ...EMPTY, address: target.address }), ...next } }))
  }, [])

  const loadBalances = useCallback(async (target: Scope) => {
    if (!target.address) return
    try { patch(target, { balances: await getBalances(target.address, target.asset) }) } catch { /* coverage is a hint */ }
  }, [patch])

  const check = useCallback(async (target: Scope) => {
    if (!target.address) return
    try {
      const funded = await isAccountFunded(target.address)
      if (!funded) {
        patch(target, { needsFunding: true, needsTrustline: false, balances: null })
        return
      }
      const trusted = target.asset.isNative() || await hasTrustline(target.address, target.asset)
      patch(target, { needsFunding: !funded, needsTrustline: !trusted })
      await loadBalances(target)
    } catch { /* a failed lookup must not block the page */ }
  }, [loadBalances, patch])

  useEffect(() => {
    setSnapshot({ scope, value: { ...EMPTY, address } })
    if (address) {
      void check(scope)
      const issuer = asset.getIssuer()
      if (issuer) void localTestFaucet(issuer).then((faucet) => patch(scope, { faucet }))
    }
  }, [address, asset, scope, check, patch])

  const selectAsset = useCallback((id: string) => {
    const option = payrollAssets.find((candidate) => candidate.id === id)
    if (!option || assetOverride || busy.current) return false
    setSelected(option)
    return true
  }, [assetOverride])

  const refresh = useCallback(() => check(scope), [check, scope])

  const fund = useCallback(async () => {
    const target = scope
    if (!target.address || busy.current) return
    busy.current = true
    patch(target, { funding: true, error: null })
    try {
      await fundWithFriendbot(target.address)
      await check(target)
    } catch (error) {
      patch(target, { error: friendlyError(error) })
    } finally {
      busy.current = false
      patch(target, { funding: false })
    }
  }, [scope, patch, check])

  const enableAsset = useCallback(async () => {
    const target = scope
    if (!target.address || target.asset.isNative() || busy.current) return
    busy.current = true
    patch(target, { enabling: true, error: null })
    try {
      await addTrustline(target.address, target.asset)
      await check(target)
    } catch (error) {
      patch(target, { error: friendlyError(error) })
    } finally {
      busy.current = false
      patch(target, { enabling: false })
    }
  }, [scope, patch, check])

  const fundAsset = useCallback(async () => {
    const target = scope
    const faucet = stateRef.current.faucet
    if (!target.address || target.asset.isNative() || !faucet || busy.current || stateRef.current.fundingReceipt?.status === 'pending') return
    busy.current = true
    patch(target, { fundingAsset: true, error: null })
    try {
      const receipt = await requestTestUsdc(faucet, target.address)
      patch(target, { fundingReceipt: receipt })
      await loadBalances(target)
    } catch (error) {
      patch(target, { error: friendlyError(error) })
    } finally {
      busy.current = false
      patch(target, { fundingAsset: false })
    }
  }, [scope, patch, loadBalances])

  const value = useMemo<AccountContextValue>(() => ({
    ...state,
    asset,
    assetId: asset.isNative() ? 'native' : `${asset.getCode()}:${asset.getIssuer()}`,
    assetCode: asset.getCode(),
    selectAsset,
    fund: () => { void fund() },
    enableAsset: () => { void enableAsset() },
    refresh: () => { void refresh() },
    fundAsset: () => { void fundAsset() },
  }), [state, asset, selectAsset, fund, enableAsset, refresh, fundAsset])

  return <AccountContext.Provider value={value}>{children}</AccountContext.Provider>
}

export function useAccount() {
  const value = useContext(AccountContext)
  if (!value) throw new Error('useAccount needs an AccountProvider.')
  return value
}

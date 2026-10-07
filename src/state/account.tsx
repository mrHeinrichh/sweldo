import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { addTrustline, fundWithFriendbot, getBalances, hasTrustline, isAccountFunded, type WalletBalances } from '../lib/stellar'
import { assetLabel, payrollAsset } from './config'
import { friendlyError } from './errors'
import { useWallet } from './wallet'

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
}

type AccountContextValue = AccountState & {
  assetCode: string
  fund: () => void
  enableAsset: () => void
  refresh: () => void
}

const EMPTY: AccountState = { address: null, balances: null, needsFunding: false, needsTrustline: false, funding: false, enabling: false, error: null }
const AccountContext = createContext<AccountContextValue | null>(null)

export function AccountProvider({ children }: { children: ReactNode }) {
  const { session } = useWallet()
  const [state, setState] = useState<AccountState>(EMPTY)
  const current = useRef<string | null>(null)
  const patch = useCallback((address: string, next: Partial<AccountState>) => {
    if (current.current === address) setState((previous) => ({ ...previous, ...next }))
  }, [])

  const loadBalances = useCallback(async (address: string) => {
    try { patch(address, { balances: await getBalances(address, payrollAsset) }) } catch { /* coverage is a hint */ }
  }, [patch])

  const check = useCallback(async (address: string) => {
    try {
      const funded = await isAccountFunded(address)
      patch(address, { needsFunding: !funded })
      await loadBalances(address)
      if (payrollAsset.isNative()) return
      const trusted = await hasTrustline(address, payrollAsset)
      patch(address, { needsTrustline: !trusted })
    } catch { /* a failed lookup must not block the page */ }
  }, [loadBalances, patch])

  const address = session?.onTestnet ? session.address : null
  useEffect(() => {
    current.current = address
    setState({ ...EMPTY, address })
    if (address) void check(address)
  }, [address, check])

  const refresh = useCallback(async () => {
    const target = current.current
    if (!target) return
    try {
      const funded = await isAccountFunded(target)
      const trusted = payrollAsset.isNative() || await hasTrustline(target, payrollAsset)
      patch(target, { needsFunding: !funded, needsTrustline: !trusted })
      await loadBalances(target)
    } catch { /* ignore */ }
  }, [loadBalances, patch])

  const fund = useCallback(async () => {
    const target = current.current
    if (!target || state.funding) return
    patch(target, { funding: true, error: null })
    try {
      await fundWithFriendbot(target)
      const funded = await isAccountFunded(target)
      patch(target, { funding: false, needsFunding: !funded })
      if (funded) await refresh()
    } catch (error) {
      patch(target, { funding: false, error: friendlyError(error) })
    }
  }, [patch, refresh, state.funding])

  const enableAsset = useCallback(async () => {
    const target = current.current
    if (!target || state.enabling) return
    patch(target, { enabling: true, error: null })
    try {
      await addTrustline(target, payrollAsset)
      const trusted = await hasTrustline(target, payrollAsset)
      patch(target, { enabling: false, needsTrustline: !trusted })
    } catch (error) {
      patch(target, { enabling: false, error: friendlyError(error) })
    }
  }, [patch, state.enabling])

  const value = useMemo<AccountContextValue>(() => ({
    ...state,
    assetCode: assetLabel,
    fund: () => { void fund() },
    enableAsset: () => { void enableAsset() },
    refresh: () => { void refresh() },
  }), [state, fund, enableAsset, refresh])

  return <AccountContext.Provider value={value}>{children}</AccountContext.Provider>
}

export function useAccount() {
  const value = useContext(AccountContext)
  if (!value) throw new Error('useAccount needs an AccountProvider.')
  return value
}

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { horizonReader, reconstructPayroll } from '../lib/payroll-ledger'
import { cancelBalances, NETWORK_PASSPHRASE } from '../lib/stellar'
import { currentAccount } from '../lib/wallets'
import type { NoticeData } from '../ui/Notice'
import { plural } from '../ui/format'
import { explorer } from './config'
import { friendlyError } from './errors'
import { cancellableBalanceIds, onSchedulesChanged, type PayrollSchedule } from './schedules-store'
import { useWallet, type WalletSession } from './wallet'

type SchedulesState = {
  schedules: PayrollSchedule[]
  address: string | null
  activeBalanceIds: Set<string>
  balancesLoaded: boolean
  loading: boolean
  checkedAt: string | null
  cancellingId: string | null
  notice: NoticeData | null
}
type SchedulesApi = SchedulesState & {
  cancellableFor: (schedule: PayrollSchedule, now: Date) => string[]
  inspect: (address: string) => void
  refresh: () => void
  cancel: (schedule: PayrollSchedule, session: WalletSession) => void
  dismissNotice: () => void
}
const empty = (): SchedulesState => ({
  schedules: [], address: null, activeBalanceIds: new Set(), balancesLoaded: false,
  loading: false, checkedAt: null, cancellingId: null, notice: null,
})
const SchedulesContext = createContext<SchedulesApi | null>(null)

export function SchedulesProvider({ children }: { children: ReactNode }) {
  const { session } = useWallet()
  const [state, setState] = useState<SchedulesState>(empty)
  const stateRef = useRef(state)
  stateRef.current = state
  const targetRef = useRef<string | null>(null)
  const requestRef = useRef<AbortController | null>(null)
  const labels = useRef(new Map<string, Pick<PayrollSchedule, 'name' | 'registryHash' | 'registryContractId'>>())

  const load = useCallback(async (address: string) => {
    requestRef.current?.abort()
    const controller = new AbortController()
    requestRef.current = controller
    targetRef.current = address
    setState((previous) => ({
      ...previous, address, schedules: previous.address === address ? previous.schedules : [],
      activeBalanceIds: new Set(), balancesLoaded: false, loading: true, checkedAt: null, notice: null,
    }))
    try {
      const result = await reconstructPayroll(address, { read: horizonReader(controller.signal) })
      if (controller.signal.aborted || targetRef.current !== address) return
      const schedules = result.schedules.map((schedule) => ({
        ...schedule, ...labels.current.get(`${schedule.hash}:${schedule.employee}`),
      }))
      setState((previous) => ({
        ...previous, schedules, loading: false, balancesLoaded: true, checkedAt: result.checkedAt,
        activeBalanceIds: new Set(schedules.flatMap((schedule) => schedule.payouts?.filter((payout) => payout.active).map((payout) => payout.balanceId) ?? [])),
        notice: result.warnings.length ? { tone: 'error', text: `${result.warnings.length} payout statuses could not be verified. Refresh before managing those payouts.` } : null,
      }))
    } catch (error) {
      if (controller.signal.aborted || targetRef.current !== address) return
      setState((previous) => ({ ...previous, loading: false, balancesLoaded: false, notice: { tone: 'error', text: friendlyError(error) } }))
    }
  }, [])

  const address = session?.address ?? null
  useEffect(() => {
    if (address) void load(address)
    else {
      requestRef.current?.abort()
      targetRef.current = null
      setState(empty())
    }
    return () => { requestRef.current?.abort() }
  }, [address, load])

  useEffect(() => onSchedulesChanged((change) => {
    for (const schedule of change.schedules) labels.current.set(`${schedule.hash}:${schedule.employee}`, {
      name: schedule.name, registryHash: schedule.registryHash, registryContractId: schedule.registryContractId,
    })
    if (targetRef.current) void load(targetRef.current)
  }), [load])

  const refresh = useCallback(() => { if (targetRef.current) void load(targetRef.current) }, [load])
  const cancel = useCallback(async (schedule: PayrollSchedule, wallet: WalletSession) => {
    if (stateRef.current.cancellingId) return
    if (!wallet.onTestnet || schedule.employer !== wallet.address) {
      setState((previous) => ({ ...previous, notice: { tone: 'error', text: 'Connect the employer wallet on Testnet to cancel its future payouts.' } }))
      return
    }
    setState((previous) => ({ ...previous, cancellingId: schedule.id, notice: null }))
    try {
      const activeWallet = await currentAccount()
      if (activeWallet.address !== wallet.address || activeWallet.network !== 'TESTNET'
        || (activeWallet.networkPassphrase && activeWallet.networkPassphrase !== NETWORK_PASSPHRASE)) {
        throw new Error('The wallet account or network changed. Reconnect the employer on Testnet.')
      }
      // Reconstruct again before signing, rather than trusting the displayed snapshot.
      const latest = await reconstructPayroll(wallet.address)
      const current = latest.schedules.find((item) => item.id === schedule.id)
      if (!current) throw new Error('This payroll could not be verified on Horizon. Refresh and try again.')
      const active = new Set(current.payouts?.filter((payout) => payout.active).map((payout) => payout.balanceId))
      const ids = cancellableBalanceIds(current, active, new Date())
      if (!ids.length) throw new Error('No future payouts remain. Payouts at or past payday cannot be cancelled.')
      const response = await cancelBalances(wallet.address, ids)
      if (targetRef.current === wallet.address) {
        await load(wallet.address)
        setState((previous) => ({ ...previous, notice: {
          tone: 'success', text: `${ids.length} future ${plural(ids.length, 'payout was', 'payouts were')} returned to your wallet.`,
          link: explorer.transaction(response.hash), linkLabel: 'View cancellation',
        } }))
      }
    } catch (error) {
      if (targetRef.current === wallet.address) setState((previous) => ({ ...previous, notice: { tone: 'error', text: friendlyError(error) } }))
    } finally {
      setState((previous) => ({ ...previous, cancellingId: null }))
    }
  }, [load])

  const api = useMemo<SchedulesApi>(() => ({
    ...state,
    cancellableFor: (schedule, now) => state.balancesLoaded && !state.loading ? cancellableBalanceIds(schedule, state.activeBalanceIds, now) : [],
    inspect: (address) => { void load(address.trim()) }, refresh,
    cancel: (schedule, wallet) => { void cancel(schedule, wallet) },
    dismissNotice: () => setState((previous) => ({ ...previous, notice: null })),
  }), [state, load, refresh, cancel])
  return <SchedulesContext.Provider value={api}>{children}</SchedulesContext.Provider>
}

export function useSchedules() {
  const value = useContext(SchedulesContext)
  if (!value) throw new Error('useSchedules needs a SchedulesProvider.')
  return value
}

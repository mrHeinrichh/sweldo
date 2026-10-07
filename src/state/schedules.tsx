import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { cancelBalances, getClaimableBalances } from '../lib/stellar'
import type { NoticeData } from '../ui/Notice'
import { plural } from '../ui/format'
import { explorer } from './config'
import { friendlyError } from './errors'
import { cancellableBalanceIds, onSchedulesChanged, readSchedules, updateSchedule, type PayrollSchedule } from './schedules-store'
import { useWallet, type WalletSession } from './wallet'

// Port of SchedulesBloc: recent schedules and cancelling their future payouts.

type SchedulesState = {
  schedules: PayrollSchedule[]
  address: string | null
  activeBalanceIds: Set<string>
  balancesLoaded: boolean
  cancellingId: string | null
  notice: NoticeData | null
}

type SchedulesApi = SchedulesState & {
  cancellableFor: (schedule: PayrollSchedule, now: Date) => string[]
  refresh: () => void
  cancel: (schedule: PayrollSchedule, session: WalletSession) => void
  dismissNotice: () => void
}

const SchedulesContext = createContext<SchedulesApi | null>(null)

async function activeIds(address: string) {
  return (await getClaimableBalances(address)).map((record) => record.balance_id)
}

export function SchedulesProvider({ children }: { children: ReactNode }) {
  const { session } = useWallet()
  const [state, setState] = useState<SchedulesState>(() => ({
    schedules: readSchedules(), address: null, activeBalanceIds: new Set(), balancesLoaded: false, cancellingId: null, notice: null,
  }))
  const addressRef = useRef<string | null>(null)
  const stateRef = useRef(state)
  stateRef.current = state

  const load = useCallback(async (address: string) => {
    try {
      const ids = await activeIds(address)
      if (addressRef.current !== address) return
      setState((previous) => ({ ...previous, activeBalanceIds: new Set(ids), balancesLoaded: true }))
    } catch {
      if (addressRef.current !== address) return
      setState((previous) => ({ ...previous, activeBalanceIds: new Set(), balancesLoaded: true }))
    }
  }, [])

  const address = session?.address ?? null
  useEffect(() => {
    addressRef.current = address
    setState((previous) => ({ ...previous, address, activeBalanceIds: new Set(), balancesLoaded: false }))
    if (address) void load(address)
  }, [address, load])

  useEffect(() => onSchedulesChanged((change) => {
    setState((previous) => {
      const active = new Set([...previous.activeBalanceIds, ...change.added])
      change.removed.forEach((id) => active.delete(id))
      return { ...previous, schedules: change.schedules, activeBalanceIds: active, balancesLoaded: previous.balancesLoaded || change.added.length > 0 }
    })
  }), [])

  const refresh = useCallback(() => {
    const target = addressRef.current
    if (!target) return
    setState((previous) => ({ ...previous, balancesLoaded: false }))
    void load(target)
  }, [load])

  const cancel = useCallback(async (schedule: PayrollSchedule, wallet: WalletSession) => {
    if (stateRef.current.cancellingId) return
    if (!wallet.onTestnet) {
      setState((previous) => ({ ...previous, notice: { tone: 'error', text: 'Switch Freighter to Testnet, then reconnect.' } }))
      return
    }
    if (schedule.employer !== wallet.address) {
      setState((previous) => ({ ...previous, notice: { tone: 'error', text: 'Connect the employer wallet that originally funded this payroll.' } }))
      return
    }
    setState((previous) => ({ ...previous, cancellingId: schedule.id, notice: null }))
    try {
      // Re-check the ledger: a payout may have reached payday since the confirmation was shown.
      const latest = new Set(await activeIds(wallet.address))
      setState((previous) => ({ ...previous, activeBalanceIds: latest, balancesLoaded: true }))
      const ids = cancellableBalanceIds(schedule, latest, new Date())
      if (ids.length === 0) throw new Error('No future payouts remain. Payouts at or past payday cannot be cancelled.')
      const response = await cancelBalances(wallet.address, ids)
      updateSchedule(schedule.id, (saved) => ({
        ...saved,
        cancelledAt: new Date().toISOString(),
        cancelHash: response.hash,
        cancelledPayouts: (saved.cancelledPayouts ?? 0) + ids.length,
      }), ids)
      setState((previous) => ({
        ...previous,
        cancellingId: null,
        notice: {
          tone: 'success',
          text: `${ids.length} future ${plural(ids.length, 'payout was', 'payouts were')} cancelled and returned to your wallet.`,
          link: explorer.transaction(response.hash),
          linkLabel: 'View cancellation',
        },
      }))
    } catch (error) {
      setState((previous) => ({ ...previous, cancellingId: null, notice: { tone: 'error', text: friendlyError(error) } }))
    }
  }, [])

  const api = useMemo<SchedulesApi>(() => ({
    ...state,
    cancellableFor: (schedule, now) => cancellableBalanceIds(schedule, state.activeBalanceIds, now),
    refresh,
    cancel: (schedule, wallet) => { void cancel(schedule, wallet) },
    dismissNotice: () => setState((previous) => ({ ...previous, notice: null })),
  }), [state, refresh, cancel])

  return <SchedulesContext.Provider value={api}>{children}</SchedulesContext.Provider>
}

export function useSchedules() {
  const value = useContext(SchedulesContext)
  if (!value) throw new Error('useSchedules needs a SchedulesProvider.')
  return value
}

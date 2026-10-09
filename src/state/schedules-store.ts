// Confirmed ledger state plus optional labels for the current session.

export type PayrollPayout = {
  balanceId: string
  amount: string
  unlockAt: string
  active: boolean
  status: 'scheduled' | 'claimable' | 'claimed' | 'cancelled' | 'unknown'
  settlementHash?: string
  settledAt?: string
}

export type PayrollSchedule = {
  id: string
  employee: string
  name: string
  total: string
  tranches: number
  asset: string
  createdAt: string
  hash: string
  employer?: string
  balanceIds: string[]
  firstUnlock?: string
  intervalSeconds?: number
  revocable?: boolean
  cancelledAt?: string
  cancelHash?: string
  cancelledPayouts?: number
  registryHash?: string
  registryContractId?: string
  payouts?: PayrollPayout[]
}

export type ScheduleStoreChange = { schedules: PayrollSchedule[]; added: string[]; removed: string[] }

const listeners = new Set<(change: ScheduleStoreChange) => void>()

export function onSchedulesChanged(listener: (change: ScheduleStoreChange) => void) {
  listeners.add(listener)
  return () => { listeners.delete(listener) }
}

/** Notify the dashboard to re-read Horizon after a funding transaction. */
export function prependSchedules(schedules: PayrollSchedule[], balanceIds: string[] = []) {
  listeners.forEach((listener) => listener({ schedules, added: balanceIds, removed: [] }))
}

export function scheduleInitial(schedule: PayrollSchedule) {
  const name = schedule.name.trim()
  return name ? name[0].toUpperCase() : '?'
}

export function paydayAt(schedule: PayrollSchedule, index: number): Date | null {
  if (!schedule.firstUnlock || schedule.intervalSeconds == null) return null
  return new Date(new Date(schedule.firstUnlock).getTime() + index * schedule.intervalSeconds * 1000)
}

/** Payouts the employer can still take back: on-chain, revocable, payday in the future. */
export function cancellableBalanceIds(schedule: PayrollSchedule, active: Set<string>, now: Date) {
  if (!schedule.revocable) return []
  if (schedule.payouts) {
    return schedule.payouts.filter((payout) => payout.active && active.has(payout.balanceId)
      && Date.parse(payout.unlockAt) > now.getTime()).map((payout) => payout.balanceId)
  }
  if (schedule.balanceIds.length === 0 || !schedule.firstUnlock || schedule.intervalSeconds == null) return []
  return schedule.balanceIds.filter((id, index) => active.has(id) && (paydayAt(schedule, index)?.getTime() ?? 0) > now.getTime())
}

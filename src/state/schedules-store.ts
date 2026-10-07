// Payroll schedules remembered on this device, under the key both clients share.

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
}

export type ScheduleStoreChange = { schedules: PayrollSchedule[]; added: string[]; removed: string[] }

const KEY = 'sweldo-schedules-v1'
const listeners = new Set<(change: ScheduleStoreChange) => void>()

export function readSchedules(): PayrollSchedule[] {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) ?? '[]') as Array<Partial<PayrollSchedule>>
    if (!Array.isArray(raw)) return []
    return raw.map((item) => ({
      id: item.id ?? '',
      employee: item.employee ?? '',
      name: item.name ?? 'Team member',
      total: String(item.total ?? '0'),
      tranches: Number(item.tranches ?? 1),
      asset: item.asset ?? 'XLM',
      createdAt: item.createdAt ?? new Date(0).toISOString(),
      hash: item.hash ?? '',
      employer: item.employer,
      balanceIds: item.balanceIds ?? [],
      firstUnlock: item.firstUnlock,
      intervalSeconds: item.intervalSeconds,
      revocable: item.revocable ?? false,
      cancelledAt: item.cancelledAt,
      cancelHash: item.cancelHash,
      cancelledPayouts: item.cancelledPayouts,
      registryHash: item.registryHash,
      registryContractId: item.registryContractId,
    }))
  } catch {
    return []
  }
}

function write(schedules: PayrollSchedule[]) {
  try { localStorage.setItem(KEY, JSON.stringify(schedules)) } catch { /* storage may be full or blocked */ }
}

export function onSchedulesChanged(listener: (change: ScheduleStoreChange) => void) {
  listeners.add(listener)
  return () => { listeners.delete(listener) }
}

/** Newest schedules go first. */
export function prependSchedules(schedules: PayrollSchedule[], balanceIds: string[] = []) {
  const next = [...schedules, ...readSchedules()]
  write(next)
  listeners.forEach((listener) => listener({ schedules: next, added: balanceIds, removed: [] }))
}

export function updateSchedule(id: string, change: (saved: PayrollSchedule) => PayrollSchedule, removed: string[] = []) {
  const next = readSchedules().map((schedule) => (schedule.id === id ? change(schedule) : schedule))
  write(next)
  listeners.forEach((listener) => listener({ schedules: next, added: [], removed }))
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
  if (!schedule.revocable || schedule.balanceIds.length === 0 || !schedule.firstUnlock || schedule.intervalSeconds == null) return []
  return schedule.balanceIds.filter((id, index) => active.has(id) && (paydayAt(schedule, index)?.getTime() ?? 0) > now.getTime())
}

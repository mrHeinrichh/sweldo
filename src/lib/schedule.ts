// Pure scheduling helpers shared by the payroll form and its smart schedule
// builder. Mirrors the Flutter app's PayrollFormState + PayrollSampler.

export type Cadence = 'minute' | 'day' | 'week' | 'month'

export const CADENCES: Record<Cadence, { seconds: number; label: string; unit: string; hint: string; phrase: string }> = {
  minute: { seconds: 60, label: 'Every minute', unit: 'minute', hint: 'For live demos', phrase: 'every minute' },
  day: { seconds: 86_400, label: 'Daily', unit: 'day', hint: 'Every day', phrase: 'every day' },
  week: { seconds: 604_800, label: 'Weekly', unit: 'week', hint: 'Every week', phrase: 'every week' },
  month: { seconds: 2_592_000, label: 'Monthly', unit: 'month', hint: 'Every 30 days', phrase: 'every month' },
}

export const CADENCE_ORDER: Cadence[] = ['minute', 'day', 'week', 'month']
export const MAX_OPERATIONS = 100
export const MAX_PAYOUTS = 50

export function units(cadence: Cadence, count: number) {
  const unit = CADENCES[cadence].unit
  return `${count} ${unit}${count === 1 ? '' : 's'}`
}

/** Most payouts each employee can have while the team fits one transaction. */
export function capacity(employees: number) {
  return Math.max(1, Math.min(MAX_PAYOUTS, Math.floor(MAX_OPERATIONS / Math.max(1, employees))))
}

/** When the first payout unlocks if the payroll is locked at `now`. */
export function firstPayday(now: Date, cadence: Cadence, firstDelay: number, firstPaydayAt: Date | null) {
  if (firstPaydayAt) return firstPaydayAt.getTime() > now.getTime() ? firstPaydayAt : now
  return new Date(now.getTime() + firstDelay * CADENCES[cadence].seconds * 1000)
}

export function paydays(first: Date, cadence: Cadence, count: number) {
  const step = CADENCES[cadence].seconds * 1000
  return Array.from({ length: Math.max(0, count) }, (_, index) => new Date(first.getTime() + index * step))
}

/** How many paydays fit between the first payday and the end of `until`. */
export function payoutsUntil(first: Date, until: Date, cadence: Cadence) {
  const end = new Date(until.getFullYear(), until.getMonth(), until.getDate(), 23, 59)
  return Math.floor((end.getTime() - first.getTime()) / (CADENCES[cadence].seconds * 1000)) + 1
}

export const SAMPLE_NAMES = [
  'Ana Santos', 'Marco Reyes', 'Bea Dela Cruz', 'Paolo Garcia', 'Liza Mendoza', 'Jun Bautista',
  'Carla Villanueva', 'Rico Ramos', 'Joy Aquino', 'Miguel Torres', 'Grace Flores', 'Nico Castillo',
]

export type ScheduleSample = {
  names: string[]
  totals: string[]
  cadence: Cadence
  payouts: number
  firstDelay: number
}

/**
 * Realistic random values for the payroll form: names, pay, cadence, payout
 * count and first payday. Totals split evenly (20–250 per payout, steps of
 * 10) and stay within what a Friendbot-funded Testnet wallet can lock.
 */
export function rollSample(employees: number, random: () => number = Math.random): ScheduleSample {
  const pick = (n: number) => Math.floor(random() * n)
  const pool = [...SAMPLE_NAMES]
  for (let i = pool.length - 1; i > 0; i -= 1) {
    const j = pick(i + 1)
    ;[pool[i], pool[j]] = [pool[j], pool[i]]
  }
  const payouts = Math.min(capacity(employees), 2 + pick(7))
  return {
    names: Array.from({ length: employees }, (_, i) => pool[i % pool.length]),
    totals: Array.from({ length: employees }, () => String((20 + pick(24) * 10) * payouts)),
    cadence: CADENCE_ORDER[pick(CADENCE_ORDER.length)],
    payouts,
    firstDelay: pick(4),
  }
}

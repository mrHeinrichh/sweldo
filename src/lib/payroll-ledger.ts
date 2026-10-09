import { StrKey } from '@stellar/stellar-sdk'
import { amountString, amountUnits } from './claim-convert.ts'
import type { PayrollPayout, PayrollSchedule } from '../state/schedules-store.ts'

export const PAYROLL_HORIZON = 'https://horizon-testnet.stellar.org'
type Predicate = Record<string, unknown>
export type LedgerOperation = {
  id: string
  type: string
  source_account: string
  transaction_hash: string
  transaction_successful?: boolean
  created_at: string
  asset?: string
  amount?: string
  balance_id?: string
  claimant?: string
  claimants?: { destination: string; predicate: Predicate }[]
}
type LedgerEffect = { type: string; balance_id?: string }
type LiveBalance = { id: string; amount: string; asset: string; claimants: { destination: string; predicate: Predicate }[] }
export type PayrollLedgerState = { schedules: PayrollSchedule[]; checkedAt: string; warnings: string[] }
export type HorizonRead = <T>(path: string, allowMissing?: boolean) => Promise<T | null>

export function horizonReader(signal?: AbortSignal): HorizonRead {
  return async <T>(path: string, allowMissing = false) => {
    const url = new URL(path, PAYROLL_HORIZON)
    if (url.origin !== PAYROLL_HORIZON) throw new Error('Only Stellar Testnet Horizon reads are supported.')
    const timeout = AbortSignal.timeout(20_000)
    const response = await fetch(url, { signal: signal ? AbortSignal.any([signal, timeout]) : timeout })
    if (allowMissing && response.status === 404) return null
    if (!response.ok) throw new Error(`Horizon could not load payroll state (${response.status}). Try refreshing.`)
    return response.json() as Promise<T>
  }
}

/** Follow every page, including histories longer than Horizon's 100-record limit. */
export async function horizonRecords<T>(read: HorizonRead, path: string, allowMissing = false): Promise<T[]> {
  const records: T[] = []
  const visited = new Set<string>()
  let next: string | undefined = path
  while (next) {
    if (visited.has(next) || visited.size >= 1000) throw new Error('Horizon history is incomplete. Refresh before using this payroll state.')
    visited.add(next)
    const firstPage = visited.size === 1
    const page: { _embedded: { records: T[] }; _links?: { next?: { href: string } } } | null = await read(next, allowMissing && firstPage)
    if (!page) {
      if (allowMissing && firstPage) break
      throw new Error('Horizon history is incomplete. Refresh before using this payroll state.')
    }
    if (!Array.isArray(page._embedded?.records)) throw new Error('Horizon returned an invalid history page.')
    if (page._embedded.records.length === 0) break
    records.push(...page._embedded.records)
    next = page._links?.next?.href
  }
  return records
}

export function absoluteDeadline(predicate: Predicate): number | null {
  const value = predicate.abs_before_epoch ?? predicate.abs_before ?? predicate.before_absolute_time
  if (typeof value !== 'string' && typeof value !== 'number') return null
  const time = /^-?\d+$/.test(String(value)) ? Number(value) * 1000 : Date.parse(String(value))
  return Number.isFinite(time) && Number.isFinite(new Date(time).getTime()) ? time : null
}

/** Recognize the mutually exclusive worker-after/employer-before pattern Sweldo funds. */
export function payrollTerms(operation: LedgerOperation, employer: string) {
  if (operation.type !== 'create_claimable_balance' || operation.transaction_successful === false
    || operation.source_account !== employer || !operation.asset || !operation.amount
    || operation.claimants?.length !== 2) return null
  const owner = operation.claimants.find((item) => item.destination === employer)
  const worker = operation.claimants.find((item) => item.destination !== employer)
  if (!owner || !worker) return null
  // More complex predicates must not be mistaken for Sweldo's cancellation authorization.
  if (Object.keys(owner.predicate).some((key) => !['abs_before', 'abs_before_epoch', 'before_absolute_time'].includes(key))) return null
  if (Object.keys(worker.predicate).length !== 1 || !worker.predicate.not || typeof worker.predicate.not !== 'object') return null
  const after = worker.predicate.not as Predicate
  if (Object.keys(after).some((key) => !['abs_before', 'abs_before_epoch', 'before_absolute_time'].includes(key))) return null
  const deadline = absoluteDeadline(owner.predicate)
  if (deadline === null || deadline !== absoluteDeadline(after)) return null
  return { employee: worker.destination, unlockAt: new Date(deadline).toISOString(), asset: operation.asset, amount: operation.amount }
}

async function mapLimited<T, U>(items: T[], work: (item: T) => Promise<U>): Promise<U[]> {
  const result: U[] = new Array(items.length)
  let index = 0
  await Promise.all(Array.from({ length: Math.min(4, items.length) }, async () => {
    while (index < items.length) {
      const current = index++
      result[current] = await work(items[current])
    }
  }))
  return result
}

export async function reconstructPayroll(employer: string, options: { read?: HorizonRead; now?: Date } = {}): Promise<PayrollLedgerState> {
  if (!StrKey.isValidEd25519PublicKey(employer)) throw new Error('Enter a valid Stellar employer public key starting with G.')
  const read = options.read ?? horizonReader()
  const now = options.now ?? new Date()
  const operations = await horizonRecords<LedgerOperation>(read, `/accounts/${employer}/operations?limit=100&order=desc&include_failed=false`, true)
  const creates = operations.filter((operation) => payrollTerms(operation, employer) !== null)
  const warnings: string[] = []
  const payouts = await mapLimited(creates, async (operation) => {
    const terms = payrollTerms(operation, employer)!
    const effects = await horizonRecords<LedgerEffect>(read, `/operations/${operation.id}/effects?limit=100`)
    const balanceId = effects.find((effect) => effect.type === 'claimable_balance_created')?.balance_id
    if (!balanceId || !/^[a-f0-9]{72}$/i.test(balanceId)) throw new Error('Horizon is missing a payroll balance ID. Refresh to recover complete state.')
    const history = await horizonRecords<LedgerOperation>(read, `/claimable_balances/${balanceId}/operations?limit=100&order=desc&include_failed=false`)
    const claim = history.find((record) => record.type === 'claim_claimable_balance'
      && record.transaction_successful !== false && record.balance_id === balanceId)
    const payout: PayrollPayout = { balanceId, amount: terms.amount, unlockAt: terms.unlockAt, active: false, status: 'unknown' }
    if (claim && (claim.claimant ?? claim.source_account) === employer) payout.status = 'cancelled'
    else if (claim && (claim.claimant ?? claim.source_account) === terms.employee) payout.status = 'claimed'
    if (payout.status !== 'unknown' && claim) {
      payout.settlementHash = claim.transaction_hash
      payout.settledAt = claim.created_at
    } else {
      const live = await read<LiveBalance>(`/claimable_balances/${balanceId}`, true)
      const liveTerms = live ? payrollTerms({ ...operation, claimants: live.claimants }, employer) : null
      if (live && live.id === balanceId && live.asset === terms.asset && live.amount === terms.amount
        && liveTerms?.unlockAt === terms.unlockAt && liveTerms.employee === terms.employee) {
        payout.active = true
        payout.status = Date.parse(terms.unlockAt) > now.getTime() ? 'scheduled' : 'claimable'
      } else {
        warnings.push(`Status could not be verified for ${balanceId}. Refresh; a missing balance alone does not prove a claim.`)
      }
    }
    return { operation, terms, payout }
  })
  const groups = new Map<string, typeof payouts>()
  for (const item of payouts) {
    const key = `${item.operation.transaction_hash}:${item.terms.employee}:${item.terms.asset}`
    groups.set(key, [...(groups.get(key) ?? []), item])
  }
  const schedules = [...groups.entries()].map(([id, items]): PayrollSchedule => {
    items.sort((a, b) => Date.parse(a.payout.unlockAt) - Date.parse(b.payout.unlockAt) || a.operation.id.localeCompare(b.operation.id))
    const first = items[0]
    const gaps = items.slice(1).map((item, index) => (Date.parse(item.payout.unlockAt) - Date.parse(items[index].payout.unlockAt)) / 1000)
    const intervalSeconds = gaps.length && gaps.every((gap) => gap === gaps[0]) ? gaps[0] : undefined
    const cancelled = items.filter((item) => item.payout.status === 'cancelled')
    return {
      id, employer, employee: first.terms.employee, name: 'Team member',
      total: amountString(items.reduce((total, item) => total + amountUnits(item.payout.amount), 0n)),
      tranches: items.length, asset: first.terms.asset === 'native' ? 'XLM' : first.terms.asset.split(':')[0],
      createdAt: first.operation.created_at, hash: first.operation.transaction_hash,
      firstUnlock: first.payout.unlockAt, intervalSeconds, revocable: true,
      balanceIds: items.map((item) => item.payout.balanceId), payouts: items.map((item) => item.payout),
      cancelledPayouts: cancelled.length, cancelledAt: cancelled.at(-1)?.payout.settledAt,
      cancelHash: cancelled.at(-1)?.payout.settlementHash,
    }
  }).sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt) || a.id.localeCompare(b.id))
  return { schedules, checkedAt: (options.now ?? new Date()).toISOString(), warnings }
}

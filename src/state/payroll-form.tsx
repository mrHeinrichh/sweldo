import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react'
import { StrKey } from '@stellar/stellar-sdk'
import { createBatchSchedule, recordScheduleProof } from '../lib/stellar'
import { CADENCES, capacity, firstPayday, paydays, rollSample, type Cadence } from '../lib/schedule'
import type { NoticeData } from '../ui/Notice'
import { plural } from '../ui/format'
import { amountString, perPayout, tryUnits } from './amount'
import { assetLabel, explorer, hasRegistry, MAX_OPERATIONS, MAX_PAYOUTS_PER_EMPLOYEE, payrollAsset } from './config'
import { friendlyError } from './errors'
import { prependSchedules, type PayrollSchedule } from './schedules-store'
import type { WalletSession } from './wallet'

// Port of PayrollFormBloc: the "New payroll" form and its one-signature
// submission. Lives above the router so it survives tab switches.

export type PayrollRecipient = { id: string; name: string; employee: string; total: string }

export type PayrollProof = {
  hash: string
  total: string
  balanceCount: number
  employeeCount: number
  payouts: number
  firstUnlock: Date
  asset: string
  registryHash?: string
  registryContractId?: string
}

export type PayrollFormState = {
  recipients: PayrollRecipient[]
  payouts: number
  cadence: Cadence
  firstPaydayIn: number
  firstPaydayAt: Date | null
  submitting: boolean
  progress: string | null
  notice: NoticeData | null
  lastProof: PayrollProof | null
  /** Wizard step: 0 team, 1 schedule, 2 review and lock. */
  step: PayrollStep
  /** Times someone tried to leave the team step incomplete; above 0 shows field errors. */
  teamChecks: number
}

export type PayrollStep = 0 | 1 | 2
export const PAYROLL_STEPS = 3

/** What still blocks locking, checked without a wallet. */
export type PayrollProblems = { missingAddresses: number; invalidAmounts: number; overLimit: boolean }

export type ScheduleChange = { cadence?: Cadence; payouts?: number; firstPaydayIn?: number; firstPaydayAt?: Date | null }

type PayrollFormApi = {
  state: PayrollFormState
  capacity: number
  balanceCount: number
  overOperationLimit: boolean
  totalLockedUnits: bigint
  firstPayday: (now: Date) => Date
  paydays: (now: Date) => Date[]
  amountPerPayout: (total: string) => string
  addRecipient: () => void
  removeRecipient: (id: string) => void
  changeRecipient: (id: string, change: Partial<Omit<PayrollRecipient, 'id'>>) => void
  changeSchedule: (change: ScheduleChange) => void
  /** Every visit starts a fresh draft: new sample values, first step. */
  startDraft: () => void
  /** Moves without checks (the guide uses this). */
  goToStep: (step: PayrollStep) => void
  /** Moves forward only once every employee has a wallet address and pay. */
  requestStep: (step: PayrollStep) => boolean
  problems: PayrollProblems
  dismissNotice: () => void
  submit: (session: WalletSession) => void
}

const newId = () => crypto.randomUUID()
export const hasValidAddress = (recipient: PayrollRecipient) =>
  recipient.employee.length === 56 && StrKey.isValidEd25519PublicKey(recipient.employee)

/**
 * New sample values for every field except the wallet addresses people typed:
 * locking pay to invented keys would strand it after payday.
 */
function rolled(from: PayrollFormState): PayrollFormState {
  const sample = rollSample(from.recipients.length)
  return {
    ...from,
    recipients: from.recipients.map((row, index) => ({ ...row, name: sample.names[index], total: sample.totals[index] })),
    payouts: sample.payouts,
    cadence: sample.cadence,
    firstPaydayIn: sample.firstDelay,
    firstPaydayAt: null,
    notice: null,
  }
}

function initialState(): PayrollFormState {
  // Every visit starts from a fresh random sample.
  return rolled({
    recipients: [{ id: newId(), name: '', employee: '', total: '' }],
    payouts: 4,
    cadence: 'minute',
    firstPaydayIn: 1,
    firstPaydayAt: null,
    submitting: false,
    progress: null,
    notice: null,
    lastProof: null,
    step: 0,
    teamChecks: 0,
  })
}

const PayrollFormContext = createContext<PayrollFormApi | null>(null)

export function PayrollFormProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState(initialState)
  const stateRef = useRef(state)
  stateRef.current = state
  const update = useCallback((change: (previous: PayrollFormState) => PayrollFormState) => {
    setState((previous) => {
      const next = change(previous)
      stateRef.current = next
      return next
    })
  }, [])

  const amountPerPayout = useCallback((total: string) => perPayout(total, stateRef.current.payouts), [])

  const validate = useCallback((session: WalletSession): string | null => {
    const current = stateRef.current
    if (!session.onTestnet) return 'Switch Freighter to Testnet, then reconnect.'
    const rows = current.recipients
    if (rows.some((row) => !hasValidAddress(row))) {
      return 'Every employee needs a valid 56-character Stellar public key (starts with G).'
    }
    if (rows.some((row) => (tryUnits(row.total) ?? 0n) <= 0n) || current.payouts < 1 || current.payouts > MAX_PAYOUTS_PER_EMPLOYEE) {
      return 'Use positive payroll amounts and 1–50 payouts.'
    }
    if (rows.some((row) => (tryUnits(perPayout(row.total, current.payouts)) ?? 0n) <= 0n)) {
      return `An amount is too small to split into ${current.payouts} payouts.`
    }
    if (rows.length * current.payouts > MAX_OPERATIONS) {
      return 'This batch is too large for one Stellar transaction. Keep employees × payouts at 100 or less.'
    }
    return null
  }, [])

  const submit = useCallback(async (session: WalletSession) => {
    const current = stateRef.current
    if (current.submitting) return
    const problem = validate(session)
    if (problem) {
      update((previous) => ({ ...previous, notice: { tone: 'error', text: problem } }))
      return
    }
    const rows = current.recipients
    const { payouts, cadence } = current
    const firstUnlock = firstPayday(new Date(), cadence, current.firstPaydayIn, current.firstPaydayAt)
    const totalLocked = rows.reduce((sum, row) => sum + (tryUnits(row.total) ?? 0n), 0n)
    update((previous) => ({ ...previous, submitting: true, progress: 'Confirm in Freighter…', notice: null }))
    try {
      const result = await createBatchSchedule({
        employer: session.address,
        recipients: rows.map((row) => ({ employee: row.employee, amountPerPayout: perPayout(row.total, payouts) })),
        payouts,
        firstUnlock,
        intervalSeconds: CADENCES[cadence].seconds,
        asset: payrollAsset,
      })
      const createdAt = new Date().toISOString()
      const schedules: PayrollSchedule[] = rows.map((row, index) => ({
        id: newId(),
        employee: row.employee,
        name: row.name.trim() || 'Team member',
        total: amountString(tryUnits(row.total) ?? 0n),
        tranches: payouts,
        asset: assetLabel,
        createdAt,
        hash: result.hash,
        employer: session.address,
        balanceIds: result.balanceIds.slice(index * payouts, (index + 1) * payouts),
        firstUnlock: firstUnlock.toISOString(),
        intervalSeconds: CADENCES[cadence].seconds,
        revocable: true,
      }))

      // Record proof metadata for the first schedule in the Soroban registry.
      let registryProof: Awaited<ReturnType<typeof recordScheduleProof>> = null
      let registryWarning = ''
      const first = schedules[0]
      if (hasRegistry && first.balanceIds.length > 0) {
        update((previous) => ({ ...previous, progress: 'Recording proof in the registry…' }))
        try {
          registryProof = await recordScheduleProof({
            employer: session.address,
            employee: first.employee,
            total: first.total,
            asset: assetLabel,
            cadenceSeconds: CADENCES[cadence].seconds,
            claimableBalanceId: first.balanceIds[0],
            payoutTxHash: result.hash,
          })
          if (registryProof) schedules[0] = { ...first, registryHash: registryProof.hash, registryContractId: registryProof.contractId }
        } catch (error) {
          registryWarning = ` The Soroban registry proof was not recorded: ${friendlyError(error)}`
        }
      }

      prependSchedules(schedules, result.balanceIds)
      const people = `${rows.length} ${plural(rows.length, 'employee')}`
      update((previous) => ({
        ...previous,
        submitting: false,
        progress: null,
        lastProof: {
          hash: result.hash,
          total: amountString(totalLocked),
          balanceCount: rows.length * payouts,
          employeeCount: rows.length,
          payouts,
          firstUnlock,
          asset: assetLabel,
          registryHash: registryProof?.hash,
          registryContractId: registryProof?.contractId,
        },
        notice: {
          tone: 'success',
          text: `Payroll locked for ${people}${registryProof ? ' and recorded in the Soroban registry' : ''}. You can cancel future payouts until each payday.${registryWarning}`,
          link: explorer.transaction(result.hash),
          linkLabel: 'View payroll transaction',
        },
      }))
    } catch (error) {
      update((previous) => ({ ...previous, submitting: false, progress: null, notice: { tone: 'error', text: friendlyError(error) } }))
    }
  }, [update, validate])

  const api = useMemo<PayrollFormApi>(() => {
    const balanceCount = state.recipients.length * state.payouts
    return {
      state,
      capacity: capacity(state.recipients.length),
      balanceCount,
      overOperationLimit: balanceCount > MAX_OPERATIONS,
      totalLockedUnits: state.recipients.reduce((sum, row) => sum + (tryUnits(row.total) ?? 0n), 0n),
      firstPayday: (now) => firstPayday(now, state.cadence, state.firstPaydayIn, state.firstPaydayAt),
      paydays: (now) => paydays(firstPayday(now, state.cadence, state.firstPaydayIn, state.firstPaydayAt), state.cadence, state.payouts),
      amountPerPayout,
      addRecipient: () => update((previous) => ({ ...previous, recipients: [...previous.recipients, { id: newId(), name: '', employee: '', total: '' }] })),
      removeRecipient: (id) => update((previous) => (previous.recipients.length === 1 ? previous : { ...previous, recipients: previous.recipients.filter((row) => row.id !== id) })),
      changeRecipient: (id, change) => update((previous) => ({
        ...previous,
        recipients: previous.recipients.map((row) => (row.id === id
          ? { ...row, ...change, ...(change.employee !== undefined ? { employee: change.employee.trim() } : {}) }
          : row)),
      })),
      changeSchedule: (change) => update((previous) => ({
        ...previous,
        cadence: change.cadence ?? previous.cadence,
        payouts: change.payouts !== undefined ? Math.max(1, Math.min(999, change.payouts)) : previous.payouts,
        firstPaydayIn: change.firstPaydayIn !== undefined ? Math.max(0, Math.min(9999, change.firstPaydayIn)) : previous.firstPaydayIn,
        // Choosing "in N intervals" replaces a picked date unless a new date comes with it.
        firstPaydayAt: change.firstPaydayAt !== undefined ? change.firstPaydayAt : change.firstPaydayIn !== undefined ? null : previous.firstPaydayAt,
      })),
      startDraft: () => update((previous) => (previous.submitting
        ? previous
        : { ...rolled(previous), step: 0, lastProof: null, teamChecks: 0 })),
      goToStep: (step) => update((previous) => ({ ...previous, step })),
      requestStep: (step) => {
        const rows = stateRef.current.recipients
        const incomplete = rows.some((row) => !hasValidAddress(row)
          || (tryUnits(row.total) ?? 0n) <= 0n
          || (tryUnits(perPayout(row.total, stateRef.current.payouts)) ?? 0n) <= 0n)
        if (step > 0 && incomplete) {
          update((previous) => ({ ...previous, step: 0, teamChecks: previous.teamChecks + 1 }))
          return false
        }
        update((previous) => ({ ...previous, step }))
        return true
      },
      problems: {
        missingAddresses: state.recipients.filter((row) => !hasValidAddress(row)).length,
        invalidAmounts: state.recipients.filter((row) => (tryUnits(row.total) ?? 0n) <= 0n
          || (tryUnits(perPayout(row.total, state.payouts)) ?? 0n) <= 0n).length,
        overLimit: balanceCount > MAX_OPERATIONS,
      },
      dismissNotice: () => update((previous) => ({ ...previous, notice: null })),
      submit: (session) => { void submit(session) },
    }
  }, [state, amountPerPayout, update, submit])

  return <PayrollFormContext.Provider value={api}>{children}</PayrollFormContext.Provider>
}

export function usePayrollForm() {
  const value = useContext(PayrollFormContext)
  if (!value) throw new Error('usePayrollForm needs a PayrollFormProvider.')
  return value
}

import { CalendarClock, Check, LockKeyhole, UsersRound, type LucideIcon } from 'lucide-react'
import { CADENCES } from '../../lib/schedule'
import { tryUnits } from '../../state/amount'
import { MAX_PAYOUTS_PER_EMPLOYEE } from '../../state/config'
import { hasValidAddress, usePayrollForm } from '../../state/payroll-form'
import { plural } from '../../ui/format'
import { useWallet } from '../../state/wallet'
import { useUp } from '../../ui/hooks'

type Status = 'todo' | 'current' | 'done'

/** The wizard's steps: team, schedule, lock. Each updates live and opens its step when tapped. */
export function PayrollProgress({ onSelect }: { onSelect: (section: number) => void }) {
  const form = usePayrollForm()
  const { state } = form
  const rows = state.recipients
  const { session } = useWallet()
  // Your own wallet doesn't count as an employee's wallet.
  const valid = rows.filter((row) => hasValidAddress(row) && row.employee !== session?.address).length
  const amountsOk = rows.every((row) => (tryUnits(row.total) ?? 0n) > 0n)
  const teamDone = valid === rows.length && amountsOk
  const scheduleDone = state.payouts >= 1 && state.payouts <= MAX_PAYOUTS_PER_EMPLOYEE && !form.overOperationLimit
  const locked = state.lastProof !== null

  const steps: { icon: LucideIcon; title: string; detail: string; done: boolean }[] = [
    { icon: UsersRound, title: 'Team', detail: teamDone ? `${rows.length} ${plural(rows.length, 'employee')} ready` : `${valid} of ${rows.length} wallets added`, done: teamDone },
    { icon: CalendarClock, title: 'Schedule', detail: `${state.payouts} ${plural(state.payouts, 'payout')}, ${CADENCES[state.cadence].label.toLowerCase()}`, done: scheduleDone },
    { icon: LockKeyhole, title: 'Lock', detail: state.submitting ? 'Signing…' : locked ? 'Locked on Stellar' : 'One signature', done: locked && !state.submitting },
  ]
  // The step you're on is current; others show whether they're complete.
  const statuses: Status[] = steps.map((step, i) => {
    if (i === state.step && !step.done) return 'current'
    if (i === state.step && i < 2) return 'current'
    return step.done ? 'done' : 'todo'
  })
  const compact = !useUp('sm')

  return (
    <div className={`progress ${compact ? 'compact' : ''}`}>
      {steps.map((step, i) => {
        const Icon = statuses[i] === 'done' ? Check : step.icon
        return (
          <button
            key={step.title}
            type="button"
            className={`progress-step is-${statuses[i]}`}
            onClick={() => onSelect(i)}
            aria-label={`Step ${i + 1}, ${step.title}: ${step.detail}`}
            aria-current={i === state.step ? 'step' : undefined}
          >
            <span className="progress-circle"><Icon key={String(statuses[i] === 'done')} size={18} className="progress-icon" /></span>
            <span className="t-label progress-title">{step.title}</span>
            <span key={step.detail} className="t-caption progress-detail">{step.detail}</span>
            {/* The line to the next step runs circle to circle, with the same gap at each end. */}
            {i < steps.length - 1 && (
              <span className="progress-connector" aria-hidden><span style={{ transform: `scaleX(${statuses[i] === 'done' ? 1 : 0})` }} /></span>
            )}
          </button>
        )
      })}
    </div>
  )
}

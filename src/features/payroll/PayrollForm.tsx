import { useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { ArrowLeft, ArrowRight, KeyRound, LockKeyhole, Plus, RotateCcw, ShieldCheck, TriangleAlert, Undo2, Wallet } from 'lucide-react'
import { useAccount } from '../../state/account'
import { formatAmount, formatUnits } from '../../state/amount'
import { assetLabel } from '../../state/config'
import { hasValidAddress, usePayrollForm, type PayrollStep } from '../../state/payroll-form'
import { useWallet } from '../../state/wallet'
import { Button } from '../../ui/Button'
import { plural, shortKey } from '../../ui/format'
import { useReducedMotion, useUp, useWide } from '../../ui/hooks'
import { ensureVisible } from '../../ui/scroll'
import { Panel } from '../../ui/Layout'
import { AnimatedNotice } from '../../ui/Notice'
import { PaperHeader, PayrollPaper } from '../../ui/Paper'
import { AccountSetupPrompts } from '../account/AccountSetupPrompts'
import { PayrollProgress } from './PayrollProgress'
import { PayrollProofCard } from './PayrollProofCard'
import { InsightChip, PayScheduleBuilder, ScheduleInsights } from './PayScheduleBuilder'
import { RecipientRow } from './RecipientRow'

const STEPS: { title: string; description: string; next?: string }[] = [
  { title: 'Who are you paying?', description: 'Add each person with their Stellar wallet and the total to pay them.', next: 'Continue to schedule' },
  { title: 'When do they get paid?', description: 'Choose how often pay unlocks, how many times, and when it starts.', next: 'Continue to review' },
  { title: 'Review and lock', description: 'Check the plan, then sign once in Freighter to lock every payout.' },
]

/**
 * "New payroll" as three short steps: who gets paid, when, then one
 * signature. Each step fits on a screen, so nobody scrolls a long form.
 */
export function PayrollForm() {
  const form = usePayrollForm()
  const account = useAccount()
  const { state } = form
  const step = state.step
  const reduced = useReducedMotion()
  const top = useRef<HTMLDivElement>(null)
  const previousStep = useRef(step)
  const direction = step >= previousStep.current ? 'forward' : 'back'
  useEffect(() => { previousStep.current = step }, [step])

  // Rows present on first render don't animate in; rows added later do.
  const [initialIds] = useState(() => new Set(state.recipients.map((row) => row.id)))

  // A new proof means balances changed.
  const lastHash = state.lastProof?.hash
  useEffect(() => { if (lastHash) account.refresh() }, [lastHash]) // eslint-disable-line react-hooks/exhaustive-deps

  const go = (next: PayrollStep) => {
    form.goToStep(next)
    // Bring the start of the form back into view if it scrolled away.
    const node = top.current
    if (node && node.getBoundingClientRect().top < 80) ensureVisible(node, 0.08, !reduced)
  }

  const locked = step === 2 && state.lastProof !== null
  const heading = locked
    ? { title: 'Payroll locked', description: 'Every payout is on the Stellar ledger. You can cancel future payouts until each payday.' }
    : STEPS[step]

  return (
    <Panel className="payroll-form">
      <div ref={top} className="wizard-progress"><PayrollProgress onSelect={(index) => go(index as PayrollStep)} /></div>
      <AccountSetupPrompts trustlineMessage={`Add a ${assetLabel} trustline so this wallet can hold and lock ${assetLabel} for payroll.`} />
      <AnimatedNotice data={state.notice} />

      <section key={locked ? 'locked' : step} className={`wizard-step ${direction}`} aria-labelledby="wizard-title">
        <h2 id="wizard-title" className="wizard-title m0">{heading.title}</h2>
        <p className="t-body-sm m0 wizard-description">{heading.description}</p>
        <div className="wizard-body">
          {step === 0 && <TeamStep initialIds={initialIds} />}
          {step === 1 && <PayScheduleBuilder />}
          {step === 2 && (locked ? <LockedStep onNew={() => { form.startDraft(); go(0) }} /> : <ReviewStep onFix={go} />)}
        </div>
      </section>

      {!locked && (
        <WizardActions>
          {step > 0
            ? <Button label="Back" icon={<ArrowLeft />} tone="secondary" disabled={state.submitting} onClick={() => go((step - 1) as PayrollStep)} />
            : <span />}
          {step < 2
            ? <Button label={STEPS[step].next!} icon={<ArrowRight />} onClick={() => go((step + 1) as PayrollStep)} className="wizard-primary" />
            : <LockButton />}
        </WizardActions>
      )}
      {step === 2 && !locked && (
        <p className="lock-note t-caption">
          <ShieldCheck size={14} />
          <span>Funds move from your wallet into claimable balances on the Stellar ledger. Sweldo never holds them.</span>
        </p>
      )}
    </Panel>
  )
}

/**
 * Back and Continue: at the foot of the panel on wide screens, pinned above
 * the bottom navigation on phones so the next action never needs a scroll.
 */
function WizardActions({ children }: { children: ReactNode }) {
  const wide = useWide()
  const [slot, setSlot] = useState<HTMLElement | null>(null)
  useEffect(() => { setSlot(document.getElementById('page-bar')) }, [])
  if (wide) return <div className="wizard-footer">{children}</div>
  if (!slot) return null
  return createPortal(<div className="wizard-bar"><div className="wizard-bar-row">{children}</div></div>, slot)
}

function TeamStep({ initialIds }: { initialIds: Set<string> }) {
  const form = usePayrollForm()
  const { state } = form
  const sm = useUp('sm')
  const count = state.recipients.length
  return (
    <>
      <div className="team-actions">
        <span className="t-caption">{count} {plural(count, 'employee')}</span>
        <span className="team-actions-buttons">
          <Button label={sm ? 'Add employee' : 'Add'} icon={<Plus />} tone="quiet" disabled={state.submitting} onClick={form.addRecipient} />
        </span>
      </div>
      <div className="recipients" data-tour="employees">
        {state.recipients.map((row, index) => (
          <RecipientRow
            key={row.id}
            recipient={row}
            index={index}
            assetLabel={assetLabel}
            removable={count > 1}
            animateIn={!initialIds.has(row.id)}
            disabled={state.submitting}
          />
        ))}
      </div>
    </>
  )
}

/** The plan as a printed pay summary, then the checks, then the policy. */
function ReviewStep({ onFix }: { onFix: (step: PayrollStep) => void }) {
  const form = usePayrollForm()
  const { state, problems } = form
  const people = state.recipients.length
  return (
    <>
      <PayrollPaper
        header={(
          <PaperHeader
            title={`${people} ${plural(people, 'employee')} × ${state.payouts} ${plural(state.payouts, 'payout')}`}
            trailing={<span key={String(form.totalLockedUnits)} className="t-amount review-total">{formatUnits(form.totalLockedUnits)} {assetLabel}</span>}
          />
        )}
      >
        {state.recipients.map((row, index) => (
          <div key={row.id} className="review-row">
            <div className="review-person">
              <span className="t-subtitle">{row.name.trim() || `Employee ${index + 1}`}</span>
              {hasValidAddress(row)
                ? <span className="t-mono">{shortKey(row.employee, 6)}</span>
                : <span className="review-missing t-caption"><KeyRound size={13} />Wallet address missing</span>}
            </div>
            <div className="review-pay">
              <span className="t-figures">{formatAmount(row.total || '0')} {assetLabel}</span>
              <span className="t-caption">{state.payouts} × {formatAmount(form.amountPerPayout(row.total))} {assetLabel}</span>
            </div>
          </div>
        ))}
      </PayrollPaper>
      <div className="review-checks">
        <ScheduleInsights>
          {problems.missingAddresses > 0 && (
            <InsightChip
              icon={TriangleAlert}
              tone="danger"
              text={`${problems.missingAddresses} ${plural(problems.missingAddresses, 'employee needs', 'employees need')} a wallet address`}
              actionLabel="Add addresses"
              onAction={() => onFix(0)}
            />
          )}
          {problems.invalidAmounts > 0 && (
            <InsightChip
              icon={TriangleAlert}
              tone="danger"
              text={`${problems.invalidAmounts} ${plural(problems.invalidAmounts, 'amount')} can’t be split into ${state.payouts} payouts`}
              actionLabel="Fix amounts"
              onAction={() => onFix(0)}
            />
          )}
        </ScheduleInsights>
      </div>
      <div className="cancel-policy">
        <Undo2 size={18} />
        <p className="t-body-sm t-ink m0">You can cancel a payout until its payday. From payday on, only the employee can claim it.</p>
      </div>
    </>
  )
}

function LockButton() {
  const form = usePayrollForm()
  const wallet = useWallet()
  const { state, problems } = form
  const session = wallet.session
  const sm = useUp('sm')
  const blocked = problems.missingAddresses > 0 || problems.invalidAmounts > 0 || problems.overLimit
  return (
    <span data-tour="lock" className="wizard-lock wizard-primary">
      <Button
        expand
        label={!session ? (sm ? 'Connect wallet to lock payroll' : 'Connect to lock') : state.progress ?? 'Lock payroll on Stellar'}
        icon={!session ? <Wallet /> : <LockKeyhole />}
        loading={state.submitting}
        disabled={!!session && blocked}
        onClick={() => (!session ? wallet.openSheet() : form.submit(session))}
      />
    </span>
  )
}

function LockedStep({ onNew }: { onNew: () => void }) {
  const { state } = usePayrollForm()
  if (!state.lastProof) return null
  return (
    <>
      <PayrollProofCard key={state.lastProof.hash} proof={state.lastProof} />
      <div className="locked-actions">
        <Button label="Start a new payroll" icon={<RotateCcw />} tone="secondary" onClick={onNew} />
      </div>
    </>
  )
}

import { useEffect, useRef, useState } from 'react'
import { Dices, Layers, LockKeyhole, Plus, ShieldCheck, Undo2, UsersRound, Wallet } from 'lucide-react'
import { useAccount } from '../../state/account'
import { formatUnits } from '../../state/amount'
import { assetLabel } from '../../state/config'
import { usePayrollForm } from '../../state/payroll-form'
import { useWallet } from '../../state/wallet'
import { Button } from '../../ui/Button'
import { plural } from '../../ui/format'
import { useReducedMotion, useUp } from '../../ui/hooks'
import { ensureVisible } from '../../ui/scroll'
import { Panel, SectionHeading } from '../../ui/Layout'
import { AnimatedNotice, Collapse } from '../../ui/Notice'
import { AccountSetupPrompts } from '../account/AccountSetupPrompts'
import { PayrollProgress } from './PayrollProgress'
import { PayrollProofCard } from './PayrollProofCard'
import { PayScheduleBuilder } from './PayScheduleBuilder'
import { RecipientRow } from './RecipientRow'

/** "New payroll": who gets paid, how much, how often — then one signature. */
export function PayrollForm() {
  const form = usePayrollForm()
  const wallet = useWallet()
  const account = useAccount()
  const { state } = form
  const session = wallet.session
  const sm = useUp('sm')
  const reduced = useReducedMotion()
  const sections = [useRef<HTMLDivElement>(null), useRef<HTMLDivElement>(null), useRef<HTMLDivElement>(null)]
  // Rows present on first render don't animate in; rows added later do.
  const [initialIds] = useState(() => new Set(state.recipients.map((row) => row.id)))

  // A new proof means balances changed.
  const lastHash = state.lastProof?.hash
  useEffect(() => { if (lastHash) account.refresh() }, [lastHash]) // eslint-disable-line react-hooks/exhaustive-deps

  const jumpTo = (section: number) => {
    const target = sections[section].current
    if (target) ensureVisible(target, 0.08, !reduced)
  }

  return (
    <Panel className="payroll-form">
      <SectionHeading title="New payroll" description="One transaction creates every time-locked payout for every employee below." />
      <div className="payroll-progress-wrap"><PayrollProgress onSelect={jumpTo} /></div>
      <AccountSetupPrompts trustlineMessage={`Add a ${assetLabel} trustline so this wallet can hold and lock ${assetLabel} for payroll.`} />
      <AnimatedNotice data={state.notice} />
      <Collapse open={state.lastProof !== null}>
        {state.lastProof && <div className="proof-wrap"><PayrollProofCard key={state.lastProof.hash} proof={state.lastProof} /></div>}
      </Collapse>

      <div className="employees-head" ref={sections[0]} data-tour="employees">
        <UsersRound size={18} />
        <span className="t-subtitle employees-title">Employees</span>
        <span data-tour="shuffle"><ShuffleButton shuffles={state.shuffles} disabled={state.submitting} onClick={form.randomize} /></span>
        <Button label={sm ? 'Add employee' : 'Add'} icon={<Plus />} tone="quiet" disabled={state.submitting} onClick={form.addRecipient} />
      </div>
      <div className="recipients">
        {state.recipients.map((row, index) => (
          <RecipientRow
            key={row.id}
            recipient={row}
            index={index}
            assetLabel={assetLabel}
            removable={state.recipients.length > 1}
            animateIn={!initialIds.has(row.id)}
            shuffles={state.shuffles}
            disabled={state.submitting}
          />
        ))}
      </div>
      <div ref={sections[1]} style={{ height: 'var(--s-lg)' }} />
      <PayScheduleBuilder />
      <div ref={sections[2]} className="batch-summary">
        <div className="batch-summary-count">
          <Layers size={16} />
          <span className="t-body-sm t-ink">{state.recipients.length} {plural(state.recipients.length, 'employee')} × {state.payouts} {plural(state.payouts, 'payout')}</span>
        </div>
        <div className="batch-summary-total">
          <span className="t-caption">Total locked</span>
          <span key={String(form.totalLockedUnits)} className="t-amount batch-total">{formatUnits(form.totalLockedUnits)} {assetLabel}</span>
        </div>
      </div>
      <div className="cancel-policy">
        <Undo2 size={18} />
        <p className="t-body-sm t-ink m0">You can cancel a payout until its payday. From payday on, only the employee can claim it.</p>
      </div>
      <div data-tour="lock" className="lock-wrap">
        <Button
          label={!session ? 'Connect wallet to lock payroll' : state.progress ?? 'Lock payroll on Stellar'}
          icon={!session ? <Wallet /> : <LockKeyhole />}
          large
          expand
          loading={state.submitting}
          onClick={() => (!session ? wallet.openSheet() : form.submit(session))}
        />
      </div>
      <p className="lock-note t-caption">
        <ShieldCheck size={14} />
        <span>Funds move from your wallet into claimable balances on the Stellar ledger. Sweldo never holds them.</span>
      </p>
    </Panel>
  )
}

/** Rolls new sample values. The dice turns once per roll. */
function ShuffleButton({ shuffles, disabled, onClick }: { shuffles: number; disabled: boolean; onClick: () => void }) {
  return (
    <button type="button" className="shuffle-button" disabled={disabled} onClick={onClick} title="Fill the form with new sample values">
      <Dices size={18} className="shuffle-dice" style={{ transform: `rotate(${shuffles * 360}deg)` }} />
      <span>Shuffle</span>
    </button>
  )
}

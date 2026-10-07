import { useState } from 'react'
import { ArrowUpRight, Check, ChevronDown, ReceiptText, RefreshCw, Undo2 } from 'lucide-react'
import { formatAmount, perPayout } from '../../state/amount'
import { explorer } from '../../state/config'
import { useSchedules } from '../../state/schedules'
import { scheduleInitial, type PayrollSchedule } from '../../state/schedules-store'
import { useWallet } from '../../state/wallet'
import { Button, IconButton } from '../../ui/Button'
import { AlertDialog } from '../../ui/Dialog'
import { ExternalLink } from '../../ui/ExternalLink'
import { formatDateTime, plural } from '../../ui/format'
import { useNow } from '../../ui/hooks'
import { KeyText } from '../../ui/KeyText'
import { Panel } from '../../ui/Layout'
import { AnimatedNotice, Collapse } from '../../ui/Notice'

/** Recent payrolls on this device, with future-payout cancellation. Collapses to its header. */
export function ScheduleList() {
  const schedules = useSchedules()
  const [expanded, setExpanded] = useState(true)
  const count = schedules.schedules.length

  return (
    <Panel className="schedule-list">
      <div className="schedule-list-head">
        <button type="button" className="schedule-list-toggle" onClick={() => setExpanded((value) => !value)} aria-expanded={expanded} aria-label={expanded ? 'Collapse recent payrolls' : 'Expand recent payrolls'}>
          <span className="schedule-list-icon"><ReceiptText size={18} /></span>
          <span className="schedule-list-titles">
            <span className="schedule-list-title-row">
              <span className="t-title">Recent payrolls</span>
              <span key={count} className="schedule-count">{count}</span>
            </span>
            <span className="t-body-sm">Saved on this device, each linked to its proof.</span>
          </span>
          <ChevronDown size={20} className={`schedule-list-chevron ${expanded ? 'open' : ''}`} />
        </button>
        {schedules.address && (
          <IconButton icon={<RefreshCw />} label="Check the ledger again" loading={!schedules.balancesLoaded} onClick={schedules.refresh} />
        )}
      </div>
      <AnimatedNotice data={schedules.notice} gap="top" />
      <Collapse open={expanded}>
        <div className="schedule-tiles">
          {schedules.schedules.map((schedule, index) => (
            <div key={schedule.id}>
              {index > 0 && <hr className="schedule-divider" />}
              <ScheduleTile schedule={schedule} />
            </div>
          ))}
        </div>
      </Collapse>
    </Panel>
  )
}

function ScheduleTile({ schedule }: { schedule: PayrollSchedule }) {
  const each = perPayout(schedule.total, schedule.tranches)
  const createdAt = new Date(schedule.createdAt)
  const [fresh] = useState(() => Date.now() - createdAt.getTime() < 4000)
  return (
    <div className={`schedule-tile ${fresh ? 'fresh' : ''}`}>
      <div className="schedule-tile-row">
        <span className="schedule-avatar t-label">{scheduleInitial(schedule)}</span>
        <div className="schedule-tile-text">
          <span className="t-subtitle">{schedule.name}</span>
          <KeyText value={schedule.employee} edge={5} />
          <span className="t-body-sm">{schedule.tranches} {plural(schedule.tranches, 'payout')} of {formatAmount(each)} {schedule.asset}</span>
          <span className="t-caption">Locked {formatDateTime(createdAt)}</span>
        </div>
        <a className="schedule-open" href={explorer.transaction(schedule.hash)} target="_blank" rel="noreferrer" title="View payroll transaction" aria-label="View payroll transaction">
          <ArrowUpRight size={18} />
        </a>
      </div>
      <ScheduleControl schedule={schedule} />
    </div>
  )
}

/** The cancellation status line, re-evaluated every second. */
function ScheduleControl({ schedule }: { schedule: PayrollSchedule }) {
  const schedules = useSchedules()
  const { session } = useWallet()
  const now = useNow()
  const [confirming, setConfirming] = useState<number | null>(null)
  const remaining = schedules.cancellableFor(schedule, now)
  const cancelled = !!schedule.cancelledAt

  let content
  let contentKey: string
  if (!schedule.revocable) {
    contentKey = 'original'
    content = <Status text="Original schedule. Cancellation was not enabled." />
  } else if (cancelled) {
    const n = schedule.cancelledPayouts ?? 0
    contentKey = 'cancelled'
    content = (
      <div className="schedule-control-wrap">
        <Status text={`${n} future ${plural(n, 'payout')} returned to you`} icon={<Check size={14} />} color="var(--payday)" />
        {schedule.cancelHash && <ExternalLink href={explorer.transaction(schedule.cancelHash)} label="Cancellation proof" small />}
      </div>
    )
  } else if (!session) {
    contentKey = 'connect'
    content = <Status text="Connect the employer wallet to manage this payroll." />
  } else if (schedule.employer !== session.address) {
    contentKey = 'other'
    content = <Status text="Connect the wallet that funded this payroll to manage it." />
  } else if (!schedules.balancesLoaded) {
    contentKey = 'checking'
    content = <Status text="Checking future payouts on the ledger…" />
  } else if (remaining.length > 0) {
    contentKey = `remaining${remaining.length}`
    content = (
      <div className="schedule-control-wrap">
        <Status text={`${remaining.length} future ${plural(remaining.length, 'payout')} can still be cancelled`} />
        <Button
          label="Cancel remaining payroll"
          icon={<Undo2 />}
          tone="danger"
          loading={schedules.cancellingId === schedule.id}
          disabled={schedules.cancellingId !== null}
          onClick={() => setConfirming(remaining.length)}
        />
      </div>
    )
  } else {
    contentKey = 'done'
    content = <Status text="Every payday has arrived. Nothing left to cancel." />
  }

  return (
    <div className={`schedule-control ${cancelled ? 'cancelled' : ''}`}>
      <div key={contentKey} className="schedule-control-content">{content}</div>
      {schedule.registryContractId && (
        <ExternalLink href={explorer.contract(schedule.registryContractId)} label="Recorded in the Soroban payroll registry" small className="schedule-registry" />
      )}
      {confirming !== null && session && (
        <AlertDialog
          title={`Cancel future payouts for ${schedule.name}?`}
          body={`Sweldo re-checks all ${confirming} eligible ${plural(confirming, 'payout')} on Stellar, then returns ${confirming === 1 ? 'it' : 'them'} to your wallet. Payouts at or past payday stay with the employee.`}
          onClose={() => setConfirming(null)}
          actions={(
            <>
              <button type="button" className="text-button" onClick={() => setConfirming(null)}>Keep payroll</button>
              <button type="button" className="filled-button danger" onClick={() => { setConfirming(null); schedules.cancel(schedule, session) }}>
                Cancel {confirming} {plural(confirming, 'payout')}
              </button>
            </>
          )}
        />
      )}
    </div>
  )
}

function Status({ text, icon, color }: { text: string; icon?: React.ReactNode; color?: string }) {
  return (
    <span className="schedule-status t-caption" style={color ? { color } : undefined}>
      {icon}
      <span>{text}</span>
    </span>
  )
}

import { useEffect, useState } from 'react'
import { ArrowUpRight, Check, ChevronDown, ReceiptText, RefreshCw, Search, Undo2 } from 'lucide-react'
import { formatAmount } from '../../state/amount'
import { explorer } from '../../state/config'
import { useSchedules } from '../../state/schedules'
import { scheduleInitial, type PayrollPayout, type PayrollSchedule } from '../../state/schedules-store'
import { useWallet } from '../../state/wallet'
import { Button, IconButton } from '../../ui/Button'
import { AlertDialog } from '../../ui/Dialog'
import { ExternalLink } from '../../ui/ExternalLink'
import { formatDateTime, plural } from '../../ui/format'
import { useNow } from '../../ui/hooks'
import { KeyText } from '../../ui/KeyText'
import { Panel } from '../../ui/Layout'
import { AnimatedNotice, Collapse } from '../../ui/Notice'

/** Payroll obligations reconstructed from public Stellar Testnet history. */
export function ScheduleList() {
  const schedules = useSchedules()
  const [expanded, setExpanded] = useState(true)
  const [address, setAddress] = useState(schedules.address ?? '')
  useEffect(() => { setAddress(schedules.address ?? '') }, [schedules.address])
  const count = schedules.schedules.length

  return (
    <Panel className="schedule-list">
      <div className="schedule-list-head">
        <button type="button" className="schedule-list-toggle" onClick={() => setExpanded((value) => !value)} aria-expanded={expanded} aria-label={expanded ? 'Collapse recent payrolls' : 'Expand recent payrolls'}>
          <span className="schedule-list-icon"><ReceiptText size={18} /></span>
          <span className="schedule-list-titles">
            <span className="schedule-list-title-row">
              <span className="t-title">Payroll history</span>
              <span key={count} className="schedule-count">{count}</span>
            </span>
            <span className="t-body-sm">Stellar Testnet</span>
          </span>
          <ChevronDown size={20} className={`schedule-list-chevron ${expanded ? 'open' : ''}`} />
        </button>
        {schedules.address && (
          <IconButton icon={<RefreshCw />} label="Check the ledger again" loading={schedules.loading} onClick={schedules.refresh} />
        )}
      </div>
      <form className="ledger-address" onSubmit={(event) => { event.preventDefault(); schedules.inspect(address) }}>
        <label className="field">
          <span className="t-label">Employer public key</span>
          <span className="input-box"><span className="input-icon"><Search size={16} /></span><input aria-label="Employer public key" className="mono-input" value={address} onChange={(event) => setAddress(event.target.value)} placeholder="G..." spellCheck={false} /></span>
        </label>
        <Button label="Load payroll" icon={<Search />} tone="secondary" loading={schedules.loading} disabled={!address.trim() || schedules.cancellingId !== null} onClick={() => schedules.inspect(address)} />
      </form>
      {schedules.checkedAt && <p className="t-caption ledger-checked">Checked {formatDateTime(new Date(schedules.checkedAt))}</p>}
      <AnimatedNotice data={schedules.notice} gap="top" />
      <Collapse open={expanded}>
        <div className="schedule-tiles">
          {!count && <p role="status" className="t-body-sm">{schedules.loading ? 'Reading payroll history...' : schedules.balancesLoaded ? 'No supported payroll schedules found for this employer.' : 'Enter an employer public key to view payroll.'}</p>}
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
  const createdAt = new Date(schedule.createdAt)
  const [fresh] = useState(() => Date.now() - createdAt.getTime() < 4000)
  return (
    <div className={`schedule-tile ${fresh ? 'fresh' : ''}`}>
      <div className="schedule-tile-row">
        <span className="schedule-avatar t-label">{scheduleInitial(schedule)}</span>
        <div className="schedule-tile-text">
          <span className="t-subtitle">{schedule.name}</span>
          <KeyText value={schedule.employee} edge={5} />
          <span className="t-body-sm">{schedule.tranches} {plural(schedule.tranches, 'payout')} / Total {formatAmount(schedule.total)} {schedule.asset}</span>
          <span className="t-caption">Locked {formatDateTime(createdAt)}</span>
        </div>
        <a className="schedule-open" href={explorer.transaction(schedule.hash)} target="_blank" rel="noreferrer" title="View payroll transaction" aria-label="View payroll transaction">
          <ArrowUpRight size={18} />
        </a>
      </div>
      <PayoutStatusList schedule={schedule} />
      <ScheduleControl schedule={schedule} />
    </div>
  )
}

function payoutLabel(payout: PayrollPayout, now: Date) {
  if (payout.active) return Date.parse(payout.unlockAt) > now.getTime() ? 'Scheduled' : 'Claimable'
  return { claimed: 'Claimed', cancelled: 'Cancelled', unknown: 'Unverified', scheduled: 'Scheduled', claimable: 'Claimable' }[payout.status]
}

function PayoutStatusList({ schedule }: { schedule: PayrollSchedule }) {
  const now = useNow()
  const schedules = useSchedules()
  if (!schedule.payouts) return null
  const claimed = schedule.payouts.filter((payout) => payout.status === 'claimed').length
  const cancelled = schedule.payouts.filter((payout) => payout.status === 'cancelled').length
  return (
    <div className="ledger-payouts">
      <span className="t-caption">{claimed} claimed / {cancelled} cancelled / {schedule.payouts.filter((payout) => payout.active).length} open</span>
      {schedules.balancesLoaded && <span className="t-caption">{schedules.cancellableFor(schedule, now).length} future payouts eligible for employer cancellation</span>}
      <ol className="ledger-payout-list">
        {schedule.payouts.map((payout) => (
          <li className="ledger-payout" key={payout.balanceId}>
            <div className="ledger-payout-top"><span className="t-label">{formatAmount(payout.amount)} {schedule.asset}</span><span className={`t-caption ledger-status ${payout.status}`}>{payoutLabel(payout, now)}</span></div>
            <span className="t-caption">Payday {formatDateTime(new Date(payout.unlockAt))}</span>
            <div className="ledger-payout-proof">
              <KeyText value={payout.balanceId} edge={6} />
              <ExternalLink href={explorer.claimableBalance(payout.balanceId)} label="Balance" small />
              {payout.settlementHash && <ExternalLink href={explorer.transaction(payout.settlementHash)} label={payout.status === 'cancelled' ? 'Cancellation' : 'Claim'} small />}
            </div>
          </li>
        ))}
      </ol>
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
  } else if (!schedules.balancesLoaded) {
    contentKey = 'checking'
    content = <Status text={schedules.loading ? 'Checking payouts on Stellar...' : 'Refresh to verify cancellation eligibility.'} />
  } else if (!session) {
    contentKey = 'connect'
    content = <Status text="Connect the employer wallet to manage this payroll." />
  } else if (schedule.employer !== session.address) {
    contentKey = 'other'
    content = <Status text="Connect the wallet that funded this payroll to manage it." />
  } else if (!session.onTestnet) {
    contentKey = 'network'
    content = <Status text="Switch the employer wallet to Testnet and reconnect." />
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
    content = (
      <div className="schedule-control-wrap">
        <Status text={cancelled ? `${schedule.cancelledPayouts} future payouts returned to you. Nothing left to cancel.` : 'No verified future payouts are eligible for cancellation.'} icon={cancelled ? <Check size={14} /> : undefined} />
        {schedule.cancelHash && <ExternalLink href={explorer.transaction(schedule.cancelHash)} label="Cancellation proof" small />}
      </div>
    )
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

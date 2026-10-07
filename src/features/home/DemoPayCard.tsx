import { useMemo, useState } from 'react'
import { LockKeyhole } from 'lucide-react'
import { countdownLabel, formatShortDate } from '../../ui/format'
import { useNow, useReducedMotion } from '../../ui/hooks'
import { Tilt3D } from '../../ui/Motion'
import { ClaimedStamp, PaperHeader, PayrollPaper, PunchSlot, type PunchState } from '../../ui/Paper'

type Status = 'claimed' | 'ready' | 'locked'
const MINUTE = 60_000
const DAY = 86_400_000

/**
 * A worker's pay schedule, printed onto payroll paper. A working model of
 * the real flow: one payout is ready, and claiming it stamps the row.
 */
export function DemoPayCard({ assetLabel }: { assetLabel: string }) {
  const [claimed, setClaimed] = useState(false)
  const reduced = useReducedMotion()
  // One claimed, one ready, one about to unlock while you watch, one later.
  const rows = useMemo(() => {
    const anchor = Date.now()
    return [
      { payday: new Date(anchor - 15 * DAY), status: 'claimed' as Status },
      { payday: new Date(anchor - 3 * MINUTE), status: 'ready' as Status },
      { payday: new Date(anchor + 2 * MINUTE + 48_000), status: 'locked' as Status },
      { payday: new Date(anchor + 15 * DAY), status: 'locked' as Status },
    ]
  }, [])

  return (
    <div className="demo-card">
      <Tilt3D maxTilt={7}>
        <PayrollPaper
          elevated
          header={<PaperHeader title="Ana Santos's pay" trailing={<span className="t-figures t-muted">1,200 {assetLabel} locked</span>} />}
        >
          {rows.map((row, index) => (
            // Rows feed in top to bottom, like a printer advancing the form.
            <div key={index} className={reduced ? '' : 'demo-print'} style={{ animationDelay: `${180 + index * 110}ms` }}>
              <DemoRow
                payday={row.payday}
                status={row.status}
                asset={assetLabel}
                claimedNow={index === 1 && claimed}
                onClaim={index === 1 && !claimed ? () => setClaimed(true) : undefined}
              />
            </div>
          ))}
        </PayrollPaper>
      </Tilt3D>
      <div className="demo-caption" key={String(claimed)}>
        {claimed ? (
          <>
            <span className="t-caption">That is the whole claim: one signature, straight to her wallet.</span>
            <button type="button" className="text-button" onClick={() => setClaimed(false)}>Reset</button>
          </>
        ) : (
          <span className="t-caption">A sample schedule. Try claiming the payout that is ready.</span>
        )}
      </div>
    </div>
  )
}

function DemoRow({ payday, status: base, asset, claimedNow, onClaim }: {
  payday: Date; status: Status; asset: string; claimedNow: boolean; onClaim?: () => void
}) {
  const now = useNow()
  const unlocked = now.getTime() >= payday.getTime()
  const status: Status = claimedNow ? 'claimed' : base === 'locked' && unlocked ? 'ready' : base
  const punch: PunchState = status === 'claimed' ? 'punched' : status === 'ready' ? 'ready' : 'locked'
  const caption = status === 'locked'
    ? `Payday ${formatShortDate(payday)}`
    : status === 'ready'
      ? `Unlocked ${formatShortDate(payday)}`
      : claimedNow ? 'Claimed just now' : `Claimed ${formatShortDate(payday)}`

  return (
    <div className="demo-row">
      <PunchSlot state={punch} />
      <div className="demo-row-text">
        <div className="t-figures" style={{ fontSize: 16 }}>300 {asset}</div>
        <div className="t-caption">{caption}</div>
      </div>
      <div className="demo-row-trailing">
        {status === 'claimed' && <span key={`stamp${claimedNow}`} className="demo-swap"><ClaimedStamp animate={claimedNow} /></span>}
        {status === 'ready' && <button key="claim" type="button" className="demo-claim demo-swap" onClick={onClaim}>Claim</button>}
        {status === 'locked' && (
          <span key="locked" className="demo-locked demo-swap">
            <LockKeyhole size={15} />
            <span className="t-figures">{countdownLabel(payday.getTime() - now.getTime())}</span>
          </span>
        )}
      </div>
    </div>
  )
}

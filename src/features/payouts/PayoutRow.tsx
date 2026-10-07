import { ArrowRightLeft, HandCoins, Hourglass, LockKeyhole } from 'lucide-react'
import { formatAmount } from '../../state/amount'
import { explorer } from '../../state/config'
import { unlockTimeFor, type Payout } from '../../state/payouts'
import { Button } from '../../ui/Button'
import { ExternalLink } from '../../ui/ExternalLink'
import { countdownLabel, formatDateTime } from '../../ui/format'
import { useNow, useUp } from '../../ui/hooks'
import { FlipCard, PingDot } from '../../ui/Motion'
import { ClaimedStamp, PunchSlot } from '../../ui/Paper'

/**
 * One payout on the employee's pay schedule: locked with a countdown, then
 * ready to claim — and once claimed, the row turns over like a split-flap
 * board to show its stamped receipt.
 */
export function PayoutRow({ payout, address, onClaim, onConvert, claiming, disabled, claimedHash }: {
  payout: Payout; address: string; onClaim: () => void; onConvert?: () => void; claiming: boolean; disabled: boolean; claimedHash?: string
}) {
  return (
    <FlipCard
      vertical
      flipped={!!claimedHash}
      front={<Front payout={payout} address={address} onClaim={onClaim} onConvert={onConvert} claiming={claiming} disabled={disabled} />}
      back={<Back payout={payout} claimedHash={claimedHash} />}
    />
  )
}

function Front({ payout, address, onClaim, onConvert, claiming, disabled }: {
  payout: Payout; address: string; onClaim: () => void; onConvert?: () => void; claiming: boolean; disabled: boolean
}) {
  const now = useNow()
  const wide = useUp('sm')
  const unlockAt = unlockTimeFor(payout, address)
  const unlocked = unlockAt === null || now.getTime() >= unlockAt.getTime()
  const when = unlockAt === null ? 'Claimable any time' : unlocked ? `Unlocked ${formatDateTime(unlockAt)}` : `Unlocks ${formatDateTime(unlockAt)}`

  const action = unlocked
    ? (
      <div key="ready" className="payout-actions payout-swap">
        {onConvert && <Button label="Claim as PHPT" icon={<ArrowRightLeft />} disabled={disabled} onClick={onConvert} />}
        <Button
          label={onConvert ? 'Claim USDC only' : 'Claim'}
          icon={onConvert ? undefined : <HandCoins />}
          tone={onConvert ? 'secondary' : 'payday'}
          loading={claiming}
          disabled={disabled}
          onClick={onClaim}
        />
      </div>
    )
    : (
      <span key="locked" className="payout-countdown payout-swap">
        <Hourglass size={14} />
        <span className="t-figures" aria-label={`Unlocks in ${countdownLabel(unlockAt!.getTime() - now.getTime())}`}>
          {countdownLabel(unlockAt!.getTime() - now.getTime())}
        </span>
      </span>
    )

  const details = (
    <div className="payout-details">
      <span className="t-amount" style={{ fontSize: 21 }}>{formatAmount(payout.amount)} {payout.assetCode}</span>
      <span className="payout-when">
        {unlocked ? <span className="payout-ping"><PingDot /></span> : <LockKeyhole size={13} className="payout-lock" />}
        <span className="t-caption">{when}</span>
      </span>
      <ExternalLink href={explorer.claimableBalance(payout.balanceId)} label="View on-chain" small className="payout-chain" />
    </div>
  )
  const slot = <PunchSlot state={unlocked ? 'ready' : 'locked'} />

  return (
    <div className={`payout-row ${wide ? 'wide' : ''}`} aria-label={unlocked ? 'Payout ready to claim' : 'Locked payout'}>
      {wide
        ? <>{slot}{details}<div className="payout-action">{action}</div></>
        : (
          <>
            <span style={{ paddingTop: 4 }}>{slot}</span>
            <div className="payout-stack">{details}<div className="payout-action left">{action}</div></div>
          </>
        )}
    </div>
  )
}

/** The receipt side: punched slot, stamp, and the transaction. */
function Back({ payout, claimedHash }: { payout: Payout; claimedHash?: string }) {
  return (
    <div className="payout-row payout-back" aria-label="Claimed payout">
      <PunchSlot state="punched" />
      <div className="payout-details">
        <span className="t-subtitle">{formatAmount(payout.amount)} {payout.assetCode} is in your wallet</span>
        {claimedHash && <ExternalLink href={explorer.transaction(claimedHash)} label="View transaction" small />}
      </div>
      <ClaimedStamp animate />
    </div>
  )
}

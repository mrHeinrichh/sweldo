import { RefreshCw } from 'lucide-react'
import { amountString, formatAmount } from '../../state/amount'
import { IconButton } from '../../ui/Button'
import { easeOutCubic } from '../../ui/curves'
import { useWide } from '../../ui/hooks'
import { KeyText } from '../../ui/KeyText'
import { Panel } from '../../ui/Layout'
import { useTween } from '../../ui/Motion'

/** Connected wallet, total still to come, and a manual refresh. */
export function WalletOverview({ address, totalUnits, assetLabel, activeCount, loading, onRefresh }: {
  address: string; totalUnits: bigint; assetLabel: string; activeCount: number; loading: boolean; onRefresh: () => void
}) {
  const wide = useWide()
  const total = useTween(Number(amountString(totalUnits)), 480, easeOutCubic)
  const wallet = (
    <div className="overview-cell">
      <span className="t-caption">Connected wallet</span>
      <span className="overview-key"><KeyText value={address} edge={8} strong /></span>
    </div>
  )
  const totalCell = (
    <div className="overview-cell">
      <span className="t-caption">Locked and claimable</span>
      <span className="overview-figure"><span className="t-amount-lg">{formatAmount(total)}</span><span className="t-label t-muted"> {assetLabel}</span></span>
    </div>
  )
  const count = (
    <div className="overview-cell">
      <span className="t-caption">Payouts ahead</span>
      <span className="t-amount-lg overview-figure">{activeCount}</span>
    </div>
  )
  const refresh = <IconButton icon={<RefreshCw />} label="Read the ledger again" loading={loading} onClick={onRefresh} size={44} />

  return (
    <Panel className={`overview ${wide ? 'wide' : ''}`}>
      {wide
        ? <>{wallet}{totalCell}{count}{refresh}</>
        : (
          <>
            <div className="overview-top">{wallet}{refresh}</div>
            <hr className="overview-divider" />
            <div className="overview-bottom">{totalCell}{count}</div>
          </>
        )}
    </Panel>
  )
}

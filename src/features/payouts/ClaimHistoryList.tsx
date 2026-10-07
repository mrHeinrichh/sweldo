import { Check } from 'lucide-react'
import { formatAmount } from '../../state/amount'
import { explorer } from '../../state/config'
import { claimProofKey, type ClaimRecord } from '../../state/payouts'
import { ExternalLink } from '../../ui/ExternalLink'
import { formatDateTime, shortKey } from '../../ui/format'
import { Panel, SectionHeading } from '../../ui/Layout'

/** Completed claims for this wallet, each with its transaction proof. */
export function ClaimHistoryList({ history, assetLabel, freshKey }: { history: ClaimRecord[]; assetLabel: string; freshKey: string | null }) {
  return (
    <Panel>
      <SectionHeading title="Claim history" description="Completed claims for this wallet." trailing={<span className="t-caption">{history.length} claimed</span>} />
      <div style={{ height: 'var(--s-lg)' }} />
      {history.length === 0
        ? <p className="t-body-sm m0">No claims yet. Each payout you claim appears here with its transaction proof.</p>
        : history.map((record, index) => (
          <div key={claimProofKey(record)}>
            {index > 0 && <hr className="history-divider" />}
            <div className={`history-row ${claimProofKey(record) === freshKey ? 'fresh' : ''}`}>
              <span className="history-check"><Check size={16} /></span>
              <div className="history-text">
                <span className="t-figures" style={{ fontSize: 16 }}>
                  {record.amount ? `${formatAmount(record.amount)} ${record.asset ?? assetLabel}` : 'Payroll payout claimed'}
                </span>
                <span className="t-caption">{formatDateTime(new Date(record.claimedAt))}</span>
                {record.balanceId && <span className="t-mono" style={{ fontSize: 12 }}>{shortKey(record.balanceId, 8)}</span>}
              </div>
              {record.transactionHash && <ExternalLink href={explorer.transaction(record.transactionHash)} label="View transaction" small />}
            </div>
          </div>
        ))}
    </Panel>
  )
}

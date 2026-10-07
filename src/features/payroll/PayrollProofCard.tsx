import { formatAmount } from '../../state/amount'
import { explorer } from '../../state/config'
import type { PayrollProof } from '../../state/payroll-form'
import { ExternalLink } from '../../ui/ExternalLink'
import { formatDateTime } from '../../ui/format'
import { KeyText } from '../../ui/KeyText'
import { ClaimedStamp, PaperHeader, PayrollPaper } from '../../ui/Paper'

/** The receipt stub printed after a payroll is locked. */
export function PayrollProofCard({ proof }: { proof: PayrollProof }) {
  const rows: [string, string][] = [
    ['Total locked', `${formatAmount(proof.total)} ${proof.asset}`],
    ['Payouts created', `${proof.balanceCount}`],
    ['Employees', `${proof.employeeCount}`],
    ['Payouts each', `${proof.payouts}`],
    ['First payday', formatDateTime(proof.firstUnlock)],
  ]
  return (
    <PayrollPaper header={<PaperHeader title="Payroll locked on Stellar Testnet" trailing={<ClaimedStamp label="Locked" animate />} />}>
      {rows.map(([label, value]) => (
        <div key={label} className="proof-row">
          <span className="t-body-sm">{label}</span>
          <span className="t-figures">{value}</span>
        </div>
      ))}
      <div className="proof-links">
        <span className="t-caption">Payroll transaction</span>
        <KeyText value={proof.hash} edge={10} />
        <ExternalLink href={explorer.transaction(proof.hash)} label="Verify on Stellar Expert" />
        {proof.registryContractId && (
          <>
            <span className="t-caption" style={{ marginTop: 'var(--s-md)' }}>Soroban payroll registry</span>
            <KeyText value={proof.registryContractId} edge={10} />
            {proof.registryHash && <ExternalLink href={explorer.transaction(proof.registryHash)} label="Verify registry proof" />}
          </>
        )}
      </div>
    </PayrollPaper>
  )
}

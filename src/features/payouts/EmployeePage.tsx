import { useState } from 'react'
import { Puzzle, RefreshCw, Smartphone, Wallet } from 'lucide-react'
import { PageFrame } from '../../app/Shell'
import { supportsConversion } from '../../lib/claim-convert'
import { assetLabel as configAssetLabel, conversionPair } from '../../state/config'
import { unlockTimeFor, usePayouts, type Payout } from '../../state/payouts'
import { useWallet } from '../../state/wallet'
import { Button } from '../../ui/Button'
import { shortKey } from '../../ui/format'
import { Panel, SectionHeading } from '../../ui/Layout'
import { PingDot, Skeleton, Tilt3D } from '../../ui/Motion'
import { AnimatedNotice, Collapse } from '../../ui/Notice'
import { PayrollPaper } from '../../ui/Paper'
import { AccountSetupPrompts } from '../account/AccountSetupPrompts'
import { ConversionReceiptCard, ConversionSheet } from '../conversion/ConversionSheet'
import { ClaimHistoryList } from './ClaimHistoryList'
import { PayoutRow } from './PayoutRow'
import { WalletOverview } from './WalletOverview'
import '../payroll/payroll.css'
import './payouts.css'

export function EmployeePage() {
  const { session } = useWallet()
  return (
    <PageFrame title="My pay" description="Your salary on Stellar. Each payout unlocks on its payday, and you claim it straight to your wallet.">
      <div key={session?.address ?? 'connect'} className="pay-switch">
        {session ? <PayView address={session.address} /> : <ConnectPrompt />}
      </div>
    </PageFrame>
  )
}

/** A compact, centred invitation to connect: everything on one axis, no empty half-panel. */
function ConnectPrompt() {
  const wallet = useWallet()
  return (
    <div className="connect-prompt-wrap">
      <Panel className="connect-prompt">
        <Tilt3D maxTilt={18} baseX={8} radius={22} className="wallet-tile-tilt">
          <span className="wallet-tile">
            <Wallet size={34} color="#fff" />
            <span className="wallet-tile-ping"><PingDot color="#fff" size={7} /></span>
          </span>
        </Tilt3D>
        <h2 className="t-title m0 t-center" style={{ marginTop: 'var(--s-xl)' }}>Connect to see your pay</h2>
        <p className="t-body-sm m0 t-center" style={{ marginTop: 'var(--s-sm)' }}>
          Use the Freighter wallet your employer added to the payroll. Your payouts are read straight from the Stellar ledger.
        </p>
        <div data-tour="connect-pay" style={{ marginTop: 'var(--s-xl)' }}>
          <Button label="Connect Freighter" icon={<Wallet />} large onClick={wallet.openSheet} />
        </div>
        <div className="connect-hints">
          <span><Puzzle size={14} /><span className="t-caption">Browser extension</span></span>
          <span><Smartphone size={14} /><span className="t-caption">Freighter app</span></span>
        </div>
      </Panel>
    </div>
  )
}

function PayView({ address }: { address: string }) {
  const payouts = usePayouts()
  const [converting, setConverting] = useState<Payout | null>(null)
  const open = payouts.openPayouts
  const assetLabel = open.length === 0 ? configAssetLabel : open[0].assetCode

  return (
    <div className="pay-view">
      <WalletOverview address={address} totalUnits={payouts.totalUnits} assetLabel={assetLabel} activeCount={open.length} loading={payouts.loading} onRefresh={payouts.refresh} />
      <div style={{ height: 'var(--s-lg)' }} />
      <AnimatedNotice data={payouts.notice} />
      <Collapse open={payouts.receipt !== null}>
        {payouts.receipt && <div style={{ paddingBottom: 'var(--s-lg)' }}><ConversionReceiptCard receipt={payouts.receipt} /></div>}
      </Collapse>
      <AccountSetupPrompts trustlineMessage="Add a trustline so this wallet can receive the payroll asset before you claim." />
      <div style={{ height: 'var(--s-md)' }} />
      <SectionHeading title="Pay schedule" description="Payouts addressed to your wallet, soonest first." trailing={<span className="t-caption">{payouts.payouts.length} on the ledger</span>} />
      <div style={{ height: 'var(--s-lg)' }} />
      <div data-tour="pay-schedule"><Timeline address={address} onConvert={setConverting} /></div>
      <div style={{ height: 'var(--s-xxl)' }} />
      <div data-tour="claim-history">
        <ClaimHistoryList history={payouts.history} assetLabel={configAssetLabel} freshKey={payouts.freshClaimKey} />
      </div>
      {conversionPair && (
        <ConversionSheet
          open={converting !== null}
          address={address}
          payout={converting}
          pair={conversionPair}
          onClose={() => setConverting(null)}
          onReceipt={(receipt) => { setConverting(null); payouts.conversionCompleted(receipt) }}
        />
      )}
    </div>
  )
}

function Timeline({ address, onConvert }: { address: string; onConvert: (payout: Payout) => void }) {
  const payouts = usePayouts()
  if (!payouts.loaded && payouts.loading) return <LedgerLoading />
  if (payouts.payouts.length === 0) {
    return (
      <Panel>
        <div className="t-subtitle">No pay scheduled yet</div>
        <p className="t-body-sm m0" style={{ marginTop: 'var(--s-xs)' }}>Ask your employer to lock a payroll for {shortKey(address, 8)}, then refresh.</p>
        <div style={{ marginTop: 'var(--s-lg)' }}>
          <Button label="Refresh" icon={<RefreshCw />} tone="secondary" loading={payouts.loading} onClick={payouts.refresh} />
        </div>
      </Panel>
    )
  }
  // Soonest payday first: that's the order paydays arrive in.
  const sorted = [...payouts.payouts].sort((a, b) => (unlockTimeFor(a, address)?.getTime() ?? 0) - (unlockTimeFor(b, address)?.getTime() ?? 0))
  return (
    <PayrollPaper>
      {sorted.map((payout) => (
        <PayoutRow
          key={payout.balanceId}
          payout={payout}
          address={address}
          claiming={payouts.claimingId === payout.balanceId}
          disabled={payouts.claimingId !== null || payouts.loading}
          claimedHash={payouts.claimedHashes[payout.balanceId]}
          onClaim={() => payouts.claim(payout)}
          onConvert={conversionPair && supportsConversion({ balance_id: payout.balanceId, asset: payout.asset, amount: payout.amount, claimants: payout.claimants }, conversionPair) ? () => onConvert(payout) : undefined}
        />
      ))}
    </PayrollPaper>
  )
}

/** Pulsing placeholder rows while the ledger is read. */
function LedgerLoading() {
  return (
    <div aria-label="Reading the Stellar ledger">
      <PayrollPaper>
        {[0, 1, 2].map((i) => (
          <div key={i} className="ledger-loading-row">
            <Skeleton width={14} height={22} radius={7} />
            <div className="ledger-loading-text">
              <Skeleton width={120} height={18} />
              <Skeleton width={190} height={12} />
            </div>
            <Skeleton width={88} height={30} radius={999} />
          </div>
        ))}
      </PayrollPaper>
    </div>
  )
}

import { useCallback, useEffect, useRef, useState } from 'react'
import { ArrowRightLeft, ChevronDown, CircleCheck, Link, LoaderCircle, RefreshCw, X } from 'lucide-react'
import { claimAndConvert, SubmissionUncertain } from '../../lib/claim-convert-wallet'
import { QUOTE_LIFETIME_MS, quoteClaimConversion, type ConversionPair, type ConversionQuote, type ConversionReceipt } from '../../lib/claim-convert'
import { server } from '../../lib/stellar'
import { formatAmount } from '../../state/amount'
import { explorer } from '../../state/config'
import { conversionError } from '../../state/errors'
import type { Payout } from '../../state/payouts'
import { Button } from '../../ui/Button'
import { ExternalLink } from '../../ui/ExternalLink'
import { useNow } from '../../ui/hooks'
import { KeyText } from '../../ui/KeyText'
import { AnimatedNotice, Collapse } from '../../ui/Notice'
import { Sheet } from '../../ui/Sheet'
import { ClaimedStamp } from '../../ui/Paper'

type ConversionState = {
  quote: ConversionQuote | null
  loading: boolean
  signing: boolean
  error: string | null
  /** The transaction may have landed; the person must check before retrying. */
  uncertainHash: string | null
}

/** Claim-and-convert for one payout. Resolves with the receipt, or closes empty. */
export function ConversionSheet({ open, address, payout, pair, onClose, onReceipt }: {
  open: boolean; address: string; payout: Payout | null; pair: ConversionPair; onClose: () => void; onReceipt: (receipt: ConversionReceipt) => void
}) {
  return (
    <Sheet open={open} onClose={onClose} label="Claim as PHPT" maxWidth={480} dismissible={false}>
      {payout && <ConversionContent key={payout.balanceId} address={address} payout={payout} pair={pair} onClose={onClose} onReceipt={onReceipt} />}
    </Sheet>
  )
}

function ConversionContent({ address, payout, pair, onClose, onReceipt }: {
  address: string; payout: Payout; pair: ConversionPair; onClose: () => void; onReceipt: (receipt: ConversionReceipt) => void
}) {
  const [state, setState] = useState<ConversionState>({ quote: null, loading: true, signing: false, error: null, uncertainHash: null })
  const request = useRef(0)
  const now = useNow()
  const locked = state.uncertainHash !== null

  const requestQuote = useCallback(async () => {
    const id = ++request.current
    setState({ quote: null, loading: true, signing: false, error: null, uncertainHash: null })
    try {
      const quote = await quoteClaimConversion(server, address, payout.balanceId, pair)
      if (id === request.current) setState({ quote, loading: false, signing: false, error: null, uncertainHash: null })
    } catch (error) {
      if (id === request.current) setState({ quote: null, loading: false, signing: false, error: conversionError(error), uncertainHash: null })
    }
  }, [address, payout.balanceId, pair])

  useEffect(() => { void requestQuote() }, [requestQuote])

  const confirm = async () => {
    const quote = state.quote
    if (!quote || state.signing || Date.now() >= quote.expiresAt) return
    setState({ quote, loading: false, signing: true, error: null, uncertainHash: null })
    try {
      const receipt = await claimAndConvert(server, quote)
      onReceipt(receipt)
    } catch (error) {
      if (error instanceof SubmissionUncertain) {
        setState({ quote: null, loading: false, signing: false, error: error.message, uncertainHash: error.transactionHash })
      } else {
        setState({ quote: null, loading: false, signing: false, error: conversionError(error), uncertainHash: null })
      }
    }
  }

  const quote = state.quote
  const expired = quote !== null && now.getTime() >= quote.expiresAt

  return (
    <div className="conversion">
      <div className="conversion-head">
        <h2 className="t-title m0">Claim as PHPT</h2>
        <button type="button" className="conversion-close" onClick={onClose} disabled={state.signing} aria-label="Close" title="Close"><X size={24} /></button>
      </div>
      <p className="t-body-sm m0">Claim {formatAmount(payout.amount)} test-USDC and receive PHPT in your connected wallet, in one transaction.</p>
      <div style={{ height: 'var(--s-xl)' }} />
      {state.loading && (
        <div className="conversion-checking" aria-live="polite">
          <LoaderCircle size={18} className="spin" />
          <span className="t-body-sm">Checking the payout, trustlines and liquidity…</span>
        </div>
      )}
      {!state.loading && quote && <QuoteDetails quote={quote} now={now} />}
      <AnimatedNotice data={state.error ? { tone: 'error', text: state.error } : null} gap="top" />
      {state.uncertainHash && (
        <div className="conversion-uncertain">
          <span className="t-caption">Check this transaction before retrying:</span>
          <KeyText value={state.uncertainHash} edge={10} />
          <ExternalLink href={explorer.transaction(state.uncertainHash)} label="Open on Stellar Expert" />
        </div>
      )}
      <p className="t-caption m0 conversion-note">Test assets have no real value. If the conversion fails, the payout stays unclaimed. A submitted transaction may still charge a network fee.</p>
      <div className="conversion-actions">
        <Button label="Refresh quote" icon={<RefreshCw />} tone="secondary" disabled={state.loading || state.signing || locked} onClick={() => void requestQuote()} />
        <Button
          label={state.signing ? 'Confirm in Freighter…' : 'Claim and convert'}
          icon={<ArrowRightLeft />}
          loading={state.signing}
          disabled={!quote || expired || state.loading || locked}
          onClick={() => void confirm()}
        />
      </div>
    </div>
  )
}

function QuoteDetails({ quote, now }: { quote: ConversionQuote; now: Date }) {
  const [issuersOpen, setIssuersOpen] = useState(false)
  const leftMs = Math.max(0, quote.expiresAt - now.getTime())
  const expired = leftMs <= 0
  const fraction = Math.min(1, Math.max(0, leftMs / QUOTE_LIFETIME_MS))
  const rows: [string, string][] = [
    ['Payout', `${formatAmount(quote.sendAmount)} test-USDC`],
    ['You receive about', `${formatAmount(quote.expectedAmount)} PHPT`],
    ['At least', `${formatAmount(quote.minimumAmount)} PHPT`],
    ['Price may move', 'Up to 1%'],
  ]
  const missing = quote.missingTrustlines.map((asset) => asset.code).join(' and ')
  const r = 6.8
  const circumference = 2 * Math.PI * r

  return (
    <div className="quote">
      <div className="quote-table">
        {rows.map(([label, value], i) => (
          <div key={label} className={`quote-row ${i % 2 === 0 ? 'banded' : ''}`}>
            <span className="t-body-sm">{label}</span>
            <span className="t-figures">{value}</span>
          </div>
        ))}
        <div className="quote-row">
          <span className="t-body-sm">Quote</span>
          <svg width={16} height={16} viewBox="0 0 16 16" aria-hidden className="quote-ring">
            <circle cx={8} cy={8} r={r} fill="none" stroke="var(--greenbar)" strokeWidth={2.4} />
            <circle cx={8} cy={8} r={r} fill="none" stroke={expired ? 'var(--danger)' : 'var(--stamp)'} strokeWidth={2.4}
              strokeDasharray={circumference} strokeDashoffset={circumference * (1 - fraction)} transform="rotate(-90 8 8)" />
          </svg>
          <span className="t-figures" style={{ color: expired ? 'var(--danger)' : 'var(--ink)' }}>{expired ? 'Expired. Refresh it.' : `${Math.floor(leftMs / 1000)}s left`}</span>
        </div>
      </div>
      <div className="quote-trust">
        {missing ? <Link size={20} className="quote-trust-icon add" /> : <CircleCheck size={20} className="quote-trust-icon ok" />}
        <p className="t-body-sm t-ink m0">
          {missing ? `Sweldo adds ${missing} to your wallet in the same transaction. Keep some test XLM for reserves and fees.` : 'Your wallet can already hold both test assets.'}
        </p>
      </div>
      <button type="button" className="quote-issuers-toggle" aria-expanded={issuersOpen} onClick={() => setIssuersOpen((value) => !value)}>
        <span className="t-label">Test asset issuers</span>
        <ChevronDown size={24} className={issuersOpen ? 'open' : ''} />
      </button>
      <Collapse open={issuersOpen}>
        <div className="quote-issuers">
          <span className="t-caption">USDC</span>
          <KeyText value={quote.source.issuer ?? ''} edge={10} />
          <span className="t-caption">PHPT</span>
          <KeyText value={quote.destination.issuer ?? ''} edge={10} />
        </div>
      </Collapse>
    </div>
  )
}

/** Proof that a claim-and-convert landed. */
export function ConversionReceiptCard({ receipt }: { receipt: ConversionReceipt }) {
  const received = receipt.receivedAmount
  return (
    <div className="receipt-card" aria-live="polite">
      <div className="receipt-head">
        <span className="t-subtitle">Payout claimed as PHPT</span>
        <ClaimedStamp label="Converted" animate color="var(--payday)" />
      </div>
      <p className="t-body-sm t-ink m0">
        {formatAmount(receipt.sentAmount)} test-USDC claimed. {received !== null
          ? `${formatAmount(received)} PHPT received.`
          : `At least ${formatAmount(receipt.minimumAmount)} PHPT received. Open the transaction for the exact amount.`}
      </p>
      <div style={{ height: 'var(--s-sm)' }} />
      <KeyText value={receipt.hash} edge={10} />
      <ExternalLink href={explorer.transaction(receipt.hash)} label="Verify on Stellar Expert" className="tone-success" />
    </div>
  )
}

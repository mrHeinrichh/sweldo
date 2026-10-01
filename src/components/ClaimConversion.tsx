import { useCallback, useEffect, useRef, useState } from 'react'
import { ArrowRightLeft, Check, Copy, ExternalLink, LoaderCircle, RefreshCw, X } from 'lucide-react'
import { server, type BalanceRecord } from '../lib/stellar'
import { conversionError, quoteClaimConversion, type ConversionPair, type ConversionQuote, type ConversionReceipt } from '../lib/claim-convert'
import { claimAndConvert, SubmissionUncertain } from '../lib/claim-convert-wallet'
import './ClaimConversion.css'

const explorer = 'https://stellar.expert/explorer/testnet/tx/'

export function ClaimConversionDialog({ address, payout, pair, onClose, onComplete }: {
  address: string; payout: BalanceRecord; pair: ConversionPair
  onClose: () => void; onComplete: (receipt: ConversionReceipt) => void
}) {
  const dialog = useRef<HTMLDialogElement>(null)
  const [quote, setQuote] = useState<ConversionQuote | null>(null)
  const [loading, setLoading] = useState(true)
  const [signing, setSigning] = useState(false)
  const [error, setError] = useState('')
  const [uncertainHash, setUncertainHash] = useState('')
  const [now, setNow] = useState(Date.now())
  const requestId = useRef(0)
  const expired = !!quote && now >= quote.expiresAt
  const refreshQuote = useCallback(async () => {
    const id = ++requestId.current
    setLoading(true); setQuote(null); setError('')
    try {
      const next = await quoteClaimConversion(server, address, payout.balance_id, pair)
      if (requestId.current === id) { setQuote(next); setNow(Date.now()) }
    } catch (cause) {
      if (requestId.current === id) setError(conversionError(cause))
    } finally { if (requestId.current === id) setLoading(false) }
  }, [address, payout.balance_id, pair])
  useEffect(() => {
    const pendingRequests = requestId
    dialog.current?.showModal()
    void refreshQuote()
    const timer = window.setInterval(() => setNow(Date.now()), 1000)
    return () => { ++pendingRequests.current; window.clearInterval(timer) }
  }, [refreshQuote])
  async function confirm() {
    if (!quote || signing || Date.now() >= quote.expiresAt) return
    setSigning(true); setError('')
    try { onComplete(await claimAndConvert(server, quote)) }
    catch (cause) {
      setError(conversionError(cause)); setQuote(null)
      if (cause instanceof SubmissionUncertain) setUncertainHash(cause.transactionHash)
    } finally { setSigning(false) }
  }
  return <dialog ref={dialog} className="conversion-dialog" aria-labelledby="conversion-title" onCancel={(event) => { event.preventDefault(); if (!signing) onClose() }}>
    <div className="conversion-heading"><div><span>STELLAR TESTNET</span><h2 id="conversion-title">Claim as PHPT</h2></div><button className="conversion-icon" aria-label="Close conversion" title="Close" disabled={signing} onClick={onClose}><X size={20} /></button></div>
    <p className="conversion-description">Claim {payout.amount} test-USDC and receive PHPT in your connected wallet.</p>
    {loading && <div className="conversion-loading" role="status"><LoaderCircle className="spin" size={20} /> Checking payout, trustlines, and liquidity...</div>}
    {quote && <>
      <dl className="conversion-summary">
        <div><dt>Payout</dt><dd>{quote.sendAmount} test-USDC</dd></div>
        <div><dt>Expected receipt</dt><dd>{quote.expectedAmount} PHPT</dd></div>
        <div><dt>Minimum receipt</dt><dd>{quote.minimumAmount} PHPT</dd></div>
        <div><dt>Slippage limit</dt><dd>1%</dd></div>
        <div><dt>Quote</dt><dd>{expired ? 'Expired' : `${Math.max(0, Math.ceil((quote.expiresAt - now) / 1000))}s remaining`}</dd></div>
      </dl>
      <div className="conversion-trust"><strong>{quote.missingTrustlines.length ? `Enable ${quote.missingTrustlines.map((asset) => asset.code).join(' and ')}` : 'Trustlines ready'}</strong><p>{quote.missingTrustlines.length ? 'Missing trustlines will be added with your claim. Keep Testnet XLM available for reserves and fees.' : 'Your wallet can receive both test assets.'}</p></div>
      <details className="conversion-assets"><summary>Test asset issuers</summary><p>USDC: <code>{quote.source.issuer}</code></p><p>PHPT: <code>{quote.destination.issuer}</code></p></details>
    </>}
    {error && <div className="notice error" role="alert">{error}</div>}
    {uncertainHash && <a className="conversion-tx" href={`${explorer}${uncertainHash}`} target="_blank" rel="noreferrer">Check transaction <ExternalLink size={14} /><code>{uncertainHash}</code></a>}
    <p className="conversion-policy">Test assets have no real value. If conversion fails, the payout stays unclaimed. A submitted transaction may still charge a network fee.</p>
    <div className="conversion-actions">
      <button className="button button-ghost" onClick={refreshQuote} disabled={loading || signing || !!uncertainHash}><RefreshCw size={16} /> Refresh quote</button>
      <button className="button button-primary" onClick={confirm} disabled={!quote || expired || loading || signing || !!uncertainHash}>{signing ? <LoaderCircle className="spin" size={16} /> : <ArrowRightLeft size={16} />}{signing ? 'Confirm in Freighter...' : 'Claim and convert'}</button>
    </div>
  </dialog>
}

export function ClaimConversionReceipt({ receipt }: { receipt: ConversionReceipt }) {
  const [copied, setCopied] = useState(false)
  const [copyError, setCopyError] = useState('')
  async function copy() {
    try { await navigator.clipboard.writeText(receipt.hash); setCopied(true); setCopyError('') }
    catch { setCopyError('Copy unavailable. Select the transaction hash below.') }
  }
  return <section className="conversion-receipt" aria-label="Claim and conversion receipt" role="status">
    <div className="conversion-receipt-heading"><Check size={20} /><h2>Payout claimed as PHPT</h2></div>
    <p>{receipt.sentAmount} test-USDC claimed. {receipt.receivedAmount ? `${receipt.receivedAmount} PHPT received.` : `At least ${receipt.minimumAmount} PHPT received. Open the transaction for the exact amount.`}</p>
    <div className="conversion-receipt-proof"><code>{receipt.hash}</code><button className="conversion-icon" onClick={copy} aria-label={copied ? 'Transaction hash copied' : 'Copy transaction hash'} title={copied ? 'Copied' : 'Copy transaction hash'}>{copied ? <Check size={17} /> : <Copy size={17} />}</button></div>
    {copyError && <p>{copyError}</p>}
    <a href={`${explorer}${receipt.hash}`} target="_blank" rel="noreferrer">Verify on Stellar Expert <ExternalLink size={14} /></a>
  </section>
}

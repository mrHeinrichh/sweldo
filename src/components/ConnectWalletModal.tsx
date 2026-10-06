import { useEffect, useRef, useState } from 'react'
import QRCode from 'qrcode'
import { Check, ChevronRight, Copy, ExternalLink, LoaderCircle, LogOut, Puzzle, QrCode, Smartphone, X } from 'lucide-react'
import {
  connect,
  FREIGHTER_MISSING,
  freighterDeepLink,
  isMobileBrowser,
  mobileAvailable,
  type WalletKind,
  type WalletState,
} from '../lib/wallets'
import './ConnectWalletModal.css'

type Props = {
  open: boolean
  wallet: WalletState | null
  onClose: () => void
  onConnected: (wallet: WalletState) => void
  onDisconnect: () => void
}

type View = 'choose' | 'pairing' | 'connected'

const KIND_LABEL: Record<WalletKind, string> = {
  'freighter-extension': 'Freighter extension',
  'freighter-mobile': 'Freighter app',
}

/**
 * Connect with the Freighter browser extension, or pair the Freighter
 * mobile app over WalletConnect: a QR code on desktop, a deep link on phones.
 */
export function ConnectWalletModal({ open, wallet, onClose, onConnected, onDisconnect }: Props) {
  const dialog = useRef<HTMLDialogElement>(null)
  const [view, setView] = useState<View>('choose')
  const [busy, setBusy] = useState<WalletKind | null>(null)
  const [error, setError] = useState('')
  const [pairingUri, setPairingUri] = useState('')
  const [qr, setQr] = useState('')
  const [copied, setCopied] = useState(false)
  const pairing = useRef<AbortController | null>(null)
  const mobile = isMobileBrowser()

  useEffect(() => {
    const element = dialog.current
    if (!element) return
    if (open && !element.open) {
      element.showModal()
      setView(wallet ? 'connected' : 'choose')
      setError('')
    }
    if (!open && element.open) element.close()
  }, [open, wallet])

  useEffect(() => {
    if (!pairingUri) return
    let cancelled = false
    QRCode.toDataURL(pairingUri, { margin: 1, width: 480, color: { dark: '#1c1a22', light: '#ffffff' } })
      .then((url) => { if (!cancelled) setQr(url) })
      .catch(() => { if (!cancelled) setQr('') })
    return () => { cancelled = true }
  }, [pairingUri])

  function close() {
    pairing.current?.abort()
    pairing.current = null
    setBusy(null)
    setPairingUri('')
    setQr('')
    onClose()
  }

  async function choose(kind: WalletKind) {
    setBusy(kind)
    setError('')
    const controller = new AbortController()
    pairing.current = controller
    try {
      const next = await connect(kind, {
        signal: controller.signal,
        onPairingUri: (uri) => {
          setPairingUri(uri)
          setView('pairing')
          // On a phone, hand the pairing straight to Freighter.
          if (mobile) window.location.href = freighterDeepLink(uri)
        },
      })
      onConnected(next)
      setPairingUri('')
      setQr('')
    } catch (cause) {
      if ((cause as { name?: string })?.name === 'AbortError') return
      setError(cause instanceof Error ? cause.message : String(cause))
      setView('choose')
      setPairingUri('')
    } finally {
      if (pairing.current === controller) pairing.current = null
      setBusy(null)
    }
  }

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(pairingUri)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1800)
    } catch {
      setError('Copy is unavailable here. Scan the code instead.')
    }
  }

  const options: Array<{ kind: WalletKind; icon: React.ReactNode; title: string; body: string; available: boolean }> = [
    {
      kind: 'freighter-mobile',
      icon: mobile ? <Smartphone size={20} /> : <QrCode size={20} />,
      title: 'Freighter app',
      body: !mobileAvailable()
        ? 'Not set up on this site yet.'
        : mobile ? 'Open Freighter on this phone and approve.' : 'Scan a QR code with Freighter on your phone.',
      available: mobileAvailable(),
    },
    {
      kind: 'freighter-extension',
      icon: <Puzzle size={20} />,
      title: 'Freighter extension',
      body: mobile ? 'Browser extensions aren’t available on phones.' : 'Sign in this browser with the Freighter extension.',
      available: !mobile,
    },
  ]
  // Lead with the option that fits this device.
  if (!mobile) options.reverse()

  return (
    <dialog
      ref={dialog}
      className="connect-dialog"
      aria-labelledby="connect-title"
      onCancel={(event) => { event.preventDefault(); close() }}
      onClick={(event) => { if (event.target === dialog.current) close() }}
    >
      <div className="connect-body">
        <button type="button" className="connect-close" aria-label="Close" onClick={close}><X size={18} /></button>

        {view === 'connected' && wallet && <div className="connect-view" key="connected">
          <h2 id="connect-title">Your wallet</h2>
          <p>Connected with the {KIND_LABEL[wallet.kind]} on {wallet.network === 'TESTNET' ? 'Testnet' : wallet.network}.</p>
          <div className="connected-account"><span className="live-dot" /><code>{wallet.address.slice(0, 8)}…{wallet.address.slice(-8)}</code></div>
          <div className="connect-actions">
            <button type="button" className="button button-ghost" onClick={() => setView('choose')}>Switch wallet</button>
            <button type="button" className="button button-cancel" onClick={() => { onDisconnect(); close() }}><LogOut size={15} /> Disconnect</button>
          </div>
        </div>}

        {view === 'choose' && <div className="connect-view" key="choose">
          <h2 id="connect-title">Connect Freighter</h2>
          <p>Freighter signs each transaction after you review it. Sweldo never sees your keys.</p>
          <div className="wallet-options">
            {options.map((option) => (
              <button
                key={option.kind}
                type="button"
                className={`wallet-option ${busy === option.kind ? 'busy' : ''}`}
                disabled={!option.available || busy !== null}
                onClick={() => choose(option.kind)}
              >
                <span className="wallet-option-icon">{option.icon}</span>
                <span className="wallet-option-text"><strong>{option.title}</strong><small>{option.body}</small></span>
                {busy === option.kind ? <LoaderCircle size={18} className="spin" /> : option.available && <ChevronRight size={18} className="wallet-option-chevron" />}
              </button>
            ))}
          </div>
          {error && <div className="connect-error" role="alert">{error}{error === FREIGHTER_MISSING && <a href="https://www.freighter.app/" target="_blank" rel="noreferrer">Get Freighter <ExternalLink size={12} /></a>}</div>}
          <p className="connect-foot">Don’t have Freighter? <a href="https://www.freighter.app/" target="_blank" rel="noreferrer">Get it at freighter.app <ExternalLink size={12} /></a></p>
        </div>}

        {view === 'pairing' && <div className="connect-view" key="pairing">
          <h2 id="connect-title">{mobile ? 'Approve in Freighter' : 'Scan with Freighter'}</h2>
          <p>{mobile
            ? 'Freighter should open with a connection request. If it doesn’t, tap Open Freighter.'
            : 'Use the Freighter app on your phone to scan this code, then approve the connection on Testnet.'}</p>
          {!mobile && <div className="qr-frame">
            {qr ? <img src={qr} alt="WalletConnect pairing code for Freighter" width={240} height={240} /> : <LoaderCircle className="spin" />}
            <span className="qr-badge"><Smartphone size={14} /></span>
          </div>}
          {!mobile && <ol className="pairing-steps">
            <li>Open Freighter on your phone.</li>
            <li>Tap the scan button and point it at this code.</li>
            <li>Approve the connection on Testnet.</li>
          </ol>}
          <div className="pairing-wait"><span className="pairing-pulse" /> Waiting for approval</div>
          <div className="connect-actions">
            <button type="button" className="button button-ghost" onClick={() => { pairing.current?.abort(); setView('choose'); setPairingUri('') }}>Back</button>
            <button type="button" className="button button-ghost" onClick={copyLink}>{copied ? <Check size={15} /> : <Copy size={15} />} {copied ? 'Copied' : 'Copy link'}</button>
            {mobile && <a className="button button-primary" href={freighterDeepLink(pairingUri)}><Smartphone size={15} /> Open Freighter</a>}
          </div>
        </div>}
      </div>
    </dialog>
  )
}

/** Shown while a signature waits for approval in the Freighter app. */
export function ApprovalPrompt({ pending }: { pending: boolean }) {
  if (!pending) return null
  const mobile = isMobileBrowser()
  return (
    <div className="approval-prompt" role="status">
      <span className="pairing-pulse" />
      <div><strong>Approve in the Freighter app</strong><small>{mobile ? 'Switch to Freighter to review and sign.' : 'Check your phone to review and sign.'}</small></div>
      {mobile && <a className="button button-primary" href={freighterDeepLink()}>Open Freighter</a>}
    </div>
  )
}

import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { ChevronRight, Copy, LoaderCircle, Puzzle, Smartphone, SquareArrowOutUpRight } from 'lucide-react'
import { freighterStoreName, freighterStoreUrl, isMobileBrowser, openFreighter, unavailableReason, WALLET_KINDS, type WalletKind } from '../../lib/wallets'
import { useToast } from '../../state/toast'
import { useWallet } from '../../state/wallet'
import { Button } from '../../ui/Button'
import { ExternalLink } from '../../ui/ExternalLink'
import { Sheet } from '../../ui/Sheet'
import './wallet.css'

/** The wallet picker. Closes itself once a wallet connects. */
export function ConnectWalletSheet() {
  const wallet = useWallet()
  return (
    <Sheet open={wallet.sheetOpen} onClose={wallet.closeSheet} label="Connect Freighter">
      <div className="connect-content">
        {wallet.pairingUri
          ? <PairingView key={wallet.pairingUri} uri={wallet.pairingUri} />
          : <WalletChoices key="choices" />}
      </div>
    </Sheet>
  )
}

function WalletChoices() {
  const wallet = useWallet()
  // Phones can only use the Freighter app; computers lead with what works here.
  const kinds: WalletKind[] = isMobileBrowser()
    ? ['freighter-mobile']
    : (['freighter-extension', 'freighter-mobile'] as WalletKind[])
      .sort((a, b) => Number(unavailableReason(a) !== null) - Number(unavailableReason(b) !== null))
  return (
    <div className="connect-view">
      <h2 className="t-title m0">Connect Freighter</h2>
      <p className="t-body-sm m0 connect-lede">Freighter signs each transaction after you review it. Sweldo never sees your keys.</p>
      <div className="connect-options">
        {kinds.map((kind) => {
          const reason = unavailableReason(kind)
          const busy = wallet.connectingKind === kind
          const enabled = reason === null && wallet.status !== 'connecting'
          return (
            <button
              key={kind}
              type="button"
              className={`connect-option sw-interactive ${busy ? 'busy' : ''} ${reason ? 'unavailable' : ''}`}
              disabled={!enabled}
              onClick={() => wallet.connect(kind)}
            >
              <span className="connect-option-icon">{kind === 'freighter-extension' ? <Puzzle size={20} /> : <Smartphone size={20} />}</span>
              <span className="connect-option-text">
                <span className="t-subtitle">{WALLET_KINDS[kind].title}</span>
                <span className="t-body-sm">{reason ?? WALLET_KINDS[kind].description}</span>
              </span>
              {busy
                ? <LoaderCircle size={18} className="spin connect-option-spinner" />
                : reason === null && <ChevronRight size={24} className="connect-option-chevron" />}
            </button>
          )
        })}
      </div>
      <p className="t-body-sm m0 connect-get">
        Don't have Freighter? <ExternalLink href={freighterStoreUrl()} label={`Get it on ${freighterStoreName()}`} className="connect-get-link" />
      </p>
    </div>
  )
}

/** WalletConnect pairing: a QR code for Freighter on another device, plus a direct link on phones. */
function PairingView({ uri }: { uri: string }) {
  const wallet = useWallet()
  const toast = useToast()
  const onPhone = isMobileBrowser()
  const [svg, setSvg] = useState('')

  // On a phone, hand straight over to Freighter (or its store page if it isn't installed).
  useEffect(() => { if (onPhone) openFreighter(uri) }, [onPhone, uri])

  useEffect(() => {
    QRCode.toString(uri, { type: 'svg', margin: 0, errorCorrectionLevel: 'L', color: { dark: '#14213A', light: '#FFFFFF' } })
      .then(setSvg)
      .catch(() => setSvg(''))
  }, [uri])

  return (
    <div className="connect-view">
      <h2 className="t-title m0">Approve in Freighter</h2>
      <p className="t-body-sm m0 connect-lede">
        {onPhone
          ? `Freighter should open with a connection request. If it isn't installed, you'll go to ${freighterStoreName()} to get it.`
          : 'Open Freighter on your phone, tap the scanner, and point it at this code. Then approve the connection on Testnet.'}
      </p>
      {/* On a phone the link opens Freighter directly; the code is for scanning from another device. */}
      {!onPhone && <div className="connect-qr" role="img" aria-label="WalletConnect pairing code" dangerouslySetInnerHTML={{ __html: svg }} />}
      <p className="connect-waiting t-caption m0"><LoaderCircle size={14} className="spin" /> Waiting for approval</p>
      <div className="connect-actions">
        <Button
          label="Copy link"
          icon={<Copy />}
          tone="quiet"
          onClick={async () => {
            try { await navigator.clipboard.writeText(uri); toast('Pairing link copied.') } catch { toast('Copy is unavailable here. Select the text instead.') }
          }}
        />
        {onPhone && <Button label="Open Freighter" icon={<SquareArrowOutUpRight />} onClick={() => openFreighter(uri)} />}
        <Button label="Back" tone="secondary" onClick={wallet.dismissPairing} />
      </div>
    </div>
  )
}

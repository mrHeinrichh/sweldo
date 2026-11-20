import { useEffect, useState } from 'react'
import QRCode from 'qrcode'
import { Copy, QrCode, ShieldCheck, X } from 'lucide-react'
import { useToast } from '../../state/toast'
import { Button, IconButton } from '../../ui/Button'
import { Sheet } from '../../ui/Sheet'
import { AddressGroups } from './ScanWalletSheet'
import './wallet-qr.css'

/**
 * The connected wallet's public address as a QR code, for an employer to scan.
 * Mirrors sweldo_flutter/lib/features/wallet/view/wallet_address_qr.dart.
 */
export function WalletAddressQr({ address, open, onClose }: { address: string; open: boolean; onClose: () => void }) {
  // Kept with the address it encodes, so a changed wallet never shows a stale code.
  const [rendered, setRendered] = useState<{ address: string; url: string } | null>(null)
  const image = rendered?.address === address ? rendered.url : ''
  const toast = useToast()
  useEffect(() => {
    if (!open) return
    let cancelled = false
    void QRCode.toDataURL(address, { width: 720, margin: 2, errorCorrectionLevel: 'M', color: { dark: '#14213A', light: '#FFFFFF' } })
      .then((url) => { if (!cancelled) setRendered({ address, url }) }).catch(() => { if (!cancelled) toast('The QR code could not be created. Copy your address instead.', { isError: true }) })
    return () => { cancelled = true }
  }, [address, open, toast])
  return <Sheet open={open} onClose={onClose} label="My wallet QR code" maxWidth={440}>
    <div className="wallet-qr-content">
      <div className="wallet-qr-heading"><h2 className="t-title m0">My wallet QR code</h2><IconButton icon={<X />} label="Close wallet QR code" onClick={onClose} /></div>
      <p className="t-body-sm m0">Show this to your employer. They scan it to add your wallet to payroll.</p>
      <div className="wallet-address-card">
        {image
          ? <img className="wallet-address-qr" src={image} alt="QR code of your Stellar public wallet address" />
          : <span className="wallet-address-pending" role="status"><QrCode size={40} strokeWidth={1.4} /><span className="sr-only">Creating your wallet QR code…</span></span>}
      </div>
      <AddressGroups address={address} />
      <div className="wallet-qr-actions">
        <Button label="Copy wallet address" icon={<Copy />} expand tone="secondary" onClick={async () => {
          try { await navigator.clipboard.writeText(address); toast('Wallet address copied.') } catch { toast('Select your address above to copy it.') }
        }} />
      </div>
      <p className="wallet-qr-privacy t-caption m0"><ShieldCheck size={14} aria-hidden /> This QR shares your public address only. It can’t connect to your wallet or move money.</p>
    </div>
  </Sheet>
}

/** Opens [WalletAddressQr] from a wallet summary. */
export function WalletQrButton({ onClick, label = 'My wallet QR' }: { onClick: () => void; label?: string }) {
  return <button type="button" className="wallet-qr-open" onClick={onClick}><QrCode size={15} aria-hidden /> {label}</button>
}

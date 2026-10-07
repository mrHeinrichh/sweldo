import { useEffect, useRef, useState } from 'react'
import { ArrowUpRight, ChevronDown, Copy, LogOut, Wallet } from 'lucide-react'
import { explorer } from '../../state/config'
import { useToast } from '../../state/toast'
import { useWallet } from '../../state/wallet'
import { Button } from '../../ui/Button'
import { shortKey } from '../../ui/format'
import { useWide } from '../../ui/hooks'
import './wallet.css'

/** Connect / connected-account control in the top bar. */
export function WalletButton() {
  const wallet = useWallet()
  const toast = useToast()
  const compact = !useWide()
  const [menuOpen, setMenuOpen] = useState(false)
  const root = useRef<HTMLDivElement>(null)
  const session = wallet.session

  useEffect(() => {
    if (!menuOpen) return
    const close = (event: MouseEvent) => { if (!root.current?.contains(event.target as Node)) setMenuOpen(false) }
    const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape') setMenuOpen(false) }
    document.addEventListener('mousedown', close)
    window.addEventListener('keydown', onKey)
    return () => { document.removeEventListener('mousedown', close); window.removeEventListener('keydown', onKey) }
  }, [menuOpen])

  if (!session) {
    return (
      <div className="wallet-button-swap" key="connect">
        <Button
          label={wallet.status === 'restoring' ? 'Checking…' : compact ? 'Connect' : 'Connect wallet'}
          icon={<Wallet />}
          tone="secondary"
          loading={wallet.isBusy}
          onClick={wallet.openSheet}
        />
      </div>
    )
  }

  return (
    <div className="wallet-button-swap wallet-menu-root" key={session.address} ref={root}>
      <button
        type="button"
        className={`wallet-chip ${session.onTestnet ? '' : 'wrong'}`}
        aria-haspopup="menu"
        aria-expanded={menuOpen}
        title="Wallet options"
        onClick={() => setMenuOpen((open) => !open)}
      >
        <span className="wallet-chip-dot" />
        <span className="t-mono">{shortKey(session.address, 4)}</span>
        <ChevronDown size={18} />
      </button>
      {menuOpen && (
        <div className="wallet-menu" role="menu">
          <button type="button" role="menuitem" onClick={async () => {
            setMenuOpen(false)
            try { await navigator.clipboard.writeText(session.address); toast('Address copied.') } catch { toast('Copy is unavailable here. Select the text instead.') }
          }}><Copy size={18} /> Copy address</button>
          <a role="menuitem" href={explorer.account(session.address)} target="_blank" rel="noreferrer" onClick={() => setMenuOpen(false)}>
            <ArrowUpRight size={18} /> View on Stellar Expert
          </a>
          <button type="button" role="menuitem" onClick={() => { setMenuOpen(false); wallet.disconnect() }}><LogOut size={18} /> Disconnect</button>
        </div>
      )}
    </div>
  )
}

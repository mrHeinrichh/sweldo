import { useEffect, useRef, type ReactNode } from 'react'
import { Compass, TriangleAlert } from 'lucide-react'
import { useTour } from '../features/tour/tour'
import { ConnectWalletSheet } from '../features/wallet/ConnectWalletSheet'
import { WalletButton } from '../features/wallet/WalletButton'
import { config, explorer, hasRegistry } from '../state/config'
import { useWallet } from '../state/wallet'
import { ExternalLink } from '../ui/ExternalLink'
import { shortKey } from '../ui/format'
import { useUp, useWide } from '../ui/hooks'
import { ContentWidth } from '../ui/Layout'
import { SweldoLogo } from '../ui/Logo'
import { PingDot } from '../ui/Motion'
import { Collapse } from '../ui/Notice'
import { navigate, routeFor, ROUTES, useLocation } from './router'
import './shell.css'

/** Frame shared by every destination: top bar, network warning, navigation. */
export function Shell({ children }: { children: ReactNode }) {
  const path = useLocation()
  const wide = useWide()
  const sm = useUp('sm')
  const current = routeFor(path)
  const scroller = useRef<HTMLElement>(null)

  // Each destination starts at its top, as each Flutter page has its own scroll.
  useEffect(() => { scroller.current?.scrollTo({ top: 0 }) }, [path])

  return (
    <div className="shell">
      <header className="top-bar">
        <ContentWidth className="top-bar-row">
          <SweldoLogo onClick={() => navigate('/')} />
          {wide && (
            <nav className="top-nav" aria-label="Main">
              {ROUTES.map((route) => {
                const Icon = route.icon
                const selected = route === current
                return (
                  <a
                    key={route.path}
                    href={`#${route.path}`}
                    className={`top-nav-item ${selected ? 'selected' : ''}`}
                    aria-current={selected ? 'page' : undefined}
                  >
                    <span className="top-nav-pill"><Icon size={17} /><span>{route.label}</span></span>
                    <span className="top-nav-underline" aria-hidden />
                  </a>
                )
              })}
            </nav>
          )}
          <span className="top-bar-spacer" />
          <NetworkChip compact={!sm} />
          <GuideButton compact={!wide} />
          <span data-tour="connect" className="top-bar-wallet"><WalletButton /></span>
        </ContentWidth>
      </header>
      <WrongNetworkBanner />
      <main className="shell-main" ref={scroller}>
        <div className="page-transition" key={path}>{children}</div>
      </main>
      {!wide && <BottomNav currentPath={current.path} />}
      <ConnectWalletSheet />
    </div>
  )
}

/** "Testnet" with a live dot; just the dot on phones, where the bar is tight. */
function NetworkChip({ compact }: { compact: boolean }) {
  return (
    <span className={`network-chip ${compact ? 'compact' : ''}`} title="Sweldo uses Stellar Testnet. Test money has no real value." aria-label={compact ? 'Testnet' : undefined}>
      <PingDot size={7} />
      {!compact && 'Testnet'}
    </span>
  )
}

function GuideButton({ compact }: { compact: boolean }) {
  const tour = useTour()
  return (
    <button type="button" className={`guide-button sw-interactive ${compact ? 'compact' : ''}`} onClick={tour.start} title="Show me around" aria-label="Open the guide">
      <Compass size={16} />
      {!compact && <span>Guide</span>}
    </button>
  )
}

function WrongNetworkBanner() {
  const { session } = useWallet()
  const show = !!session && !session.onTestnet
  return (
    <Collapse open={show}>
      <div className="wrong-network">
        <ContentWidth className="wrong-network-row">
          <TriangleAlert size={18} />
          <p className="t-body-sm t-ink m0">
            Freighter is on {session?.network ? session.network : 'another network'}. Switch it to Testnet before signing, then reconnect.
          </p>
        </ContentWidth>
      </div>
    </Collapse>
  )
}

function BottomNav({ currentPath }: { currentPath: string }) {
  return (
    <nav className="bottom-nav" aria-label="Main">
      {ROUTES.map((route) => {
        const Icon = route.icon
        const selected = route.path === currentPath
        return (
          <a key={route.path} href={`#${route.path}`} className={`bottom-nav-item ${selected ? 'selected' : ''}`} aria-current={selected ? 'page' : undefined}>
            <span className="bottom-nav-indicator"><Icon size={24} /></span>
            <span className="bottom-nav-label">{route.label}</span>
          </a>
        )
      })}
    </nav>
  )
}

/** A scrolling destination with an optional page title and the footer. */
export function PageFrame({ title, description, children }: { title?: string; description?: string; children: ReactNode }) {
  return (
    <div className="page-frame">
      <ContentWidth className="page-frame-body">
        {title && (
          <header className="page-frame-header">
            <h1 className="page-title m0">{title}</h1>
            {description && <p className="t-body t-muted m0 page-description">{description}</p>}
          </header>
        )}
        {children}
      </ContentWidth>
      <Footer />
    </div>
  )
}

function Footer() {
  const row = useRef<HTMLDivElement>(null)
  useCenteredRuns(row)
  return (
    <footer className="footer">
      <ContentWidth className="footer-row" ref={row}>
        <SweldoLogo compact />
        <span className="t-body-sm">Payroll that keeps its promise. Built on Stellar Testnet.</span>
        <ExternalLink href={explorer.home} label="Stellar Expert" className="footer-link" />
        {hasRegistry && (
          <ExternalLink href={explorer.contract(config.registryContractId)} label={`Payroll registry ${shortKey(config.registryContractId, 4)}`} className="footer-link" />
        )}
      </ContentWidth>
    </footer>
  )
}

/**
 * Flutter's Wrap sizes itself to its widest run and Align centers it; CSS
 * flex-wrap fills the line instead. Measure the runs and offset to match.
 */
function useCenteredRuns(ref: React.RefObject<HTMLDivElement | null>) {
  useEffect(() => {
    const node = ref.current
    if (!node) return
    const measure = () => {
      node.style.paddingLeft = ''
      node.style.paddingRight = ''
      const style = getComputedStyle(node)
      const inner = node.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
      // Items in one run share a vertical centre (align-items: center).
      const runs: { center: number; left: number; right: number }[] = []
      for (const child of Array.from(node.children)) {
        const rect = child.getBoundingClientRect()
        const center = rect.top + rect.height / 2
        const run = runs.find((item) => Math.abs(item.center - center) < 4)
        if (run) { run.left = Math.min(run.left, rect.left); run.right = Math.max(run.right, rect.right) }
        else runs.push({ center, left: rect.left, right: rect.right })
      }
      const widest = Math.max(...runs.map((run) => run.right - run.left))
      const offset = Math.max(0, (inner - widest) / 2)
      node.style.paddingLeft = `calc(${style.paddingLeft} + ${offset}px)`
      node.style.paddingRight = `max(0px, calc(${style.paddingRight} - ${offset}px))`
    }
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(node.parentElement ?? node)
    document.fonts?.ready.then(measure)
    return () => observer.disconnect()
  }, [ref])
}

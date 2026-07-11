import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  ArrowRight,
  BadgeCheck,
  Banknote,
  Check,
  ChevronDown,
  CircleDollarSign,
  Clock3,
  Copy,
  ExternalLink,
  Landmark,
  LoaderCircle,
  LockKeyhole,
  Menu,
  Plus,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  Wallet,
  X,
  Zap,
} from 'lucide-react'
import {
  addTrustline,
  assetLabel,
  claimBalance,
  configuredAsset,
  connectWallet,
  createSchedule,
  friendlyError,
  getClaimableBalances,
  getXlmBalance,
  parseUnlockTime,
  type BalanceRecord,
  type WalletState,
} from './lib/stellar'
import './App.css'

type View = 'home' | 'employer' | 'employee'
type ScheduleMeta = {
  id: string
  employee: string
  name: string
  total: string
  tranches: number
  asset: string
  createdAt: string
  hash: string
}

const ASSET = configuredAsset()
const ASSET_LABEL = assetLabel(ASSET)
const META_KEY = 'sweldo-schedules-v1'

function short(value: string, edge = 5) {
  return `${value.slice(0, edge)}…${value.slice(-edge)}`
}

function formatAmount(value: string | number) {
  return new Intl.NumberFormat('en-US', { maximumFractionDigits: 7 }).format(Number(value))
}

function readSchedules(): ScheduleMeta[] {
  try {
    return JSON.parse(localStorage.getItem(META_KEY) ?? '[]') as ScheduleMeta[]
  } catch {
    return []
  }
}

function saveSchedule(schedule: ScheduleMeta) {
  localStorage.setItem(META_KEY, JSON.stringify([schedule, ...readSchedules()]))
}

function useCountdown(target: Date | null) {
  const [now, setNow] = useState(Date.now())
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(timer)
  }, [])
  if (!target) return { unlocked: true, label: 'Available now' }
  const seconds = Math.max(0, Math.ceil((target.getTime() - now) / 1000))
  if (seconds <= 0) return { unlocked: true, label: 'Available now' }
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = seconds % 60
  const label = days > 0 ? `${days}d ${hours}h` : hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m ${secs}s`
  return { unlocked: false, label }
}

function Button({
  children,
  className = '',
  loading = false,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { loading?: boolean }) {
  return (
    <button className={`button ${className}`} {...props} disabled={props.disabled || loading}>
      {loading && <LoaderCircle size={17} className="spin" />}
      {children}
    </button>
  )
}

function Logo({ onClick }: { onClick: () => void }) {
  return (
    <button className="logo" onClick={onClick} aria-label="Go home">
      <span className="logo-mark"><Banknote size={22} /></span>
      <span>sweldo<span className="logo-dot">.</span></span>
    </button>
  )
}

function WalletButton({ wallet, onConnect, busy }: { wallet: WalletState | null; onConnect: () => void; busy: boolean }) {
  return (
    <Button className={wallet ? 'wallet-connected' : 'button-dark'} onClick={onConnect} loading={busy}>
      {wallet ? <><span className="live-dot" />{short(wallet.address, 4)}<ChevronDown size={15} /></> : <><Wallet size={17} /> Connect wallet</>}
    </Button>
  )
}

function Header({ wallet, connect, busy, go, view }: { wallet: WalletState | null; connect: () => void; busy: boolean; go: (v: View) => void; view: View }) {
  const [open, setOpen] = useState(false)
  return (
    <header>
      <div className="nav-shell">
        <Logo onClick={() => go('home')} />
        <nav className={open ? 'open' : ''}>
          <button className={view === 'employer' ? 'active' : ''} onClick={() => { go('employer'); setOpen(false) }}>For employers</button>
          <button className={view === 'employee' ? 'active' : ''} onClick={() => { go('employee'); setOpen(false) }}>For employees</button>
          <a href="#how-it-works" onClick={() => setOpen(false)}>How it works</a>
          <a href="https://stellar.expert/explorer/testnet" target="_blank" rel="noreferrer">Explorer <ExternalLink size={13} /></a>
        </nav>
        <div className="nav-actions">
          <span className="network-pill"><span /> Testnet</span>
          <WalletButton wallet={wallet} onConnect={connect} busy={busy} />
          <button className="menu-button" onClick={() => setOpen(!open)}>{open ? <X /> : <Menu />}</button>
        </div>
      </div>
    </header>
  )
}

function Home({ go }: { go: (view: View) => void }) {
  return (
    <main>
      <section className="hero-section">
        <div className="hero-glow" />
        <div className="hero-copy">
          <div className="eyebrow"><Sparkles size={14} /> Payroll, secured by Stellar</div>
          <h1>Payday should be<br /><span>promised in code.</span></h1>
          <p>Lock salaries on-chain. Let your team claim the moment they unlock. No chasing, no custody, no borders.</p>
          <div className="hero-actions">
            <Button className="button-primary button-large" onClick={() => go('employer')}>Create a payroll <ArrowRight size={18} /></Button>
            <Button className="button-ghost button-large" onClick={() => go('employee')}><Wallet size={18} /> View my pay</Button>
          </div>
          <div className="trust-row">
            <span><Check size={14} /> Non-custodial</span>
            <span><Check size={14} /> Protocol-native</span>
            <span><Check size={14} /> Near-zero fees</span>
          </div>
        </div>
        <div className="pay-card-wrap">
          <div className="float-chip chip-one"><ShieldCheck size={17} /> Funds secured</div>
          <div className="float-chip chip-two"><Zap size={17} /> Instant claim</div>
          <div className="pay-card">
            <div className="pay-card-top"><span>YOUR PAY</span><span className="secured"><span /> Secured</span></div>
            <div className="pay-total"><small>Total vested</small><strong>2,400.00 <span>{ASSET_LABEL}</span></strong></div>
            <div className="progress-head"><span>8 of 12 tranches</span><span>66.7%</span></div>
            <div className="progress"><i /></div>
            <div className="next-pay">
              <div className="calendar-icon"><span>JUL</span><b>15</b></div>
              <div><small>Next unlock</small><strong>300.00 {ASSET_LABEL}</strong><span>in 3 days, 14 hours</span></div>
              <div className="lock-circle"><LockKeyhole size={17} /></div>
            </div>
            <Button className="mock-claim" disabled><Clock3 size={17} /> Unlocks automatically</Button>
            <div className="stellar-note"><CircleDollarSign size={16} /> Powered by Stellar claimable balances</div>
          </div>
        </div>
      </section>

      <section className="proof-strip">
        <div><strong>$0</strong><span>platform fees</span></div>
        <i />
        <div><strong>~5s</strong><span>settlement time</span></div>
        <i />
        <div><strong>24/7</strong><span>global access</span></div>
        <i />
        <div><strong>100%</strong><span>non-custodial</span></div>
      </section>

      <section className="how" id="how-it-works">
        <div className="section-label">BUILT DIFFERENT</div>
        <h2>Payroll that keeps its promise.</h2>
        <p className="section-sub">One signature locks every payday. Stellar handles the rest.</p>
        <div className="step-grid">
          <article><span className="step-num">01</span><div className="step-icon violet"><Landmark /></div><h3>Set the schedule</h3><p>Add an employee, choose the amount and cadence. Monthly, weekly, or demo-fast.</p></article>
          <article><span className="step-num">02</span><div className="step-icon amber"><LockKeyhole /></div><h3>Lock it on-chain</h3><p>Sign once. Every tranche becomes a time-locked claimable balance on Stellar.</p></article>
          <article><span className="step-num">03</span><div className="step-icon green"><BadgeCheck /></div><h3>Claim on time</h3><p>Employees claim directly to their wallet the second a tranche unlocks.</p></article>
        </div>
      </section>
    </main>
  )
}

function DashboardShell({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return <main className="dashboard"><div className="dash-head"><div><h1>{title}</h1><p>{subtitle}</p></div><span className="network-banner"><span /> Stellar Testnet</span></div>{children}</main>
}

function Employer({ wallet, connect }: { wallet: WalletState | null; connect: () => void }) {
  const [name, setName] = useState('')
  const [employee, setEmployee] = useState('')
  const [total, setTotal] = useState('1200')
  const [tranches, setTranches] = useState(4)
  const [interval, setInterval] = useState('minute')
  const [firstDelay, setFirstDelay] = useState(1)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<{ type: 'success' | 'error'; text: string; hash?: string } | null>(null)
  const [schedules, setSchedules] = useState(readSchedules)
  const amountEach = Number(total) > 0 && tranches > 0 ? (Number(total) / tranches).toFixed(7).replace(/\.?0+$/, '') : '0'

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (!wallet) return connect()
    if (wallet.network !== 'TESTNET') return setNotice({ type: 'error', text: 'Switch Freighter to Testnet, then reconnect.' })
    if (!employee.startsWith('G') || employee.length !== 56) return setNotice({ type: 'error', text: 'Enter a valid 56-character Stellar public key.' })
    if (!(Number(total) > 0) || tranches < 1 || tranches > 50) return setNotice({ type: 'error', text: 'Use a positive amount and 1–50 tranches.' })
    const seconds = interval === 'minute' ? 60 : interval === 'day' ? 86400 : interval === 'week' ? 604800 : 2592000
    setBusy(true)
    setNotice(null)
    try {
      const result = await createSchedule({ employer: wallet.address, employee, amountPerTranche: amountEach, tranches, firstUnlock: new Date(Date.now() + firstDelay * seconds * 1000), intervalSeconds: seconds, asset: ASSET })
      const meta: ScheduleMeta = { id: crypto.randomUUID(), employee, name: name || 'Team member', total, tranches, asset: ASSET_LABEL, createdAt: new Date().toISOString(), hash: result.hash }
      saveSchedule(meta)
      setSchedules(readSchedules())
      setNotice({ type: 'success', text: `${tranches} pay tranches are now locked on Stellar.`, hash: result.hash })
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <DashboardShell title="Employer workspace" subtitle="Create payroll schedules that settle themselves.">
      <div className="dashboard-grid">
        <form className="panel form-panel" onSubmit={submit}>
          <div className="panel-title"><div><h2>New payroll schedule</h2><p>One transaction creates every time-locked payment.</p></div><span><Plus size={16} /></span></div>
          {notice && <div className={`notice ${notice.type}`}>{notice.type === 'success' ? <Check size={18} /> : <X size={18} />}<div>{notice.text}{notice.hash && <a href={`https://stellar.expert/explorer/testnet/tx/${notice.hash}`} target="_blank" rel="noreferrer">View transaction <ExternalLink size={13} /></a>}</div></div>}
          <label>Employee name <span>optional</span><input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Ana Santos" /></label>
          <label>Employee wallet address<input className="mono" value={employee} onChange={(e) => setEmployee(e.target.value.trim())} placeholder="G..." /></label>
          <div className="field-row">
            <label>Total payroll amount<div className="input-suffix"><input inputMode="decimal" value={total} onChange={(e) => setTotal(e.target.value)} /><b>{ASSET_LABEL}</b></div></label>
            <label>Number of tranches<input type="number" min="1" max="50" value={tranches} onChange={(e) => setTranches(Number(e.target.value))} /></label>
          </div>
          <div className="field-row">
            <label>Pay cadence<select value={interval} onChange={(e) => setInterval(e.target.value)}><option value="minute">Every minute (demo)</option><option value="day">Daily</option><option value="week">Weekly</option><option value="month">Monthly</option></select></label>
            <label>First unlock <span>intervals from now</span><input type="number" min="0" value={firstDelay} onChange={(e) => setFirstDelay(Number(e.target.value))} /></label>
          </div>
          <div className="schedule-summary"><span><Clock3 size={17} /> {tranches} payments of <strong>{amountEach} {ASSET_LABEL}</strong></span><span>Total locked <strong>{formatAmount(total)} {ASSET_LABEL}</strong></span></div>
          <Button className="button-primary full" type="submit" loading={busy}><LockKeyhole size={17} /> {wallet ? 'Lock payroll on Stellar' : 'Connect wallet to continue'}</Button>
          <p className="fine-print"><ShieldCheck size={14} /> Funds go straight from your wallet into protocol-level claimable balances.</p>
        </form>
        <aside className="panel side-panel">
          <div className="panel-title"><div><h2>Recent schedules</h2><p>Saved locally on this device.</p></div></div>
          {schedules.length === 0 ? <div className="empty"><div><Banknote /></div><h3>No schedules yet</h3><p>Your funded payrolls will appear here.</p></div> : <div className="schedule-list">{schedules.map((schedule) => <article key={schedule.id}><div className="avatar">{schedule.name.slice(0, 1).toUpperCase()}</div><div><strong>{schedule.name}</strong><span>{short(schedule.employee)}</span><small>{schedule.tranches} × {formatAmount(Number(schedule.total) / schedule.tranches)} {schedule.asset}</small></div><a href={`https://stellar.expert/explorer/testnet/tx/${schedule.hash}`} target="_blank" rel="noreferrer"><ExternalLink size={16} /></a></article>)}</div>}
          <div className="info-card"><Sparkles size={18} /><div><strong>Demo tip</strong><p>Choose “every minute” so judges can watch a tranche unlock live.</p></div></div>
        </aside>
      </div>
    </DashboardShell>
  )
}

function BalanceCard({ record, onClaim, claiming }: { record: BalanceRecord; onClaim: (id: string) => void; claiming: boolean }) {
  const unlockAt = parseUnlockTime(record.claimants[0]?.predicate ?? {})
  const countdown = useCountdown(unlockAt)
  return (
    <article className={`balance-card ${countdown.unlocked ? 'unlocked' : ''}`}>
      <div className="status-icon">{countdown.unlocked ? <BadgeCheck /> : <LockKeyhole />}</div>
      <div className="balance-main"><span className="status-label">{countdown.unlocked ? 'READY TO CLAIM' : 'LOCKED'}</span><strong>{formatAmount(record.amount)} <small>{record.asset === 'native' ? 'XLM' : record.asset.split(':')[0]}</small></strong><span className="unlock-date">{unlockAt ? (countdown.unlocked ? `Unlocked ${unlockAt.toLocaleString()}` : `Unlocks ${unlockAt.toLocaleString()}`) : 'Available unconditionally'}</span></div>
      <div className="balance-action">{countdown.unlocked ? <Button className="button-primary" onClick={() => onClaim(record.balance_id)} loading={claiming}>Claim now <ArrowRight size={16} /></Button> : <div className="countdown"><Clock3 size={15} /><span>{countdown.label}</span></div>}<a href={`https://stellar.expert/explorer/testnet/claimable-balance/${record.balance_id}`} target="_blank" rel="noreferrer">View on-chain <ExternalLink size={12} /></a></div>
    </article>
  )
}

function Employee({ wallet, connect }: { wallet: WalletState | null; connect: () => void }) {
  const [records, setRecords] = useState<BalanceRecord[]>([])
  const [busy, setBusy] = useState(false)
  const [claiming, setClaiming] = useState('')
  const [notice, setNotice] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  const refresh = useCallback(async () => {
    if (!wallet) return
    setBusy(true)
    try {
      setRecords(await getClaimableBalances(wallet.address))
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setBusy(false)
    }
  }, [wallet])

  useEffect(() => { void refresh() }, [refresh])
  const totals = useMemo(() => records.reduce((sum, record) => sum + Number(record.amount), 0), [records])

  async function claim(id: string) {
    if (!wallet) return connect()
    setClaiming(id)
    try {
      await claimBalance(wallet.address, id)
      setNotice({ type: 'success', text: 'Pay claimed successfully. It is now in your wallet.' })
      await refresh()
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setClaiming('')
    }
  }

  async function trust() {
    if (!wallet) return connect()
    setBusy(true)
    try {
      await addTrustline(wallet.address, ASSET)
      setNotice({ type: 'success', text: `${ASSET_LABEL} is now enabled in your wallet.` })
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <DashboardShell title="My pay" subtitle="Your on-chain salary, unlocked on schedule.">
      {!wallet ? <div className="connect-state panel"><div className="wallet-orbit"><Wallet /></div><h2>Connect to see your pay</h2><p>Use the Freighter wallet that your employer added to the payroll schedule.</p><Button className="button-primary button-large" onClick={connect}><Wallet size={18} /> Connect Freighter</Button></div> : <>
        <div className="wallet-overview panel"><div><span>CONNECTED WALLET</span><strong>{short(wallet.address, 8)}</strong><button onClick={() => navigator.clipboard.writeText(wallet.address)}><Copy size={14} /> Copy</button></div><div className="overview-stat"><span>LOCKED & CLAIMABLE</span><strong>{formatAmount(totals)} <small>{records[0]?.asset === 'native' || !records[0] ? ASSET_LABEL : records[0].asset.split(':')[0]}</small></strong></div><div className="overview-stat"><span>ACTIVE TRANCHES</span><strong>{records.length}</strong></div><Button className="refresh-button" onClick={refresh} loading={busy}><RefreshCw size={17} /></Button></div>
        {notice && <div className={`notice wide ${notice.type}`}>{notice.type === 'success' ? <Check size={18} /> : <X size={18} />} {notice.text}</div>}
        {!ASSET.isNative() && <div className="trustline-card"><div><CircleDollarSign /><span><strong>New to {ASSET_LABEL}?</strong><small>Add a trustline before claiming this issued asset.</small></span></div><Button className="button-ghost" onClick={trust} loading={busy}>Enable {ASSET_LABEL}</Button></div>}
        <div className="timeline-head"><div><h2>Vesting timeline</h2><p>Claimable balances addressed to your wallet.</p></div><span>{records.length} active</span></div>
        {busy && records.length === 0 ? <div className="loading-state"><LoaderCircle className="spin" /><span>Reading Stellar ledger…</span></div> : records.length === 0 ? <div className="empty large panel"><div><Clock3 /></div><h3>No active pay found</h3><p>Ask your employer to create a schedule for <span className="mono">{short(wallet.address, 8)}</span>, then refresh.</p><Button className="button-ghost" onClick={refresh}><RefreshCw size={16} /> Refresh ledger</Button></div> : <div className="balance-list">{records.map((record) => <BalanceCard key={record.balance_id} record={record} onClaim={claim} claiming={claiming === record.balance_id} />)}</div>}
      </>}
    </DashboardShell>
  )
}

function App() {
  const [view, setView] = useState<View>('home')
  const [wallet, setWallet] = useState<WalletState | null>(null)
  const [connecting, setConnecting] = useState(false)
  const [toast, setToast] = useState('')

  async function connect() {
    setConnecting(true)
    try {
      const next = await connectWallet()
      setWallet(next)
      const balance = await getXlmBalance(next.address)
      setToast(`Connected · ${formatAmount(balance)} XLM`)
      window.setTimeout(() => setToast(''), 3500)
    } catch (error) {
      setToast(friendlyError(error))
    } finally {
      setConnecting(false)
    }
  }

  function go(next: View) {
    setView(next)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return (
    <div className="app">
      <Header wallet={wallet} connect={connect} busy={connecting} go={go} view={view} />
      {toast && <div className="toast">{toast}{toast.includes('Freighter is not available') && <a href="https://www.freighter.app/" target="_blank" rel="noreferrer">Get Freighter <ExternalLink size={12} /></a>}</div>}
      {wallet && wallet.network !== 'TESTNET' && <div className="wrong-network">Freighter is on {wallet.network}. Switch it to <strong>Testnet</strong> before signing.</div>}
      {view === 'home' && <Home go={go} />}
      {view === 'employer' && <Employer wallet={wallet} connect={connect} />}
      {view === 'employee' && <Employee wallet={wallet} connect={connect} />}
      <footer><Logo onClick={() => go('home')} /><p>Payroll that keeps its promise. Built on Stellar Testnet.</p><a href="https://stellar.org" target="_blank" rel="noreferrer">Built on Stellar <ExternalLink size={13} /></a></footer>
    </div>
  )
}

export default App

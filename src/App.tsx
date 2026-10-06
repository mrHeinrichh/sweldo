import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  ArrowRight,
  BadgeCheck,
  Banknote,
  Check,
  ChevronDown,
  Compass,
  CircleDollarSign,
  Clock3,
  Copy,
  Dices,
  ExternalLink,
  Landmark,
  LoaderCircle,
  LockKeyhole,
  Menu,
  Plus,
  RefreshCw,
  RotateCcw,
  ShieldCheck,
  Sparkles,
  Users,
  Wallet,
  X,
  Zap,
} from 'lucide-react'
import {
  addTrustline,
  assetLabel,
  cancelBalances,
  claimBalance,
  configuredAsset,
  createBatchSchedule,
  friendlyError,
  getClaimHistory,
  getClaimableBalances,
  getXlmBalance,
  getBalances,
  fundWithFriendbot,
  hasTrustline,
  isAccountFunded,
  parseUnlockTime,
  recordScheduleProof,
  registryContractId,
  type BalanceRecord,
  type ClaimHistoryRecord,
  type WalletBalances,
  type WalletState,
} from './lib/stellar'
import './App.css'
import { ClaimConversionDialog, ClaimConversionReceipt } from './components/ClaimConversion'
import { configuredConversion, supportsConversion, type ConversionReceipt } from './lib/claim-convert'
import { PayScheduleBuilder, type SchedulePatch } from './components/PayScheduleBuilder'
import { CADENCES, firstPayday, rollSample, type Cadence } from './lib/schedule'
import { ApprovalPrompt, ConnectWalletModal } from './components/ConnectWalletModal'
import { GuidedTour, type TourStep } from './components/GuidedTour'
import { disconnect as disconnectWallet, onPendingApproval, onWalletDisconnected, restore as restoreWallet } from './lib/wallets'

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
  employer?: string
  balanceIds?: string[]
  firstUnlock?: string
  intervalSeconds?: number
  revocable?: boolean
  cancelledAt?: string
  cancelHash?: string
  cancelledPayouts?: number
  registryHash?: string
  registryContractId?: string
}
type PayrollRecipient = {
  id: string
  name: string
  employee: string
  total: string
}
type PayrollProof = {
  hash: string
  total: string
  balanceCount: number
  employeeCount: number
  payouts: number
  firstUnlock: string
  asset: string
  registryHash?: string
  registryContractId?: string
}

const ASSET = configuredAsset()
const ASSET_LABEL = assetLabel(ASSET)
const CONVERSION_PAIR = configuredConversion(import.meta.env)
const META_KEY = 'sweldo-schedules-v1'
const CLAIM_HISTORY_KEY = 'sweldo-claim-history-v1'

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

function saveSchedules(schedules: ScheduleMeta[]) {
  localStorage.setItem(META_KEY, JSON.stringify([...schedules, ...readSchedules()]))
}

function writeSchedules(schedules: ScheduleMeta[]) {
  localStorage.setItem(META_KEY, JSON.stringify(schedules))
}

function createPayrollRecipient(total = '1200'): PayrollRecipient {
  return { id: crypto.randomUUID(), name: '', employee: '', total }
}

function claimHistoryKey(address: string) {
  return `${CLAIM_HISTORY_KEY}:${address}`
}

function readLocalClaimHistory(address: string): ClaimHistoryRecord[] {
  try {
    return JSON.parse(localStorage.getItem(claimHistoryKey(address)) ?? '[]') as ClaimHistoryRecord[]
  } catch {
    return []
  }
}

function mergeClaimHistory(local: ClaimHistoryRecord[], onChain: ClaimHistoryRecord[]) {
  const byProof = new Map<string, ClaimHistoryRecord>()
  for (const record of [...local, ...onChain]) {
    const key = record.transactionHash ? `tx:${record.transactionHash}` : `balance:${record.balanceId}`
    const previous = byProof.get(key)
    byProof.set(key, {
      ...record,
      amount: previous?.amount ?? record.amount,
      asset: previous?.asset ?? record.asset,
      source: previous?.source === 'local' ? previous.source : record.source,
    })
  }
  return [...byProof.values()].sort((a, b) => new Date(b.claimedAt).getTime() - new Date(a.claimedAt).getTime())
}

function saveClaimHistory(address: string, claim: ClaimHistoryRecord) {
  const next = mergeClaimHistory([claim, ...readLocalClaimHistory(address)], [])
  localStorage.setItem(claimHistoryKey(address), JSON.stringify(next.slice(0, 50)))
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
    <Button className={wallet ? 'wallet-connected' : 'button-dark'} onClick={onConnect} loading={busy} data-tour="connect">
      {wallet ? <><span className="live-dot" />{short(wallet.address, 4)}<ChevronDown size={15} /></> : <><Wallet size={17} /> Connect wallet</>}
    </Button>
  )
}

function Header({ wallet, connect, busy, go, view, onGuide }: { wallet: WalletState | null; connect: () => void; busy: boolean; go: (v: View) => void; view: View; onGuide: () => void }) {
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
          <button type="button" className="tour-launch" onClick={onGuide} aria-label="Open the guide"><Compass size={14} /><span>Guide</span></button>
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
          <div className="hero-actions" data-tour="hero-actions">
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
            <div className="progress-head"><span>8 of 12 payouts (tranches)</span><span>66.7%</span></div>
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
          <article><span className="step-num">02</span><div className="step-icon amber"><LockKeyhole /></div><h3>Lock it on-chain</h3><p>Sign once. Every payout (tranche) becomes a time-locked claimable balance on Stellar.</p></article>
          <article><span className="step-num">03</span><div className="step-icon green"><BadgeCheck /></div><h3>Claim on time</h3><p>Employees claim directly to their wallet the second a payout (tranche) unlocks.</p></article>
        </div>
      </section>
    </main>
  )
}

function DashboardShell({ title, subtitle, children }: { title: string; subtitle: string; children: React.ReactNode }) {
  return <main className="dashboard"><div className="dash-head"><div><h1>{title}</h1><p>{subtitle}</p></div><span className="network-banner"><span /> Stellar Testnet</span></div>{children}</main>
}

function FundCard({ wallet }: { wallet: WalletState | null }) {
  const [empty, setEmpty] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    setEmpty(false)
    if (!wallet || wallet.network !== 'TESTNET') return
    isAccountFunded(wallet.address)
      .then((funded) => { if (!cancelled) setEmpty(!funded) })
      .catch(() => { /* a failed lookup must not block the page */ })
    return () => { cancelled = true }
  }, [wallet])

  async function fund() {
    if (!wallet) return
    setBusy(true)
    setError('')
    try {
      await fundWithFriendbot(wallet.address)
      setEmpty(!(await isAccountFunded(wallet.address)))
    } catch (err) {
      setError(friendlyError(err))
    } finally {
      setBusy(false)
    }
  }

  if (!empty) return null
  return <div className="trustline-card"><div><Wallet /><span><strong>Your practice wallet is empty</strong><small>Get free Testnet money to try Sweldo. It has no real value.</small>{error && <small className="error-text">{error}</small>}</span></div><Button type="button" className="button-primary" onClick={fund} loading={busy}>Get free practice money</Button></div>
}

function TrustlineCard({ wallet, connect, message }: { wallet: WalletState | null; connect: () => void; message: string }) {
  const [needed, setNeeded] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    setNeeded(false)
    if (!wallet || ASSET.isNative()) return
    hasTrustline(wallet.address, ASSET)
      .then((exists) => { if (!cancelled) setNeeded(!exists) })
      .catch(() => { if (!cancelled) setNeeded(true) })
    return () => { cancelled = true }
  }, [wallet])

  async function enable() {
    if (!wallet) return connect()
    setBusy(true)
    setError('')
    try {
      await addTrustline(wallet.address, ASSET)
      setNeeded(!(await hasTrustline(wallet.address, ASSET)))
    } catch (err) {
      setError(friendlyError(err))
    } finally {
      setBusy(false)
    }
  }

  if (!needed) return null
  return <div className="trustline-card"><div><CircleDollarSign /><span><strong>New to {ASSET_LABEL}?</strong><small>{message}</small>{error && <small className="error-text">{error}</small>}</span></div><Button type="button" className="button-ghost" onClick={enable} loading={busy}>Enable {ASSET_LABEL}</Button></div>
}

function Employer({ wallet, connect }: { wallet: WalletState | null; connect: () => void }) {
  // Every visit starts from a random sample; Shuffle rolls a new one.
  const [initialSample] = useState(() => rollSample(1))
  const [recipients, setRecipients] = useState<PayrollRecipient[]>(() => [{ ...createPayrollRecipient(initialSample.totals[0]), name: initialSample.names[0] }])
  const [tranches, setTranches] = useState(initialSample.payouts)
  const [interval, setInterval] = useState<Cadence>(initialSample.cadence)
  const [firstDelay, setFirstDelay] = useState(initialSample.firstDelay)
  const [firstPaydayAt, setFirstPaydayAt] = useState<Date | null>(null)
  const [shuffles, setShuffles] = useState(0)
  const [balances, setBalances] = useState<WalletBalances | null | undefined>(undefined)
  const [schedulesOpen, setSchedulesOpen] = useState(true)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState<{ type: 'success' | 'error'; text: string; hash?: string } | null>(null)
  const [lastProof, setLastProof] = useState<PayrollProof | null>(null)
  const [schedules, setSchedules] = useState(readSchedules)
  const [activeBalanceIds, setActiveBalanceIds] = useState<string[]>([])
  const [balancesLoaded, setBalancesLoaded] = useState(false)
  const [cancelling, setCancelling] = useState('')
  const [now, setNow] = useState(Date.now())
  const totalLocked = recipients.reduce((sum, recipient) => sum + Number(recipient.total || 0), 0)
  const employeeLabel = recipients.length === 1 ? 'employee' : 'employees'
  const amountEach = (total: string) => Number(total) > 0 && tranches > 0 ? (Number(total) / tranches).toFixed(7).replace(/\.?0+$/, '') : '0'
  const activeBalanceSet = useMemo(() => new Set(activeBalanceIds), [activeBalanceIds])

  const refreshWalletBalances = useCallback(async () => {
    if (!wallet?.address || wallet.network !== 'TESTNET') {
      setBalances(undefined)
      return
    }
    try {
      setBalances(await getBalances(wallet.address, ASSET))
    } catch {
      setBalances(undefined)
    }
  }, [wallet?.address, wallet?.network])

  useEffect(() => {
    void refreshWalletBalances()
  }, [refreshWalletBalances])

  /** New sample values for everything except wallet addresses. */
  function shuffle() {
    const sample = rollSample(recipients.length)
    setRecipients((current) => current.map((recipient, index) => ({ ...recipient, name: sample.names[index], total: sample.totals[index] })))
    setTranches(sample.payouts)
    setInterval(sample.cadence)
    setFirstDelay(sample.firstDelay)
    setFirstPaydayAt(null)
    setShuffles((count) => count + 1)
  }

  function changeSchedule(patch: SchedulePatch) {
    if (patch.cadence) setInterval(patch.cadence)
    if (patch.payouts !== undefined) setTranches(patch.payouts)
    if (patch.firstDelay !== undefined) setFirstDelay(patch.firstDelay)
    if (patch.firstPaydayAt !== undefined) setFirstPaydayAt(patch.firstPaydayAt)
  }

  const refreshEmployerBalances = useCallback(async () => {
    if (!wallet?.address) {
      setActiveBalanceIds([])
      setBalancesLoaded(false)
      return
    }
    setBalancesLoaded(false)
    try {
      const records = await getClaimableBalances(wallet.address)
      setActiveBalanceIds(records.map((record) => record.balance_id))
    } catch {
      setActiveBalanceIds([])
    } finally {
      setBalancesLoaded(true)
    }
  }, [wallet?.address])

  useEffect(() => {
    void refreshEmployerBalances()
  }, [refreshEmployerBalances])

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(timer)
  }, [])

  function cancellableIds(schedule: ScheduleMeta, availableIds = activeBalanceSet, at = now) {
    if (!schedule.revocable || !schedule.balanceIds?.length || !schedule.firstUnlock || !schedule.intervalSeconds) return []
    const firstPayday = new Date(schedule.firstUnlock).getTime()
    return schedule.balanceIds.filter((balanceId, index) => (
      availableIds.has(balanceId)
      && firstPayday + index * schedule.intervalSeconds! * 1000 > at
    ))
  }

  function updateRecipient(id: string, patch: Partial<PayrollRecipient>) {
    setRecipients((current) => current.map((recipient) => recipient.id === id ? { ...recipient, ...patch } : recipient))
  }

  function removeRecipient(id: string) {
    setRecipients((current) => current.length === 1 ? current : current.filter((recipient) => recipient.id !== id))
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (!wallet) return connect()
    if (wallet.network !== 'TESTNET') return setNotice({ type: 'error', text: 'Switch Freighter to Testnet, then reconnect.' })
    const payrollRows = recipients.map((recipient) => ({ ...recipient, employee: recipient.employee.trim(), total: recipient.total.trim() }))
    if (payrollRows.some((recipient) => !recipient.employee.startsWith('G') || recipient.employee.length !== 56)) return setNotice({ type: 'error', text: 'Every employee needs a valid 56-character Stellar public key.' })
    if (payrollRows.some((recipient) => !(Number(recipient.total) > 0)) || tranches < 1 || tranches > 50) return setNotice({ type: 'error', text: 'Use positive payroll amounts and 1–50 payouts (tranches).' })
    if (payrollRows.length * tranches > 100) return setNotice({ type: 'error', text: 'This batch is too large for one Stellar transaction. Keep employees × payouts (tranches) at 100 or less.' })
    const seconds = CADENCES[interval].seconds
    const firstUnlock = firstPayday(new Date(), interval, firstDelay, firstPaydayAt)
    setBusy(true)
    setNotice(null)
    try {
      const result = await createBatchSchedule({
        employer: wallet.address,
        recipients: payrollRows.map((recipient) => ({ employee: recipient.employee, amountPerPayout: amountEach(recipient.total) })),
        payouts: tranches,
        firstUnlock,
        intervalSeconds: seconds,
        asset: ASSET,
      })
      const createdAt = new Date().toISOString()
      const createdSchedules: ScheduleMeta[] = payrollRows.map((recipient, index) => ({
        id: crypto.randomUUID(),
        employee: recipient.employee,
        name: recipient.name || 'Team member',
        total: recipient.total,
        tranches,
        asset: ASSET_LABEL,
        createdAt,
        hash: result.hash,
        employer: wallet.address,
        balanceIds: result.balanceIds.slice(index * tranches, (index + 1) * tranches),
        firstUnlock: firstUnlock.toISOString(),
        intervalSeconds: seconds,
        revocable: true,
      }))
      const firstSchedule = createdSchedules[0]
      let registryProof: Awaited<ReturnType<typeof recordScheduleProof>> = null
      let registryWarning = ''
      if (firstSchedule?.balanceIds?.[0]) {
        try {
          registryProof = await recordScheduleProof({
            employer: wallet.address,
            employee: firstSchedule.employee,
            total: firstSchedule.total,
            asset: ASSET_LABEL,
            cadenceSeconds: seconds,
            claimableBalanceId: firstSchedule.balanceIds[0],
            payoutTxHash: result.hash,
          })
          if (registryProof) {
            firstSchedule.registryHash = registryProof.hash
            firstSchedule.registryContractId = registryProof.contractId
          }
        } catch (registryError) {
          registryWarning = ` Soroban registry proof was not recorded: ${friendlyError(registryError)}`
        }
      }
      saveSchedules(createdSchedules)
      setSchedules(readSchedules())
      void refreshWalletBalances()
      setActiveBalanceIds((current) => [...new Set([...current, ...result.balanceIds])])
      setBalancesLoaded(true)
      setLastProof({
        hash: result.hash,
        total: String(payrollRows.reduce((sum, recipient) => sum + Number(recipient.total), 0)),
        balanceCount: payrollRows.length * tranches,
        employeeCount: payrollRows.length,
        payouts: tranches,
        firstUnlock: firstUnlock.toISOString(),
        asset: ASSET_LABEL,
        registryHash: registryProof?.hash,
        registryContractId: registryProof?.contractId,
      })
      setNotice({ type: 'success', text: `Payroll locked for ${payrollRows.length} ${payrollRows.length === 1 ? 'employee' : 'employees'}${registryProof ? ' and recorded in the Soroban registry' : ''}. Future payouts can be cancelled before payday.${registryWarning}`, hash: result.hash })
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setBusy(false)
    }
  }

  async function cancelSchedule(schedule: ScheduleMeta) {
    if (!wallet) return connect()
    if (wallet.network !== 'TESTNET') return setNotice({ type: 'error', text: 'Switch Freighter to Testnet, then reconnect.' })
    if (schedule.employer !== wallet.address) return setNotice({ type: 'error', text: 'Connect the employer wallet that originally funded this payroll.' })
    const preview = cancellableIds(schedule, activeBalanceSet, Date.now())
    if (preview.length === 0) return setNotice({ type: 'error', text: 'No future payouts remain. Payouts at or past payday cannot be cancelled.' })
    const confirmed = window.confirm(`Cancel the remaining future payouts for ${schedule.name}? Sweldo will re-check all ${preview.length} eligible ${preview.length === 1 ? 'payout' : 'payouts'} on Stellar, then return them to your wallet. Payouts at or past payday stay protected.`)
    if (!confirmed) return
    setCancelling(schedule.id)
    setNotice(null)
    try {
      const latestBalances = await getClaimableBalances(wallet.address)
      const latestIds = latestBalances.map((record) => record.balance_id)
      const latestSet = new Set(latestIds)
      setActiveBalanceIds(latestIds)
      setBalancesLoaded(true)
      const balanceIds = cancellableIds(schedule, latestSet, Date.now())
      if (balanceIds.length === 0) throw new Error('No future payouts remain. Payouts at or past payday cannot be cancelled.')
      const result = await cancelBalances(wallet.address, balanceIds)
      const nextSchedules = readSchedules().map((saved) => saved.id === schedule.id ? {
        ...saved,
        cancelledAt: new Date().toISOString(),
        cancelHash: result.hash,
        cancelledPayouts: (saved.cancelledPayouts ?? 0) + balanceIds.length,
      } : saved)
      writeSchedules(nextSchedules)
      setSchedules(nextSchedules)
      setActiveBalanceIds((current) => current.filter((balanceId) => !balanceIds.includes(balanceId)))
      setNotice({ type: 'success', text: `${balanceIds.length} future ${balanceIds.length === 1 ? 'payout was' : 'payouts were'} cancelled and returned to your wallet.`, hash: result.hash })
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setCancelling('')
    }
  }

  return (
    <DashboardShell title="Employer workspace" subtitle="Create payroll schedules that settle themselves.">
      <div className={`dashboard-grid ${schedules.length === 0 ? 'single' : ''}`}>
        <form className="panel form-panel" onSubmit={submit}>
          <div className="panel-title"><div><h2>New payroll schedule</h2><p>One transaction creates every time-locked payout (tranche).</p></div><span><Plus size={16} /></span></div>
          <FundCard wallet={wallet} />
          <TrustlineCard wallet={wallet} connect={connect} message={`Add a ${ASSET_LABEL} trustline so this wallet can hold and lock ${ASSET_LABEL} for payroll.`} />
          {notice && <div className={`notice ${notice.type}`}>{notice.type === 'success' ? <Check size={18} /> : <X size={18} />}<div>{notice.text}{notice.hash && <a href={`https://stellar.expert/explorer/testnet/tx/${notice.hash}`} target="_blank" rel="noreferrer">View transaction <ExternalLink size={13} /></a>}</div></div>}
          {lastProof && <div className="payroll-proof">
            <div className="proof-title"><ShieldCheck size={18} /><div><strong>Payroll proof</strong><span>{lastProof.payouts} payouts per employee ({lastProof.payouts} tranches) confirmed on Stellar Testnet.</span></div></div>
            <div className="proof-metrics"><div><span>Total locked</span><strong>{formatAmount(lastProof.total)} {lastProof.asset}</strong></div><div><span>Claimable balances</span><strong>{lastProof.balanceCount}</strong></div><div><span>Employees</span><strong>{lastProof.employeeCount}</strong></div><div><span>First payday (First unlock)</span><strong>{new Date(lastProof.firstUnlock).toLocaleString()}</strong></div></div>
            <div className="proof-hash"><span>Payout transaction hash</span><code>{short(lastProof.hash, 8)}</code></div>
            <a className="proof-link" href={`https://stellar.expert/explorer/testnet/tx/${lastProof.hash}`} target="_blank" rel="noreferrer">Verify payout on Stellar Expert <ExternalLink size={13} /></a>
            {lastProof.registryContractId && <>
              <div className="proof-hash"><span>Soroban registry contract</span><code>{short(lastProof.registryContractId, 8)}</code></div>
              {lastProof.registryHash && <a className="proof-link" href={`https://stellar.expert/explorer/testnet/tx/${lastProof.registryHash}`} target="_blank" rel="noreferrer">Verify registry proof <ExternalLink size={13} /></a>}
            </>}
          </div>}
          <div className="batch-head" data-tour="employees"><div><h3>Employees</h3><p>Add one or more wallets to fund in the same payroll transaction.</p></div><div className="batch-actions"><Button type="button" className="button-ghost shuffle-button" data-tour="shuffle" onClick={shuffle} title="Fill the form with new sample values"><Dices size={15} key={shuffles} className={shuffles ? 'dice-roll' : ''} /> Shuffle</Button><Button type="button" className="button-ghost" onClick={() => setRecipients((current) => [...current, createPayrollRecipient('')])}><Plus size={15} /> Add employee</Button></div></div>
          <div className="employee-list">
            {recipients.map((recipient, index) => <div className="employee-row" key={recipient.id}>
              {shuffles > 0 && <span className="row-flash" key={shuffles} aria-hidden="true" />}
              <div className="row-number">{String(index + 1).padStart(2, '0')}</div>
              <label>Employee name <span>optional</span><input value={recipient.name} onChange={(event) => updateRecipient(recipient.id, { name: event.target.value })} placeholder="e.g. Ana Santos" /></label>
              <label>Wallet address<input className="mono" value={recipient.employee} onChange={(event) => updateRecipient(recipient.id, { employee: event.target.value.trim() })} placeholder="G..." /></label>
              <label>Total payroll amount<div className="input-suffix"><input inputMode="decimal" value={recipient.total} onChange={(event) => updateRecipient(recipient.id, { total: event.target.value })} /><b>{ASSET_LABEL}</b></div></label>
              <button className="row-remove" type="button" disabled={recipients.length === 1} onClick={() => removeRecipient(recipient.id)} aria-label="Remove employee"><X size={15} /></button>
            </div>)}
          </div>
          <PayScheduleBuilder
            cadence={interval}
            payouts={tranches}
            firstDelay={firstDelay}
            firstPaydayAt={firstPaydayAt}
            employees={recipients.length}
            totalLocked={totalLocked}
            assetLabel={ASSET_LABEL}
            nativeAsset={ASSET.isNative()}
            connected={Boolean(wallet)}
            balances={balances}
            onChange={changeSchedule}
          />
          <div className="schedule-summary"><span><Users size={17} /> {recipients.length} {employeeLabel} × <strong>{tranches} payouts (tranches)</strong></span><span>Total locked <strong>{formatAmount(totalLocked)} {ASSET_LABEL}</strong></span></div>
          <div className="cancellation-policy"><RotateCcw size={17} /><div><strong>Future-payout protection</strong><span>You can cancel a future payout (tranche) before payday. At payday, the employee’s claim right activates and that payout cannot be cancelled.</span></div></div>
          <Button className="button-primary full" type="submit" loading={busy} data-tour="lock"><LockKeyhole size={17} /> {wallet ? 'Lock payroll on Stellar' : 'Connect wallet to continue'}</Button>
          <p className="fine-print"><ShieldCheck size={14} /> Funds go straight from your wallet into protocol-level claimable balances.</p>
        </form>
        {schedules.length > 0 && <aside className="panel side-panel">
          <button type="button" className="panel-title collapsible-title" aria-expanded={schedulesOpen} onClick={() => setSchedulesOpen((open) => !open)}>
            <div><h2>Recent schedules <span className="count-badge">{schedules.length}</span></h2><p>Saved locally on this device.</p></div>
            <ChevronDown size={18} className="collapse-chevron" />
          </button>
          <div className={`collapse ${schedulesOpen ? 'open' : ''}`}><div>
          <div className="schedule-list">{schedules.map((schedule) => {
            const remaining = cancellableIds(schedule)
            const isOriginalEmployer = Boolean(wallet && schedule.employer === wallet.address)
            return <article key={schedule.id}>
              <div className="avatar">{schedule.name.slice(0, 1).toUpperCase()}</div>
              <div><strong>{schedule.name}</strong><span>{short(schedule.employee)}</span><small>{schedule.tranches} payouts (tranches) × {formatAmount(Number(schedule.total) / schedule.tranches)} {schedule.asset}</small></div>
              <a href={`https://stellar.expert/explorer/testnet/tx/${schedule.hash}`} target="_blank" rel="noreferrer" aria-label="View payroll transaction"><ExternalLink size={16} /></a>
              <div className={`schedule-control ${schedule.cancelledAt ? 'cancelled' : ''}`}>
                {!schedule.revocable ? <span>Original schedule · cancellation was not enabled</span>
                  : schedule.cancelledAt ? <><span><Check size={12} /> {schedule.cancelledPayouts} future {schedule.cancelledPayouts === 1 ? 'payout' : 'payouts'} returned</span>{schedule.cancelHash && <a href={`https://stellar.expert/explorer/testnet/tx/${schedule.cancelHash}`} target="_blank" rel="noreferrer">Cancellation proof <ExternalLink size={11} /></a>}</>
                    : !wallet ? <span>Connect the employer wallet to manage this payroll</span>
                      : !isOriginalEmployer ? <span>Connect the original employer wallet</span>
                        : !balancesLoaded ? <span><LoaderCircle size={12} className="spin" /> Checking future payouts…</span>
                          : remaining.length > 0 ? <><span>{remaining.length} future {remaining.length === 1 ? 'payout' : 'payouts'} cancellable before payday</span><Button type="button" className="button-cancel" loading={cancelling === schedule.id} onClick={() => cancelSchedule(schedule)}><RotateCcw size={13} /> Cancel remaining payroll</Button></>
                            : <span>No cancellable future payouts remain</span>}
                {schedule.registryContractId && <a href={`https://stellar.expert/explorer/testnet/contract/${schedule.registryContractId}`} target="_blank" rel="noreferrer">Soroban registry <ExternalLink size={11} /></a>}
              </div>
            </article>
          })}</div>
          </div></div>
        </aside>}
      </div>
    </DashboardShell>
  )
}

function BalanceCard({ record, address, onClaim, onConvert, claiming, disabled }: { record: BalanceRecord; address: string; onClaim: (record: BalanceRecord) => void; onConvert?: (record: BalanceRecord) => void; claiming: boolean; disabled: boolean }) {
  const unlockAt = parseUnlockTime(record.claimants.find((claimant) => claimant.destination === address)?.predicate ?? {})
  const countdown = useCountdown(unlockAt)
  return (
    <article className={`balance-card ${countdown.unlocked ? 'unlocked' : ''}`}>
      <div className="status-icon">{countdown.unlocked ? <BadgeCheck /> : <LockKeyhole />}</div>
      <div className="balance-main"><span className="status-label">{countdown.unlocked ? 'READY TO CLAIM' : 'LOCKED'}</span><strong>{formatAmount(record.amount)} <small>{record.asset === 'native' ? 'XLM' : record.asset.split(':')[0]}</small></strong><span className="unlock-date">{unlockAt ? (countdown.unlocked ? `Unlocked ${unlockAt.toLocaleString()}` : `Unlocks ${unlockAt.toLocaleString()}`) : 'Available unconditionally'}</span></div>
      <div className="balance-action">{countdown.unlocked ? <>{onConvert && <Button className="button-primary" disabled={disabled} onClick={() => onConvert(record)}>Claim as PHPT <ArrowRight size={16} /></Button>}<Button className={onConvert ? 'claim-original' : 'button-primary'} disabled={disabled} onClick={() => onClaim(record)} loading={claiming}>{onConvert ? 'Claim USDC only' : 'Claim now'}{!onConvert && <ArrowRight size={16} />}</Button></> : <div className="countdown"><Clock3 size={15} /><span>{countdown.label}</span></div>}<a href={`https://stellar.expert/explorer/testnet/claimable-balance/${record.balance_id}`} target="_blank" rel="noreferrer">View on-chain <ExternalLink size={12} /></a></div>
    </article>
  )
}

function ClaimHistory({ history }: { history: ClaimHistoryRecord[] }) {
  return (
    <section className="history-panel panel" data-tour="claim-history">
      <div className="timeline-head">
        <div><h2>Claim history</h2><p>Completed payroll claims for this wallet.</p></div>
        <span>{history.length} claimed</span>
      </div>
      {history.length === 0 ? <div className="empty history-empty"><div><BadgeCheck /></div><h3>No claims yet</h3><p>Claimed salary payouts (tranches) will appear here with their transaction proof.</p></div> : <div className="history-list">{history.map((record) => <article key={record.transactionHash ?? record.id}><div className="history-check"><Check size={17} /></div><div><strong>{record.amount ? `${formatAmount(record.amount)} ${record.asset ?? ASSET_LABEL}` : 'Claimed payroll payout (tranche)'}</strong><span>{new Date(record.claimedAt).toLocaleString()}</span><small>{record.balanceId ? short(record.balanceId, 8) : 'Claim operation'}</small></div>{record.transactionHash && <a href={`https://stellar.expert/explorer/testnet/tx/${record.transactionHash}`} target="_blank" rel="noreferrer">View tx <ExternalLink size={12} /></a>}</article>)}</div>}
    </section>
  )
}

function Employee({ wallet, connect }: { wallet: WalletState | null; connect: () => void }) {
  const [records, setRecords] = useState<BalanceRecord[]>([])
  const [history, setHistory] = useState<ClaimHistoryRecord[]>([])
  const [busy, setBusy] = useState(false)
  const [claiming, setClaiming] = useState('')
  const [converting, setConverting] = useState<BalanceRecord | null>(null)
  const [conversionReceipt, setConversionReceipt] = useState<ConversionReceipt | null>(null)
  const [notice, setNotice] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  const refresh = useCallback(async () => {
    if (!wallet) return
    setBusy(true)
    try {
      const [claimable, onChainHistory] = await Promise.all([
        getClaimableBalances(wallet.address),
        getClaimHistory(wallet.address),
      ])
      setRecords(claimable)
      setHistory(mergeClaimHistory(readLocalClaimHistory(wallet.address), onChainHistory))
      setNotice(null)
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setBusy(false)
    }
  }, [wallet])

  useEffect(() => { void refresh() }, [refresh])
  const totals = useMemo(() => records.reduce((sum, record) => sum + Number(record.amount), 0), [records])

  function conversionCompleted(receipt: ConversionReceipt) {
    if (!wallet) return
    setConversionReceipt(receipt)
    setConverting(null)
    try {
      saveClaimHistory(wallet.address, {
        id: receipt.balanceId, balanceId: receipt.balanceId, transactionHash: receipt.hash,
        claimedAt: new Date().toISOString(), amount: receipt.receivedAmount ?? undefined, asset: 'PHPT', source: 'local',
      })
    } catch { /* A full browser cache must not hide a confirmed transaction receipt. */ }
    void refresh()
  }

  async function claim(record: BalanceRecord) {
    if (!wallet) return connect()
    setClaiming(record.balance_id)
    try {
      const result = await claimBalance(wallet.address, record.balance_id)
      saveClaimHistory(wallet.address, {
        id: record.balance_id,
        balanceId: record.balance_id,
        transactionHash: result.hash,
        claimedAt: new Date().toISOString(),
        amount: record.amount,
        asset: record.asset === 'native' ? 'XLM' : record.asset.split(':')[0],
        source: 'local',
      })
      setNotice({ type: 'success', text: 'Pay claimed successfully. It is now in your wallet.' })
      await refresh()
    } catch (error) {
      setNotice({ type: 'error', text: friendlyError(error) })
    } finally {
      setClaiming('')
    }
  }

  return (
    <DashboardShell title="My pay" subtitle="Your on-chain salary, unlocked on schedule.">
      {!wallet ? <div className="connect-state panel"><div className="wallet-orbit"><Wallet /></div><h2>Connect to see your pay</h2><p>Use the Freighter wallet your employer added to the payroll, in this browser or on your phone.</p><Button className="button-primary button-large" onClick={connect} data-tour="connect-pay"><Wallet size={18} /> Connect Freighter</Button></div> : <>
        <div className="wallet-overview panel" data-tour="pay-overview"><div><span>CONNECTED WALLET</span><strong>{short(wallet.address, 8)}</strong><button onClick={() => navigator.clipboard.writeText(wallet.address)}><Copy size={14} /> Copy</button></div><div className="overview-stat"><span>LOCKED & CLAIMABLE</span><strong>{formatAmount(totals)} <small>{records[0]?.asset === 'native' || !records[0] ? ASSET_LABEL : records[0].asset.split(':')[0]}</small></strong></div><div className="overview-stat"><span>ACTIVE PAYOUTS (TRANCHES)</span><strong>{records.length}</strong></div><Button className="refresh-button" onClick={refresh} loading={busy}><RefreshCw size={17} /></Button></div>
        {notice && <div className={`notice wide ${notice.type}`}>{notice.type === 'success' ? <Check size={18} /> : <X size={18} />} {notice.text}</div>}
        {conversionReceipt && <ClaimConversionReceipt receipt={conversionReceipt} />}
        <FundCard wallet={wallet} />
        <TrustlineCard wallet={wallet} connect={connect} message={`Add a trustline before claiming this issued asset.`} />
        <div className="timeline-head"><div><h2>Vesting timeline</h2><p>Claimable balances addressed to your wallet.</p></div><span>{records.length} active</span></div>
        {busy && records.length === 0 ? <div className="loading-state"><LoaderCircle className="spin" /><span>Reading Stellar ledger…</span></div> : records.length === 0 ? <div className="empty large panel"><div><Clock3 /></div><h3>No active pay found</h3><p>Ask your employer to create a schedule for <span className="mono">{short(wallet.address, 8)}</span>, then refresh.</p><Button className="button-ghost" onClick={refresh}><RefreshCw size={16} /> Refresh ledger</Button></div> : <div className="balance-list" data-tour="pay-timeline">{records.map((record) => <BalanceCard key={record.balance_id} record={record} address={wallet.address} onClaim={claim} onConvert={supportsConversion(record, CONVERSION_PAIR) ? setConverting : undefined} disabled={!!claiming || busy} claiming={claiming === record.balance_id} />)}</div>}
        <ClaimHistory history={history} />
        {converting && CONVERSION_PAIR && <ClaimConversionDialog address={wallet.address} payout={converting} pair={CONVERSION_PAIR} onClose={() => setConverting(null)} onComplete={conversionCompleted} />}
      </>}
    </DashboardShell>
  )
}

const TOUR_KEY = 'sweldo-tour-seen-v1'

const TOUR: TourStep<View>[] = [
  { view: 'home', title: 'Welcome to Sweldo', body: 'Lock a team’s pay on Stellar once, and each person claims it on payday. This guide takes about a minute. Use → and ← to move, Esc to close.' },
  { view: 'home', target: '[data-tour="hero-actions"]', title: 'Two sides, one app', body: 'Employers set up payroll from “Create a payroll”. Workers open “View my pay” to claim.' },
  { target: '[data-tour="connect"]', title: 'Connect Freighter', body: 'Use the Freighter extension in this browser, or scan a QR code with the Freighter app on your phone. Sweldo never sees your keys.' },
  { view: 'employer', target: '[data-tour="employees"]', title: 'Add your team', body: 'Each row is one person: a name, their Stellar wallet address, and the total to pay them.' },
  { view: 'employer', target: '[data-tour="shuffle"]', title: 'Try it with sample values', body: 'Shuffle fills in names, pay and a schedule so you can explore. Wallet addresses you typed stay put.', tryIt: 'Press Shuffle and watch the form roll.' },
  { view: 'employer', target: '[data-tour="schedule-sentence"]', title: 'Read the schedule as a sentence', body: 'Each highlighted part is a menu: how often, how many times, and when pay starts. “Pay until a date” counts the paydays for you.', tryIt: 'Open one of the highlighted parts.' },
  { view: 'employer', target: '[data-tour="payout-track"]', title: 'Drag to set the number of payouts', body: 'Each slot is one payout. Hatched slots are past what one Stellar transaction can hold for your team.', tryIt: 'Drag the handle left or right.' },
  { view: 'employer', target: '[data-tour="presets"]', title: 'Or start from a preset', body: 'A live demo, daily, weekly or monthly plan sets everything at once.' },
  { view: 'employer', target: '[data-tour="insights"]', title: 'Check before you sign', body: 'Live notes on the first and last payday, the transaction limit, and whether your wallet covers the total plus reserves.' },
  { view: 'employer', target: '[data-tour="lock"]', title: 'Lock it with one signature', body: 'Freighter shows the transaction. Once you approve, every payout is locked on Stellar. You can cancel future payouts until each payday.' },
  { view: 'employee', target: '[data-tour="connect-pay"]', title: 'Workers: connect to see your pay', body: 'Use the wallet your employer paid. Payouts unlock on their payday and you claim them straight to your wallet.' },
  { view: 'employee', target: '[data-tour="pay-timeline"]', title: 'Claim on payday', body: 'Each locked payout counts down. When it reaches zero, Claim appears.' },
  { view: 'employee', target: '[data-tour="claim-history"]', title: 'Every claim has a receipt', body: 'Claimed pay is listed here with a link to its transaction on Stellar Expert.' },
  { title: 'You’re set', body: 'Open this guide any time from Guide in the top bar.' },
]

function App() {
  const [view, setView] = useState<View>('home')
  const [wallet, setWallet] = useState<WalletState | null>(null)
  const [connectOpen, setConnectOpen] = useState(false)
  const [approvalPending, setApprovalPending] = useState(false)
  const [toast, setToast] = useState('')
  const [tourOpen, setTourOpen] = useState(false)

  function flash(message: string) {
    setToast(message)
    window.setTimeout(() => setToast(''), 3500)
  }

  useEffect(() => {
    let cancelled = false
    // A Freighter Mobile session survives reloads; pick it back up quietly.
    restoreWallet().then((restored) => { if (restored && !cancelled) setWallet(restored) }).catch(() => {})
    const stopDisconnect = onWalletDisconnected(() => {
      setWallet(null)
      flash('Freighter ended the session. Connect again to continue.')
    })
    const stopApproval = onPendingApproval(setApprovalPending)
    // First visit: offer the guide once.
    let seen = true
    try { seen = localStorage.getItem(TOUR_KEY) === '1' } catch { /* storage may be blocked */ }
    const timer = seen ? 0 : window.setTimeout(() => { if (!cancelled) setTourOpen(true) }, 900)
    return () => { cancelled = true; window.clearTimeout(timer); stopDisconnect(); stopApproval() }
  }, [])

  function connect() {
    setConnectOpen(true)
  }

  async function connected(next: WalletState) {
    setWallet(next)
    setConnectOpen(false)
    try {
      const balance = await getXlmBalance(next.address)
      flash(`Connected. ${formatAmount(balance)} XLM available.`)
    } catch (error) {
      flash(friendlyError(error))
    }
  }

  async function disconnect() {
    await disconnectWallet()
    setWallet(null)
    flash('Wallet disconnected.')
  }

  const go = useCallback((next: View) => {
    setView(next)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [])

  const closeTour = useCallback(() => {
    setTourOpen(false)
    try { localStorage.setItem(TOUR_KEY, '1') } catch { /* ignore */ }
  }, [])

  return (
    <div className="app">
      <Header wallet={wallet} connect={connect} busy={false} go={go} view={view} onGuide={() => setTourOpen(true)} />
      <GuidedTour open={tourOpen} steps={TOUR} onClose={closeTour} onNavigate={go} />
      {toast && <div className="toast">{toast}</div>}
      <ConnectWalletModal open={connectOpen} wallet={wallet} onClose={() => setConnectOpen(false)} onConnected={connected} onDisconnect={disconnect} />
      <ApprovalPrompt pending={approvalPending} />
      {wallet && wallet.network !== 'TESTNET' && <div className="wrong-network">Freighter is on {wallet.network}. Switch it to <strong>Testnet</strong> before signing.</div>}
      {view === 'home' && <Home go={go} />}
      {view === 'employer' && <Employer wallet={wallet} connect={connect} />}
      {view === 'employee' && <Employee key={wallet?.address} wallet={wallet} connect={connect} />}
      <footer><Logo onClick={() => go('home')} /><p>Payroll that keeps its promise. Built on Stellar Testnet.</p><a href="https://stellar.org" target="_blank" rel="noreferrer">Built on Stellar <ExternalLink size={13} /></a></footer>
      {registryContractId() && <div className="contract-ribbon">Soroban Payroll Registry: <a href={`https://stellar.expert/explorer/testnet/contract/${registryContractId()}`} target="_blank" rel="noreferrer">{short(registryContractId(), 8)}</a></div>}
    </div>
  )
}

export default App

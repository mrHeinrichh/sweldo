import type { CSSProperties, ReactNode } from 'react'
import { ArrowDown, ArrowRightLeft, Check, House, LockKeyhole, PenLine, UsersRound, Wallet } from 'lucide-react'
import { formatAmount } from '../../state/amount'
import { stampCurve } from '../../ui/curves'
import { SweldoLogo } from '../../ui/Logo'
import { ClaimedStamp, PaperHeader, PayrollPaper, PunchSlot, type PunchState } from '../../ui/Paper'
import { easeBack, easeInOut, easeOut, seg } from './script'

// Every screen here is a pure function of story time, so the story can be
// paused, scrubbed and replayed frame-exactly.

const TABS = [
  { icon: House, label: 'Overview' },
  { icon: UsersRound, label: 'Pay your team' },
  { icon: Wallet, label: 'My pay' },
]

/** The Sweldo app chrome inside the phone. */
function PhoneApp({ title, tab = 2, children }: { title: string; tab?: number; children: ReactNode }) {
  return (
    <div className="phone-app">
      <div className="phone-app-body">
        <div className="phone-app-top">
          <SweldoLogo />
          <span className="phone-testnet">Testnet</span>
        </div>
        <h3 className="phone-app-title">{title}</h3>
        {children}
      </div>
      <div className="phone-tabs">
        {TABS.map((item, index) => {
          const Icon = item.icon
          return (
            <div key={item.label} className={`phone-tab ${index === tab ? 'selected' : ''}`}>
              <span className="phone-tab-indicator"><Icon size={21} /></span>
              <span className="phone-tab-label">{item.label}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

/** A finger tap: a dot that presses in and a ring that spreads. */
function Tapped({ t, children, style }: { t: number; children: ReactNode; style?: CSSProperties }) {
  const active = t > 0 && t < 1
  const press = active ? Math.sin(t * Math.PI) : 0
  return (
    <div className="phone-tapped" style={style}>
      <div style={{ transform: `scale(${1 - 0.04 * press})` }}>{children}</div>
      {active && (
        <>
          <span className="phone-tap-ring" style={{ transform: `translate(-50%, -50%) scale(${0.6 + 1.4 * t})`, borderColor: `rgba(20, 33, 58, ${0.35 * (1 - t)})` }} />
          <span className="phone-tap-dot" style={{ background: `rgba(20, 33, 58, ${0.28 * press})` }} />
        </>
      )}
    </div>
  )
}

function PhoneButton({ label, color = 'var(--stamp)', tap = 0, icon }: { label: string; color?: string; tap?: number; icon?: ReactNode }) {
  return (
    <Tapped t={tap}>
      <div className="phone-button" style={{ background: color }}>
        {icon}
        <span>{label}</span>
      </div>
    </Tapped>
  )
}

/** A stamp whose landing is driven by story time. */
function TimedStamp({ t, label = 'Claimed', color = 'var(--stamp)' }: { t: number; label?: string; color?: string }) {
  if (t <= 0) return null
  const scale = 1.9 - 0.9 * stampCurve(t)
  return (
    <span style={{ display: 'inline-block', opacity: Math.min(1, t * 2.5), transform: `scale(${scale})` }}>
      <ClaimedStamp label={label} color={color} />
    </span>
  )
}

/** The wallet's approval sheet sliding over the app. */
function ConfirmSheet({ visible, approveTap, title, rows }: { visible: number; approveTap: number; title: string; rows: [string, string][] }) {
  if (visible <= 0) return null
  const shift = (1 - easeOut(visible)) * 420
  return (
    <div className="phone-overlay">
      <div className="phone-scrim" style={{ background: `rgba(20, 33, 58, ${0.32 * visible})` }} />
      <div className="phone-confirm" style={{ transform: `translateY(${shift}px)` }}>
        <span className="phone-confirm-handle" />
        <div className="phone-confirm-head">
          <span className="phone-confirm-icon"><PenLine size={18} /></span>
          <span className="t-subtitle" style={{ fontSize: 18 }}>{title}</span>
        </div>
        {rows.map(([label, value]) => (
          <div key={label} className="phone-confirm-row">
            <span className="t-body-sm">{label}</span>
            <span className="t-figures">{value}</span>
          </div>
        ))}
        <div style={{ height: 18 }} />
        <PhoneButton label="Approve" tap={approveTap} />
      </div>
    </div>
  )
}

function Chip({ label, selected }: { label: string; selected?: boolean }) {
  return <span className={`phone-chip ${selected ? 'selected' : ''}`}>{label}</span>
}

function Line({ label, value }: { label: string; value: string }) {
  return (
    <div className="phone-line">
      <span className="t-body-sm">{label}</span>
      <span className="t-figures">{value}</span>
    </div>
  )
}

/** Scene 2: the employer locks six payouts with one signature. */
export function EmployerScreen({ g }: { g: number }) {
  const s = 4.5
  const e = 11
  const at = (a: number, b: number) => seg(g, s + a * (e - s), s + b * (e - s))
  const lockTap = at(0.26, 0.36)
  const sheet = at(0.34, 0.44) - at(0.64, 0.74)
  const approveTap = at(0.54, 0.64)
  const locked = at(0.72, 0.84)

  return (
    <div className="phone-screen">
      <PhoneApp title="Pay your team" tab={1}>
        <div className="phone-card" style={{ padding: 16 }}>
          <div className="t-subtitle">Ana Santos</div>
          <div className="t-mono">GBX7…Q2LM</div>
          <div className="phone-row" style={{ marginTop: 14 }}>
            <span className="t-body-sm">Total pay</span>
            <span className="t-figures">1,800 USDC</span>
          </div>
          <div className="phone-chips" style={{ marginTop: 14 }}>
            <Chip label="Monthly" selected />
            <Chip label="6 payouts" />
            <Chip label="First payday in 1 month" />
          </div>
        </div>
        <div className="phone-summary">
          <span className="t-body-sm t-ink">6 payouts of 300 USDC</span>
          <span className="t-amount" style={{ fontSize: 20 }}>1,800 USDC</span>
        </div>
        <div style={{ height: 150, marginTop: 18 }}>
          {locked > 0 && (
            <div style={{ opacity: Math.min(1, locked * 3) }}>
              <PayrollPaper header={<PaperHeader title="Payroll locked" trailing={<TimedStamp t={locked} label="Locked" />} />}>
                <Line label="Payouts created" value="6" />
                <Line label="First payday" value="Nov 3" />
              </PayrollPaper>
            </div>
          )}
        </div>
      </PhoneApp>
      <div style={{ position: 'absolute', left: 20, right: 20, bottom: 112 }}>
        {locked > 0
          ? <PhoneButton label="Payroll locked" color="var(--payday)" icon={<Check size={18} />} />
          : <PhoneButton label="Lock payroll on Stellar" icon={<LockKeyhole size={18} />} tap={lockTap} />}
      </div>
      <ConfirmSheet visible={sheet} approveTap={approveTap} title="Confirm in Freighter" rows={[['Lock', '1,800 USDC'], ['Payouts', '6, monthly'], ['Network', 'Testnet']]} />
    </div>
  )
}

function Figure({ label, value, color = 'var(--ink)' }: { label: string; value: string; color?: string }) {
  return (
    <div>
      <div className="t-caption">{label}</div>
      <div className="t-amount" style={{ fontSize: 20, color, marginTop: 2 }}>{value}</div>
    </div>
  )
}

function Countdown({ label }: { label: string }) {
  return (
    <span className="phone-countdown">
      <LockKeyhole size={14} />
      <span className="t-figures">{label}</span>
    </span>
  )
}

function PayRow({ slot, amount, caption, trailing }: { slot: PunchState; amount: string; caption: string; trailing: ReactNode }) {
  return (
    <div className="phone-pay-row">
      <PunchSlot state={slot} />
      <div className="phone-pay-text">
        <div className="t-figures" style={{ fontSize: 16 }}>{amount}</div>
        <div className="t-caption">{caption}</div>
      </div>
      <div className="phone-pay-trailing">{trailing}</div>
    </div>
  )
}

/** Scenes 4–5: the countdown runs out, then one tap claims the payout. */
export function WorkerScreen({ g }: { g: number }) {
  const remaining = Math.min(3, Math.max(0, 20 - Math.max(g, 17)))
  const ready = g >= 20
  const claimPop = easeBack(seg(g, 20, 20.35))
  const claimTap = seg(g, 21.6, 22)
  const sheet = seg(g, 21.9, 22.4) - seg(g, 23.3, 23.8)
  const approveTap = seg(g, 23, 23.4)
  const stamp = seg(g, 23.9, 24.5)
  const counted = easeInOut(seg(g, 24, 25.2))
  const claimed = stamp > 0
  const wallet = 300 * counted
  const lockedTotal = 1800 - 300 * counted
  const later = [['Dec 3', '30d 0h'], ['Jan 3', '61d 0h'], ['Feb 3', '92d 0h']]

  return (
    <div className="phone-screen">
      <PhoneApp title="My pay">
        <div className="phone-card phone-row" style={{ padding: 16 }}>
          <Figure label="Locked and claimable" value={`${formatAmount(Math.round(lockedTotal))} USDC`} />
          <Figure label="In your wallet" value={`${formatAmount(Math.round(wallet))} USDC`} color={counted > 0 ? 'var(--payday)' : 'var(--ink)'} />
        </div>
        <div style={{ height: 18 }} />
        <PayrollPaper>
          <PayRow
            slot={claimed ? 'punched' : ready ? 'ready' : 'locked'}
            amount="300 USDC"
            caption={claimed ? 'Claimed just now' : ready ? 'Unlocked today at 9:41 AM' : 'Unlocks today at 9:41 AM'}
            trailing={claimed
              ? <TimedStamp t={stamp} />
              : ready
                ? (
                  <div style={{ transform: `scale(${claimPop})`, width: 96 }}>
                    <Tapped t={claimTap}>
                      <div className="phone-claim">Claim</div>
                    </Tapped>
                  </div>
                )
                : <Countdown label={`0m ${String(Math.ceil(remaining)).padStart(2, '0')}s`} />}
          />
          {later.map(([month, left]) => (
            <PayRow key={month} slot="locked" amount="300 USDC" caption={`Unlocks ${month}`} trailing={<Countdown label={left} />} />
          ))}
        </PayrollPaper>
      </PhoneApp>
      <ConfirmSheet visible={sheet} approveTap={approveTap} title="Confirm in Freighter" rows={[['Claim', '300 USDC'], ['To', 'Your wallet'], ['Network', 'Testnet']]} />
    </div>
  )
}

/** Scene 6: claim-and-convert to PHPT. */
export function ConvertScreen({ g }: { g: number }) {
  const counted = easeOut(seg(g, 27.2, 28.6))
  const quoteLeft = Math.round(Math.min(60, Math.max(0, 60 - (g - 27) * 1.2)))
  const tap = seg(g, 29, 29.4)
  const stamp = seg(g, 29.6, 30.2)

  return (
    <div className="phone-screen">
      <PhoneApp title="Claim as PHPT">
        <div className="phone-card" style={{ padding: 18 }}>
          <div className="t-caption">You claim</div>
          <div className="t-amount">300 test-USDC</div>
          <div style={{ padding: '10px 0', color: 'var(--stamp)', height: 44, boxSizing: 'border-box' }}><ArrowDown size={24} /></div>
          <div className="t-caption">You receive about</div>
          <div className="t-amount-lg" style={{ color: 'var(--payday)' }}>{formatAmount(Math.round(17040 * counted))} PHPT</div>
          <div className="phone-divider" />
          <div className="phone-row"><span className="t-body-sm">At least</span><span className="t-figures">16,869.6 PHPT</span></div>
          <div className="phone-row" style={{ marginTop: 6 }}><span className="t-body-sm">Price may move</span><span className="t-figures">Up to 1%</span></div>
          <div className="phone-row" style={{ marginTop: 6 }}><span className="t-body-sm">Quote</span><span className="t-figures">{quoteLeft}s left</span></div>
        </div>
        <div style={{ height: 22 }} />
        <div style={{ height: 80 }}>
          {stamp > 0
            ? (
              <div className="phone-row" style={{ height: '100%' }}>
                <span className="t-subtitle">17,040 PHPT is in your wallet.</span>
                <TimedStamp t={stamp} label="Converted" color="var(--payday)" />
              </div>
            )
            : <PhoneButton label="Claim and convert" icon={<ArrowRightLeft size={18} />} tap={tap} />}
        </div>
        <p className="t-caption m0">Test assets on Stellar Testnet. One transaction claims and converts, or nothing happens.</p>
      </PhoneApp>
    </div>
  )
}

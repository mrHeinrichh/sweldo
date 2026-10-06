import { useEffect, useId, useRef, useState, type ReactNode } from 'react'
import {
  CalendarClock,
  CalendarDays,
  CalendarRange,
  Check,
  ChevronDown,
  GripVertical,
  Hourglass,
  Info,
  Layers,
  ShieldCheck,
  Sun,
  Timer,
  TriangleAlert,
  Wallet,
  Zap,
} from 'lucide-react'
import type { WalletBalances } from '../lib/stellar'
import {
  CADENCE_ORDER,
  CADENCES,
  MAX_OPERATIONS,
  MAX_PAYOUTS,
  capacity as teamCapacity,
  firstPayday,
  paydays,
  payoutsUntil,
  units,
  type Cadence,
} from '../lib/schedule'
import './PayScheduleBuilder.css'

export type SchedulePatch = Partial<{
  cadence: Cadence
  payouts: number
  firstDelay: number
  firstPaydayAt: Date | null
}>

type Props = {
  cadence: Cadence
  payouts: number
  firstDelay: number
  firstPaydayAt: Date | null
  employees: number
  totalLocked: number
  assetLabel: string
  nativeAsset: boolean
  connected: boolean
  /** undefined while unknown, null for an unfunded wallet. */
  balances: WalletBalances | null | undefined
  onChange: (patch: SchedulePatch) => void
}

const CADENCE_ICONS: Record<Cadence, ReactNode> = {
  minute: <Zap size={16} />,
  day: <Sun size={16} />,
  week: <CalendarRange size={16} />,
  month: <CalendarDays size={16} />,
}

const PRESETS: Array<{ title: string; cadence: Cadence; payouts: number; firstDelay: number }> = [
  { title: 'Live demo', cadence: 'minute', payouts: 3, firstDelay: 1 },
  { title: 'Daily for 2 weeks', cadence: 'day', payouts: 14, firstDelay: 1 },
  { title: 'Weekly for a quarter', cadence: 'week', payouts: 13, firstDelay: 1 },
  { title: 'Monthly for a year', cadence: 'month', payouts: 12, firstDelay: 1 },
]

const shortDate = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' })
const dateTime = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
const clock = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', second: '2-digit' })
const number = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 })

function useNow() {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 1000)
    return () => window.clearInterval(timer)
  }, [])
  return now
}

function toInputDate(date: Date) {
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

function fromInputDate(value: string) {
  const [y, m, d] = value.split('-').map(Number)
  return new Date(y, m - 1, d)
}

/**
 * The pay schedule as one smart, editable unit: a sentence whose parts are
 * controls, a track of payouts to drag, presets, and live insights that
 * check the plan against the calendar, the transaction limit and the wallet.
 */
export function PayScheduleBuilder(props: Props) {
  const { cadence, payouts, firstDelay, firstPaydayAt, employees, onChange } = props
  const now = useNow()
  const capacity = teamCapacity(employees)
  const first = firstPayday(now, cadence, firstDelay, firstPaydayAt)
  const days = paydays(first, cadence, payouts)
  const last = days[days.length - 1] ?? first

  const startLabel = firstPaydayAt
    ? `on ${shortDate.format(firstPaydayAt)}`
    : firstDelay === 0 ? 'right away' : `in ${units(cadence, firstDelay)}`

  return (
    <section className="schedule-builder" aria-label="Pay schedule">
      <div className="schedule-builder-title"><CalendarClock size={16} /> Pay schedule</div>
      <p className="schedule-sentence" data-tour="schedule-sentence">
        Pay
        <Token label={CADENCES[cadence].phrase} icon={CADENCE_ICONS[cadence]} after=",">
          {(close) => CADENCE_ORDER.map((option) => (
            <MenuItem
              key={option}
              icon={CADENCE_ICONS[option]}
              title={CADENCES[option].label}
              subtitle={CADENCES[option].hint}
              selected={option === cadence}
              onSelect={() => { onChange({ cadence: option }); close() }}
            />
          ))}
        </Token>
        <Token label={payouts === 1 ? 'once' : `${payouts} times`} icon={<Layers size={16} />} after=",">
          {(close) => (
            <>
              {[1, 3, 6, 12, 24].filter((n) => n <= capacity).map((n) => (
                <MenuItem
                  key={n}
                  icon={<Layers size={16} />}
                  title={n === 1 ? 'Once' : `${n} times`}
                  subtitle={n === 1 ? 'A single payout' : `Last payday ${units(cadence, n - 1)} after the first`}
                  selected={n === payouts}
                  onSelect={() => { onChange({ payouts: n }); close() }}
                />
              ))}
              <DateItem
                title="Pay until a date…"
                subtitle={cadence === 'minute' ? 'Not for minute-by-minute demos' : 'Sweldo counts the paydays for you'}
                disabled={cadence === 'minute'}
                min={toInputDate(first)}
                value={toInputDate(last)}
                onPick={(value) => {
                  const count = payoutsUntil(first, fromInputDate(value), cadence)
                  onChange({ payouts: Math.max(1, Math.min(capacity, count)) })
                  close()
                }}
              />
            </>
          )}
        </Token>
        <span>starting</span>
        <Token label={startLabel} icon={<Timer size={16} />} after=".">
          {(close) => (
            <>
              <MenuItem
                icon={<Zap size={16} />}
                title="Right away"
                subtitle="The first payout is claimable once locked"
                selected={!firstPaydayAt && firstDelay === 0}
                onSelect={() => { onChange({ firstDelay: 0, firstPaydayAt: null }); close() }}
              />
              {[1, 2, 3].map((n) => (
                <MenuItem
                  key={n}
                  icon={<Timer size={16} />}
                  title={`In ${units(cadence, n)}`}
                  subtitle={dateTime.format(new Date(now.getTime() + n * CADENCES[cadence].seconds * 1000))}
                  selected={!firstPaydayAt && firstDelay === n}
                  onSelect={() => { onChange({ firstDelay: n, firstPaydayAt: null }); close() }}
                />
              ))}
              <DateItem
                title="On a date…"
                subtitle="Paydays start at 9:00 AM that day"
                min={toInputDate(now)}
                value={toInputDate(firstPaydayAt ?? new Date(now.getTime() + 86_400_000))}
                onPick={(value) => {
                  const picked = fromInputDate(value)
                  if (toInputDate(picked) === toInputDate(now)) onChange({ firstDelay: 0, firstPaydayAt: null })
                  else onChange({ firstPaydayAt: new Date(picked.getFullYear(), picked.getMonth(), picked.getDate(), 9) })
                  close()
                }}
              />
            </>
          )}
        </Token>
      </p>

      <PayoutTrack payouts={payouts} capacity={capacity} first={first} last={last} onChange={(n) => onChange({ payouts: n })} />

      <div className="schedule-presets" data-tour="presets">
        {PRESETS.map((preset) => {
          const count = Math.min(preset.payouts, capacity)
          const selected = cadence === preset.cadence && payouts === count && firstDelay === preset.firstDelay && !firstPaydayAt
          return (
            <button
              key={preset.title}
              type="button"
              className={`preset-chip ${selected ? 'selected' : ''}`}
              aria-pressed={selected}
              onClick={() => onChange({ cadence: preset.cadence, payouts: count, firstDelay: preset.firstDelay, firstPaydayAt: null })}
            >
              {selected ? <Check size={14} /> : CADENCE_ICONS[preset.cadence]} {preset.title}
            </button>
          )
        })}
      </div>

      <Insights {...props} first={first} last={last} capacity={capacity} now={now} />
    </section>
  )
}

/** An editable part of the sentence: a pill that opens a menu. */
function Token({ label, icon, after, children }: { label: string; icon: ReactNode; after?: string; children: (close: () => void) => ReactNode }) {
  const [open, setOpen] = useState(false)
  const root = useRef<HTMLSpanElement>(null)
  const menuId = useId()

  useEffect(() => {
    if (!open) return
    const onPointer = (event: PointerEvent) => {
      if (!root.current?.contains(event.target as Node)) setOpen(false)
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false)
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        const items = [...(root.current?.querySelectorAll<HTMLElement>('[role="menuitemradio"]:not([disabled])') ?? [])]
        const index = items.indexOf(document.activeElement as HTMLElement)
        const next = event.key === 'ArrowDown' ? index + 1 : index - 1
        items[(next + items.length) % items.length]?.focus()
        event.preventDefault()
      }
    }
    document.addEventListener('pointerdown', onPointer)
    document.addEventListener('keydown', onKey)
    root.current?.querySelector<HTMLElement>('[role="menuitemradio"][aria-checked="true"], [role="menuitemradio"]')?.focus()
    return () => {
      document.removeEventListener('pointerdown', onPointer)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  return (
    <span className="token-wrap" ref={root}>
      <button
        type="button"
        className={`token ${open ? 'open' : ''}`}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-controls={menuId}
        onClick={() => setOpen(!open)}
      >
        {icon}
        <span key={label} className="token-label">{label}</span>
        <ChevronDown size={15} className="token-chevron" />
      </button>
      {after && <span className="token-after">{after}</span>}
      {open && <span className="token-menu" role="menu" id={menuId}>{children(() => setOpen(false))}</span>}
    </span>
  )
}

function MenuItem({ icon, title, subtitle, selected, onSelect }: {
  icon: ReactNode; title: string; subtitle: string; selected?: boolean; onSelect: () => void
}) {
  return (
    <button type="button" role="menuitemradio" aria-checked={!!selected} className={`menu-item ${selected ? 'selected' : ''}`} onClick={onSelect}>
      <span className="menu-icon">{icon}</span>
      <span className="menu-text"><strong>{title}</strong><small>{subtitle}</small></span>
      {selected && <Check size={15} className="menu-check" />}
    </button>
  )
}

function DateItem({ title, subtitle, disabled, min, value, onPick }: {
  title: string; subtitle: string; disabled?: boolean; min: string; value: string; onPick: (value: string) => void
}) {
  return (
    <label className={`menu-item date-item ${disabled ? 'disabled' : ''}`}>
      <span className="menu-icon"><CalendarDays size={16} /></span>
      <span className="menu-text"><strong>{title}</strong><small>{subtitle}</small>
        {!disabled && <input type="date" min={min} defaultValue={value} onChange={(event) => event.target.value && onPick(event.target.value)} />}
      </span>
    </label>
  )
}

/** One slot per possible payout; drag, click or use the arrow keys. */
function PayoutTrack({ payouts, capacity, first, last, onChange }: {
  payouts: number; capacity: number; first: Date; last: Date; onChange: (n: number) => void
}) {
  const track = useRef<HTMLDivElement>(null)
  const [dragging, setDragging] = useState(false)

  function setFrom(clientX: number) {
    const rect = track.current?.getBoundingClientRect()
    if (!rect) return
    const n = Math.max(1, Math.min(capacity, Math.floor(((clientX - rect.left) / rect.width) * MAX_PAYOUTS) + 1))
    if (n !== payouts) {
      navigator.vibrate?.(4)
      onChange(n)
    }
  }

  function onKeyDown(event: React.KeyboardEvent) {
    const moves: Record<string, number> = { ArrowRight: payouts + 1, ArrowUp: payouts + 1, ArrowLeft: payouts - 1, ArrowDown: payouts - 1, Home: 1, End: capacity }
    const next = moves[event.key]
    if (next === undefined) return
    event.preventDefault()
    onChange(Math.max(1, Math.min(capacity, next)))
  }

  const position = ((payouts - 0.5) / MAX_PAYOUTS) * 100
  return (
    <div className="payout-track-wrap" data-tour="payout-track">
      <div className="track-bubble" style={{ left: `clamp(64px, ${position}%, calc(100% - 64px))` }}>
        <strong>{payouts === 1 ? '1 payout' : `${payouts} payouts`}</strong>
        <small>ends {shortDate.format(last)}</small>
      </div>
      <div
        ref={track}
        className={`payout-track ${dragging ? 'dragging' : ''}`}
        role="slider"
        tabIndex={0}
        aria-label="Payouts per employee"
        aria-valuemin={1}
        aria-valuemax={capacity}
        aria-valuenow={payouts}
        aria-valuetext={`${payouts} payouts, last payday ${shortDate.format(last)}`}
        onKeyDown={onKeyDown}
        onPointerDown={(event) => { event.currentTarget.setPointerCapture(event.pointerId); setDragging(true); setFrom(event.clientX) }}
        onPointerMove={(event) => { if (dragging) setFrom(event.clientX) }}
        onPointerUp={() => setDragging(false)}
        onPointerCancel={() => setDragging(false)}
      >
        {Array.from({ length: MAX_PAYOUTS }, (_, index) => {
          const n = index + 1
          const state = n > capacity ? 'is-locked' : n <= payouts ? (n === payouts ? 'is-edge' : 'is-filled') : 'is-empty'
          return <span key={n} className={`slot ${state}`} style={{ transitionDelay: `${Math.min(index, 20) * 6}ms` }} />
        })}
        {capacity < MAX_PAYOUTS && <span className="track-limit" style={{ left: `${(capacity / MAX_PAYOUTS) * 100}%` }} />}
        <span className="track-knob" style={{ left: `${position}%` }}><GripVertical size={13} /></span>
      </div>
      <div className="track-labels">
        <span>Starts {shortDate.format(first)}</span>
        <span className={capacity < MAX_PAYOUTS ? 'limit' : ''}>{capacity < MAX_PAYOUTS ? `Team limit ${capacity}` : `Up to ${MAX_PAYOUTS}`}</span>
      </div>
    </div>
  )
}

type Tone = 'neutral' | 'good' | 'caution' | 'danger'

function Insight({ tone, icon, children, action }: { tone: Tone; icon: ReactNode; children: ReactNode; action?: { label: string; onClick: () => void } }) {
  return (
    <div className={`insight ${tone}`}>
      {icon}<span>{children}</span>
      {action && <button type="button" onClick={action.onClick}>{action.label}</button>}
    </div>
  )
}

function Insights({ cadence, payouts, employees, totalLocked, assetLabel, nativeAsset, connected, balances, onChange, first, last, capacity }: Props & {
  first: Date; last: Date; capacity: number; now: Date
}) {
  const count = employees * payouts
  const over = count > MAX_OPERATIONS
  return (
    <div className="schedule-insights" aria-live="polite" data-tour="insights">
      <Insight tone="neutral" icon={<CalendarClock size={15} />}>
        First payday {cadence === 'minute' ? clock.format(first) : dateTime.format(first)}
      </Insight>
      <Insight tone="neutral" icon={<Hourglass size={15} />}>
        {payouts === 1 ? 'One payout, nothing after it' : `Last payday ${shortDate.format(last)}, ${units(cadence, payouts - 1)} after the first`}
      </Insight>
      {over
        ? <Insight tone="danger" icon={<TriangleAlert size={15} />} action={{ label: 'Fit to one transaction', onClick: () => onChange({ payouts: capacity }) }}>
            {count} payouts won’t fit one transaction ({MAX_OPERATIONS} max)
          </Insight>
        : <Insight tone="neutral" icon={<Layers size={15} />}>{count} of {MAX_OPERATIONS} payouts in one signature</Insight>}
      <Coverage {...{ totalLocked, assetLabel, nativeAsset, connected, balances, count }} />
      {cadence === 'minute' && <Insight tone="neutral" icon={<Info size={15} />}>Keep the pay page open to watch each payout unlock live</Insight>}
      {cadence === 'month' && <Insight tone="neutral" icon={<Info size={15} />}>Monthly means every 30 days, so paydays drift from calendar dates</Insight>}
    </div>
  )
}

function Coverage({ totalLocked, assetLabel, nativeAsset, connected, balances, count }: {
  totalLocked: number; assetLabel: string; nativeAsset: boolean; connected: boolean; balances: WalletBalances | null | undefined; count: number
}) {
  if (!connected) return <Insight tone="neutral" icon={<Wallet size={15} />}>Connect a wallet to check it can cover this payroll</Insight>
  if (balances === undefined) return <Insight tone="neutral" icon={<Wallet size={15} />}>Checking your wallet…</Insight>
  if (balances === null) return <Insight tone="caution" icon={<TriangleAlert size={15} />}>This wallet isn’t funded on Testnet yet</Insight>
  // Each payout reserves 0.5 XLM per claimant, and Sweldo uses two.
  const reserves = count * 1
  const spendable = Math.max(0, balances.xlm - balances.reservedXlm)
  if (nativeAsset) {
    const need = totalLocked + reserves
    return spendable >= need
      ? <Insight tone="good" icon={<ShieldCheck size={15} />}>Your wallet covers it, {number.format(spendable - need)} XLM to spare</Insight>
      : <Insight tone="caution" icon={<TriangleAlert size={15} />}>Short by {number.format(need - spendable)} XLM, including {number.format(reserves)} XLM in payout reserves</Insight>
  }
  if (balances.asset < totalLocked) return <Insight tone="caution" icon={<TriangleAlert size={15} />}>Short by {number.format(totalLocked - balances.asset)} {assetLabel}</Insight>
  if (spendable < reserves) return <Insight tone="caution" icon={<TriangleAlert size={15} />}>Needs {number.format(reserves)} XLM for payout reserves; the wallet has {number.format(spendable)} free</Insight>
  return <Insight tone="good" icon={<ShieldCheck size={15} />}>Your wallet covers it, {number.format(balances.asset - totalLocked)} {assetLabel} to spare</Insight>
}

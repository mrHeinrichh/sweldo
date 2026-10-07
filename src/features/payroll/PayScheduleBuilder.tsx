import { useEffect, useRef, useState, type KeyboardEvent, type PointerEvent, type ReactNode } from 'react'
import {
  CalendarClock, CalendarDays, CalendarRange, Check, ChevronDown, GripVertical, Hourglass, Info, Layers, ShieldCheck,
  Sun, Timer, TriangleAlert, Wallet, Zap, type LucideIcon,
} from 'lucide-react'
import { CADENCE_ORDER, CADENCES, type Cadence } from '../../lib/schedule'
import { useAccount } from '../../state/account'
import { formatAmount } from '../../state/amount'
import { assetLabel, MAX_OPERATIONS, MAX_PAYOUTS_PER_EMPLOYEE, usesIssuedAsset } from '../../state/config'
import { usePayrollForm } from '../../state/payroll-form'
import { useWallet } from '../../state/wallet'
import { DatePickerDialog } from '../../ui/Dialog'
import { formatDateTime, formatShortDate, formatTime, plural } from '../../ui/format'
import { useNow, useUp } from '../../ui/hooks'

const CADENCE_ICON: Record<Cadence, LucideIcon> = { minute: Zap, day: Sun, week: CalendarRange, month: CalendarDays }
const phrase = (cadence: Cadence) => (cadence === 'minute' ? 'every minute' : `every ${CADENCES[cadence].unit}`)
const units = (cadence: Cadence, n: number) => `${n} ${plural(n, CADENCES[cadence].unit)}`
const DAY = 86_400_000

/**
 * The schedule as one smart, editable unit: a sentence whose parts are
 * controls, a track of payouts to drag, and presets. The checks that
 * follow from it live on the review step (`ScheduleInsights`).
 */
export function PayScheduleBuilder() {
  const form = usePayrollForm()
  const now = useNow()
  return (
    <div className="schedule-builder">
      <div data-tour="schedule-sentence"><ScheduleSentence now={now} /></div>
      <div data-tour="payout-track">
        <PayoutTrack payouts={form.state.payouts} capacity={form.capacity} paydays={form.paydays(now)} onChange={(payouts) => form.changeSchedule({ payouts })} />
      </div>
      <div data-tour="presets" className="presets-wrap"><Presets /></div>
    </div>
  )
}

/** Live checks of the plan against the calendar, the transaction limit and the wallet. */
export function ScheduleInsights({ children }: { children?: ReactNode }) {
  const now = useNow()
  return <div data-tour="insights"><Insights now={now}>{children}</Insights></div>
}

// ---------------------------------------------------------------------------
// The sentence: "Pay [every week], [6 times], starting [in 1 week]."

type TokenItem = { icon: LucideIcon; title: string; subtitle: string; onSelect: (() => void) | null; selected?: boolean }

function ScheduleSentence({ now }: { now: Date }) {
  const form = usePayrollForm()
  const { state } = form
  const cadence = state.cadence
  const first = form.firstPayday(now)
  const [picker, setPicker] = useState<'until' | 'start' | null>(null)

  const startLabel = state.firstPaydayAt
    ? `on ${formatShortDate(state.firstPaydayAt)}`
    : state.firstPaydayIn === 0 ? 'right away' : `in ${units(cadence, state.firstPaydayIn)}`

  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const interval = CADENCES[cadence].seconds * 1000

  return (
    <p className="schedule-sentence" aria-label={`Pay ${phrase(cadence)}, ${state.payouts} times, starting ${startLabel}`}>
      <span>Pay</span>
      <MenuToken
        label={phrase(cadence)}
        icon={CADENCE_ICON[cadence]}
        after=","
        items={CADENCE_ORDER.map((c) => ({
          icon: CADENCE_ICON[c],
          title: CADENCES[c].label,
          subtitle: CADENCES[c].hint,
          selected: c === cadence,
          onSelect: () => form.changeSchedule({ cadence: c }),
        }))}
      />
      <MenuToken
        label={state.payouts === 1 ? 'once' : `${state.payouts} times`}
        icon={Layers}
        after=","
        items={[
          ...[1, 3, 6, 12, 24].filter((n) => n <= form.capacity).map((n) => ({
            icon: Layers,
            title: n === 1 ? 'Once' : `${n} times`,
            subtitle: n === 1 ? 'A single payout' : `Last payday ${units(cadence, n - 1)} after the first`,
            selected: n === state.payouts,
            onSelect: () => form.changeSchedule({ payouts: n }),
          })),
          {
            icon: CalendarClock,
            title: 'Pay until a date…',
            subtitle: cadence === 'minute' ? 'Not for minute-by-minute demos' : 'Sweldo counts the paydays for you',
            onSelect: cadence === 'minute' ? null : () => setPicker('until'),
          },
        ]}
      />
      <span>starting</span>
      <MenuToken
        label={startLabel}
        icon={Timer}
        after="."
        items={[
          {
            icon: Zap, title: 'Right away', subtitle: 'The first payout is claimable once locked',
            selected: !state.firstPaydayAt && state.firstPaydayIn === 0,
            onSelect: () => form.changeSchedule({ firstPaydayIn: 0 }),
          },
          ...[1, 2, 3].map((n) => ({
            icon: Timer,
            title: `In ${units(cadence, n)}`,
            subtitle: formatDateTime(new Date(now.getTime() + interval * n)),
            selected: !state.firstPaydayAt && state.firstPaydayIn === n,
            onSelect: () => form.changeSchedule({ firstPaydayIn: n }),
          })),
          { icon: CalendarClock, title: 'On a date…', subtitle: 'Paydays start at 9:00 AM that day', selected: !!state.firstPaydayAt, onSelect: () => setPicker('start') },
        ]}
      />
      {picker === 'until' && (
        <DatePickerDialog
          helpText="Pay until"
          initialDate={form.paydays(now).at(-1) ?? first}
          firstDate={first}
          lastDate={new Date(new Date(first.getFullYear(), first.getMonth(), first.getDate()).getTime() + interval * form.capacity)}
          onCancel={() => setPicker(null)}
          onPick={(end) => {
            setPicker(null)
            const lastMoment = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59)
            const count = Math.floor((lastMoment.getTime() - first.getTime()) / 1000 / CADENCES[cadence].seconds) + 1
            form.changeSchedule({ payouts: Math.max(1, Math.min(form.capacity, count)) })
          }}
        />
      )}
      {picker === 'start' && (
        <DatePickerDialog
          helpText="First payday"
          initialDate={state.firstPaydayAt ?? new Date(today.getTime() + DAY)}
          firstDate={today}
          lastDate={new Date(today.getTime() + 730 * DAY)}
          onCancel={() => setPicker(null)}
          onPick={(picked) => {
            setPicker(null)
            if (picked.getTime() === today.getTime()) form.changeSchedule({ firstPaydayIn: 0 })
            else form.changeSchedule({ firstPaydayAt: new Date(picked.getFullYear(), picked.getMonth(), picked.getDate(), 9) })
          }}
        />
      )}
    </p>
  )
}

/** An editable part of the sentence: a pill that opens a menu. */
function MenuToken({ label, icon: Icon, items, after }: { label: string; icon: LucideIcon; items: TokenItem[]; after?: string }) {
  const [open, setOpen] = useState(false)
  const root = useRef<HTMLSpanElement>(null)
  useEffect(() => {
    if (!open) return
    const close = (event: MouseEvent) => { if (!root.current?.contains(event.target as Node)) setOpen(false) }
    const onKey = (event: globalThis.KeyboardEvent) => { if (event.key === 'Escape') setOpen(false) }
    document.addEventListener('mousedown', close)
    window.addEventListener('keydown', onKey)
    return () => { document.removeEventListener('mousedown', close); window.removeEventListener('keydown', onKey) }
  }, [open])

  return (
    <span className="token-wrap" ref={root}>
      <button type="button" className={`token ${open ? 'open' : ''}`} aria-haspopup="menu" aria-expanded={open} aria-label={`Change: ${label}`} onClick={() => setOpen((value) => !value)}>
        <Icon size={16} />
        <span key={label} className="token-label">{label}</span>
        <ChevronDown size={16} className="token-chevron" />
      </button>
      {after && <span>{after}</span>}
      {open && (
        <span className="token-menu" role="menu">
          {items.map((item) => {
            const ItemIcon = item.icon
            return (
              <button
                key={item.title}
                type="button"
                role="menuitem"
                className={`token-item ${item.selected ? 'selected' : ''}`}
                disabled={!item.onSelect}
                onClick={() => { setOpen(false); item.onSelect?.() }}
              >
                <ItemIcon size={18} className="token-item-icon" />
                <span className="token-item-text">
                  <span className="t-label">{item.title}</span>
                  <span className="t-caption">{item.subtitle}</span>
                </span>
                {item.selected && <Check size={16} className="token-item-check" />}
              </button>
            )
          })}
        </span>
      )}
    </span>
  )
}

// ---------------------------------------------------------------------------
// The track: one slot per possible payout, drag to set how many.

const SLOTS = MAX_PAYOUTS_PER_EMPLOYEE

function PayoutTrack({ payouts, capacity, paydays, onChange }: { payouts: number; capacity: number; paydays: Date[]; onChange: (n: number) => void }) {
  const box = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(600)
  const [dragging, setDragging] = useState(false)
  const [focused, setFocused] = useState(false)

  useEffect(() => {
    const node = box.current
    if (!node) return
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(node)
    return () => observer.disconnect()
  }, [])

  const setFrom = (clientX: number) => {
    const rect = box.current!.getBoundingClientRect()
    const pitch = rect.width / SLOTS
    const n = Math.max(1, Math.min(capacity, Math.floor((clientX - rect.left) / pitch) + 1))
    if (n !== payouts) onChange(n)
  }

  const onKey = (event: KeyboardEvent) => {
    let next: number | null = null
    if (event.key === 'ArrowRight' || event.key === 'ArrowUp') next = payouts + 1
    else if (event.key === 'ArrowLeft' || event.key === 'ArrowDown') next = payouts - 1
    else if (event.key === 'Home') next = 1
    else if (event.key === 'End') next = capacity
    if (next === null) return
    event.preventDefault()
    const clamped = Math.max(1, Math.min(capacity, next))
    if (clamped !== payouts) onChange(clamped)
  }

  const pitch = width / SLOTS
  const handleX = pitch * (payouts - 0.5)
  const bubbleWidth = 128
  const bubbleLeft = Math.max(0, Math.min(width - bubbleWidth, handleX - bubbleWidth / 2))
  const last = paydays.at(-1)
  const first = paydays[0]
  const gap = Math.min(1.5, pitch * 0.12)

  return (
    <div
      ref={box}
      className={`track ${dragging ? 'dragging' : ''}`}
      role="slider"
      tabIndex={0}
      aria-label="Payouts per employee"
      aria-valuemin={1}
      aria-valuemax={capacity}
      aria-valuenow={payouts}
      onKeyDown={onKey}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      onPointerDown={(event: PointerEvent<HTMLDivElement>) => {
        event.currentTarget.setPointerCapture(event.pointerId)
        setDragging(true)
        setFrom(event.clientX)
      }}
      onPointerMove={(event) => { if (dragging) setFrom(event.clientX) }}
      onPointerUp={() => setDragging(false)}
      onPointerCancel={() => setDragging(false)}
    >
      <div className="track-bubble" style={{ left: bubbleLeft, width: bubbleWidth }}>
        <div className="track-bubble-inner">
          <span className="t-label">{payouts === 1 ? '1 payout' : `${payouts} payouts`}</span>
          {last && <span className="t-caption">ends {formatShortDate(last)}</span>}
        </div>
      </div>
      <div className="track-slots">
        {Array.from({ length: SLOTS }, (_, k) => k + 1).map((i) => (
          <span key={i} className="track-slot-cell" style={{ padding: `0 ${gap}px` }}>
            <span className={`track-slot ${i > capacity ? 'locked' : i <= payouts ? (i === payouts ? 'filled edge' : 'filled') : ''}`} />
          </span>
        ))}
      </div>
      {capacity < SLOTS && <span className="track-limit" style={{ left: pitch * capacity - 1 }} />}
      <span className={`track-knob ${focused ? 'focused' : ''}`} style={{ left: handleX - 9 }}><GripVertical size={14} /></span>
      {first && <span className="t-caption track-start">Starts {formatShortDate(first)}</span>}
      <span className={`t-caption track-end ${capacity < SLOTS ? 'limited' : ''}`}>{capacity < SLOTS ? `Team limit ${capacity}` : `Up to ${SLOTS}`}</span>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Presets.

const PRESETS: { icon: LucideIcon; title: string; cadence: Cadence; payouts: number; firstIn: number }[] = [
  { icon: Zap, title: 'Live demo', cadence: 'minute', payouts: 3, firstIn: 1 },
  { icon: Sun, title: 'Daily for 2 weeks', cadence: 'day', payouts: 14, firstIn: 1 },
  { icon: CalendarRange, title: 'Weekly for a quarter', cadence: 'week', payouts: 13, firstIn: 1 },
  { icon: CalendarDays, title: 'Monthly for a year', cadence: 'month', payouts: 12, firstIn: 1 },
]

function Presets() {
  const form = usePayrollForm()
  const { state } = form
  const wrap = useUp('sm')
  return (
    <div className={`presets ${wrap ? 'wrap' : 'scroll'}`}>
      {PRESETS.map((preset) => {
        const payouts = Math.min(preset.payouts, form.capacity)
        const selected = state.cadence === preset.cadence && state.payouts === payouts && state.firstPaydayIn === preset.firstIn && !state.firstPaydayAt
        const Icon = selected ? Check : preset.icon
        return (
          <button
            key={preset.title}
            type="button"
            className={`preset sw-interactive ${selected ? 'selected' : ''}`}
            aria-pressed={selected}
            aria-label={`Preset: ${preset.title}`}
            onClick={() => form.changeSchedule({ cadence: preset.cadence, payouts, firstPaydayIn: preset.firstIn })}
          >
            <Icon size={15} />
            <span>{preset.title}</span>
          </button>
        )
      })}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Insights: what the plan means, checked against reality.

export type Tone = 'neutral' | 'good' | 'caution' | 'danger'

function Insights({ now, children }: { now: Date; children?: ReactNode }) {
  const form = usePayrollForm()
  const { state } = form
  const { session } = useWallet()
  const { balances } = useAccount()
  const paydays = form.paydays(now)
  const first = paydays[0]
  const last = paydays[paydays.length - 1]
  const cadence = state.cadence
  const count = form.balanceCount

  const coverage = (): ReactNode => {
    if (!session) return <InsightChip icon={Wallet} tone="neutral" text="Connect a wallet to check it can cover this payroll" />
    if (!balances) return <InsightChip icon={Wallet} tone="caution" text="This wallet isn’t funded on Testnet yet" />
    const total = Number(form.totalLockedUnits) / 1e7
    // Each payout reserves 0.5 XLM per claimant, and Sweldo uses two.
    const reserves = count * 1
    const spendableXlm = Math.max(0, balances.xlm - balances.reservedXlm)
    if (!usesIssuedAsset) {
      const need = total + reserves
      if (spendableXlm >= need) return <InsightChip icon={ShieldCheck} tone="good" text={`Your wallet covers it, ${formatAmount(spendableXlm - need)} XLM to spare`} />
      return <InsightChip icon={TriangleAlert} tone="caution" text={`Short by ${formatAmount(need - spendableXlm)} XLM, including ${formatAmount(reserves)} XLM in payout reserves`} />
    }
    if (balances.asset < total) return <InsightChip icon={TriangleAlert} tone="caution" text={`Short by ${formatAmount(total - balances.asset)} ${assetLabel}`} />
    if (spendableXlm < reserves) return <InsightChip icon={TriangleAlert} tone="caution" text={`Needs ${formatAmount(reserves)} XLM for payout reserves; the wallet has ${formatAmount(spendableXlm)} free`} />
    return <InsightChip icon={ShieldCheck} tone="good" text={`Your wallet covers it, ${formatAmount(balances.asset - total)} ${assetLabel} to spare`} />
  }

  return (
    <div className="insights">
      {children}
      <InsightChip icon={CalendarClock} tone="neutral" text={cadence === 'minute' ? `First payday ${formatTime(first)}` : `First payday ${formatDateTime(first)}`} />
      <InsightChip
        icon={Hourglass}
        tone="neutral"
        text={state.payouts === 1 ? 'One payout, nothing after it' : `Last payday ${formatShortDate(last)}, ${units(cadence, state.payouts - 1)} after the first`}
      />
      {form.overOperationLimit
        ? <InsightChip icon={TriangleAlert} tone="danger" text={`${count} payouts won’t fit one transaction (${MAX_OPERATIONS} max)`} actionLabel="Fit to one transaction" onAction={() => form.changeSchedule({ payouts: form.capacity })} />
        : <InsightChip icon={Layers} tone="neutral" text={`${count} of ${MAX_OPERATIONS} payouts in one signature`} />}
      {coverage()}
      {cadence === 'minute' && <InsightChip icon={Info} tone="neutral" text="Keep the pay page open to watch each payout unlock live" />}
      {cadence === 'month' && <InsightChip icon={Info} tone="neutral" text="Monthly means every 30 days, so paydays drift from calendar dates" />}
    </div>
  )
}

export function InsightChip({ icon: Icon, tone, text, actionLabel, onAction }: { icon: LucideIcon; tone: Tone; text: string; actionLabel?: string; onAction?: () => void }) {
  return (
    <span key={text} className={`insight tone-${tone}`}>
      <Icon size={15} />
      <span className="insight-text">{text}</span>
      {onAction && <button type="button" className="insight-action" onClick={onAction}>{actionLabel}</button>}
    </span>
  )
}

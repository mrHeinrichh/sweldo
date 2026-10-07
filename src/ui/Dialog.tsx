import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { ChevronLeft, ChevronRight } from 'lucide-react'

/** A Material-style modal dialog: scrim, centered surface, Escape to close. */
export function Dialog({ onClose, children, label, className = '' }: { onClose: () => void; children: ReactNode; label: string; className?: string }) {
  const surface = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    const previous = document.activeElement as HTMLElement | null
    surface.current?.focus()
    return () => { window.removeEventListener('keydown', onKey); previous?.focus?.() }
  }, [onClose])
  return createPortal(
    <div className="sw-dialog-layer">
      <div className="sw-sheet-scrim" onClick={onClose} />
      <div ref={surface} className={`sw-dialog ${className}`} role="dialog" aria-modal="true" aria-label={label} tabIndex={-1}>
        {children}
      </div>
    </div>,
    document.body,
  )
}

/** AlertDialog: a title, a sentence, and actions on the right. */
export function AlertDialog({ title, body, actions, onClose }: { title: string; body: string; actions: ReactNode; onClose: () => void }) {
  return (
    <Dialog onClose={onClose} label={title} className="sw-alert">
      <h2 className="t-title m0">{title}</h2>
      <p className="t-body m0 sw-alert-body">{body}</p>
      <div className="sw-alert-actions">{actions}</div>
    </Dialog>
  )
}

const WEEKDAYS = ['S', 'M', 'T', 'W', 'T', 'F', 'S']
const monthFormat = new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' })
const headlineFormat = new Intl.DateTimeFormat('en-US', { weekday: 'short', month: 'short', day: 'numeric' })

const dateOnly = (value: Date) => new Date(value.getFullYear(), value.getMonth(), value.getDate())
const sameDay = (a: Date, b: Date) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()

/** Material 3's calendar date picker (Flutter's showDatePicker). */
export function DatePickerDialog({ helpText, initialDate, firstDate, lastDate, onCancel, onPick }: {
  helpText: string; initialDate: Date; firstDate: Date; lastDate: Date; onCancel: () => void; onPick: (date: Date) => void
}) {
  const first = useMemo(() => dateOnly(firstDate), [firstDate])
  const last = useMemo(() => dateOnly(lastDate), [lastDate])
  const [selected, setSelected] = useState(() => dateOnly(initialDate))
  const [month, setMonth] = useState(() => new Date(selected.getFullYear(), selected.getMonth(), 1))
  const today = dateOnly(new Date())

  const days: Array<Date | null> = []
  const lead = month.getDay()
  for (let i = 0; i < lead; i += 1) days.push(null)
  const count = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
  for (let day = 1; day <= count; day += 1) days.push(new Date(month.getFullYear(), month.getMonth(), day))

  const canBack = new Date(month.getFullYear(), month.getMonth(), 0) >= first
  const canForward = new Date(month.getFullYear(), month.getMonth() + 1, 1) <= last

  return (
    <Dialog onClose={onCancel} label={helpText} className="sw-date">
      <div className="sw-date-header">
        <span className="sw-date-help">{helpText}</span>
        <span className="sw-date-headline">{headlineFormat.format(selected)}</span>
      </div>
      <div className="sw-date-divider" />
      <div className="sw-date-nav">
        <span className="sw-date-month">{monthFormat.format(month)}</span>
        <span className="sw-date-arrows">
          <button type="button" aria-label="Previous month" disabled={!canBack} onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() - 1, 1))}><ChevronLeft size={24} /></button>
          <button type="button" aria-label="Next month" disabled={!canForward} onClick={() => setMonth(new Date(month.getFullYear(), month.getMonth() + 1, 1))}><ChevronRight size={24} /></button>
        </span>
      </div>
      <div className="sw-date-grid" role="grid">
        {WEEKDAYS.map((day, index) => <span key={index} className="sw-date-weekday">{day}</span>)}
        {days.map((day, index) => {
          if (!day) return <span key={`blank${index}`} />
          const disabled = day < first || day > last
          const isSelected = sameDay(day, selected)
          return (
            <button
              key={day.toISOString()}
              type="button"
              className={`sw-date-day ${isSelected ? 'selected' : ''} ${sameDay(day, today) ? 'today' : ''}`}
              disabled={disabled}
              aria-pressed={isSelected}
              onClick={() => setSelected(day)}
            >
              {day.getDate()}
            </button>
          )
        })}
      </div>
      <div className="sw-date-actions">
        <button type="button" className="text-button" onClick={onCancel}>Cancel</button>
        <button type="button" className="text-button" onClick={() => onPick(selected)}>OK</button>
      </div>
    </Dialog>
  )
}

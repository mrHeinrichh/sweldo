import { createContext, useCallback, useContext, useEffect, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { ArrowLeft, ArrowRight, Check, Compass, Pointer, X } from 'lucide-react'
import { navigate, useLocation } from '../../app/router'
import { Button } from '../../ui/Button'
import { useReducedMotion, useWidth } from '../../ui/hooks'
import { ensureVisible } from '../../ui/scroll'
import { SWELDO_TOUR, type TourStep } from './steps'
import './tour.css'

// The highlighting guide: dims the app except for a hole around the current
// target, so the control stays usable, and explains it in a card beside it.

const SEEN_KEY = 'sweldo-tour-seen-v1'

type TourApi = {
  isOpen: boolean
  index: number
  step: TourStep
  steps: TourStep[]
  isLast: boolean
  start: () => void
  next: () => void
  back: () => void
  finish: () => void
}

const TourContext = createContext<TourApi | null>(null)

function seen() {
  try { return localStorage.getItem(SEEN_KEY) === '1' } catch { return false }
}

export function TourProvider({ children, autoStart = true }: { children: ReactNode; autoStart?: boolean }) {
  const [open, setOpen] = useState(false)
  const [index, setIndex] = useState(0)
  const direction = useRef(1)
  const steps = SWELDO_TOUR

  const finish = useCallback(() => {
    setOpen(false)
    try { localStorage.setItem(SEEN_KEY, '1') } catch { /* ignore */ }
  }, [])
  const start = useCallback(() => {
    // The guide takes focus from whatever opened it, as Flutter's overlay does.
    ;(document.activeElement as HTMLElement | null)?.blur?.()
    direction.current = 1
    setIndex(0)
    setOpen(true)
  }, [])
  const next = useCallback(() => {
    direction.current = 1
    setIndex((current) => {
      if (current >= steps.length - 1) { finish(); return current }
      return current + 1
    })
  }, [finish, steps.length])
  const back = useCallback(() => {
    direction.current = -1
    setIndex((current) => Math.max(0, current - 1))
  }, [])

  // First visit: offer the guide once.
  useEffect(() => {
    if (!autoStart || seen()) return
    const timer = window.setTimeout(() => setOpen((already) => { if (!already) setIndex(0); return true }), 1200)
    return () => window.clearTimeout(timer)
  }, [autoStart])

  const api = useMemo<TourApi>(() => ({
    isOpen: open, index, step: steps[index], steps, isLast: index === steps.length - 1, start, next, back, finish,
  }), [open, index, steps, start, next, back, finish])

  return (
    <TourContext.Provider value={api}>
      {children}
      {open && <TourOverlay api={api} skip={() => (direction.current > 0 ? next() : back())} />}
    </TourContext.Provider>
  )
}

export function useTour() {
  const value = useContext(TourContext)
  if (!value) throw new Error('useTour needs a TourProvider.')
  return value
}

type Hole = { top: number; left: number; width: number; height: number }

function TourOverlay({ api, skip }: { api: TourApi; skip: () => void }) {
  const { step, index, steps } = api
  const path = useLocation()
  const width = useWidth()
  const reduced = useReducedMotion()
  const [hole, setHole] = useState<Hole | null>(null)
  const [ready, setReady] = useState(false)
  const cardRef = useRef<HTMLDivElement>(null)
  const [cardHeight, setCardHeight] = useState(230)

  // Show the step: open its page, wait for the target, scroll it into view.
  useEffect(() => {
    let cancelled = false
    setReady(false)
    if (!step.target) setHole(null)
    if (step.route && path !== step.route) navigate(step.route)
    if (!step.target) {
      setReady(true)
      return
    }
    void (async () => {
      let element: Element | null = null
      for (let attempt = 0; attempt < 40; attempt += 1) {
        await new Promise((resolve) => window.setTimeout(resolve, 40))
        if (cancelled) return
        element = document.querySelector(`[data-tour="${step.target}"]`)
        if (element) break
      }
      if (!element) { skip(); return }
      ensureVisible(element, 0.35, !reduced)
      await new Promise((resolve) => window.setTimeout(resolve, reduced ? 0 : 400))
      if (!cancelled) setReady(true)
    })()
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [index])

  // Follow the target every frame, as it moves with scrolling and layout.
  useEffect(() => {
    if (!step.target) return
    let frame = 0
    const measure = () => {
      const element = document.querySelector(`[data-tour="${step.target}"]`)
      if (element) {
        const rect = element.getBoundingClientRect()
        const next = { top: rect.top - 8, left: rect.left - 8, width: rect.width + 16, height: rect.height + 16 }
        setHole((previous) => (previous
          && Math.abs(previous.top - next.top) < 0.5 && Math.abs(previous.left - next.left) < 0.5
          && Math.abs(previous.width - next.width) < 0.5 && Math.abs(previous.height - next.height) < 0.5
          ? previous : next))
      }
      frame = requestAnimationFrame(measure)
    }
    frame = requestAnimationFrame(measure)
    return () => cancelAnimationFrame(frame)
  }, [step.target])

  useLayoutEffect(() => {
    if (cardRef.current) setCardHeight(cardRef.current.offsetHeight)
  }, [index, ready, width])

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'ArrowRight') api.next()
      else if (event.key === 'ArrowLeft') api.back()
      else if (event.key === 'Escape') api.finish()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [api])

  const viewportW = window.innerWidth
  const viewportH = window.innerHeight
  const shownHole = step.target ? hole : null
  const compact = width < 640

  let cardStyle: React.CSSProperties
  if (compact) {
    cardStyle = { left: 12, right: 12, bottom: 12 }
  } else if (!shownHole) {
    cardStyle = { left: '50%', top: '50%', width: 420, transform: 'translate(-50%, -50%)' }
  } else {
    const below = shownHole.top + shownHole.height + 14
    const top = below + cardHeight < viewportH - 12 ? below : Math.max(12, shownHole.top - cardHeight - 14)
    const left = Math.min(Math.max(12, shownHole.left + shownHole.width / 2 - 180), Math.max(12, viewportW - 360 - 12))
    cardStyle = { top, left, width: 360 }
  }

  return (
    <div className="tour" role="dialog" aria-modal="true" aria-label={`Guide, step ${index + 1} of ${steps.length}`}>
      {shownHole ? (
        <>
          <div className="tour-shade" style={{ top: 0, left: 0, width: '100%', height: Math.max(0, shownHole.top) }} />
          <div className="tour-shade" style={{ top: shownHole.top + shownHole.height, left: 0, width: '100%', bottom: 0 }} />
          <div className="tour-shade" style={{ top: shownHole.top, left: 0, width: Math.max(0, shownHole.left), height: shownHole.height }} />
          <div className="tour-shade" style={{ top: shownHole.top, left: shownHole.left + shownHole.width, right: 0, height: shownHole.height }} />
          <div className="tour-ring" style={{ top: shownHole.top, left: shownHole.left, width: shownHole.width, height: shownHole.height }} />
        </>
      ) : (
        <div className="tour-shade full" />
      )}
      <div ref={cardRef} key={index} className={`tour-card ${ready ? 'ready' : ''} ${compact ? 'compact' : ''}`} style={cardStyle} aria-live="polite">
        <div className="tour-card-head">
          <Compass size={14} />
          <span>{index + 1} of {steps.length}</span>
          <button type="button" className="tour-close" onClick={api.finish} aria-label="Close the guide" title="Close the guide"><X size={16} /></button>
        </div>
        <div className="tour-progress"><span style={{ width: `${((index + 1) / steps.length) * 100}%` }} /></div>
        <h2 className="tour-title">{step.title}</h2>
        <p className="t-body-sm m0">{step.body}</p>
        {step.tryIt && (
          <div className="tour-try"><Pointer size={15} /><span>{step.tryIt}</span></div>
        )}
        <div className="tour-actions">
          {index === 0
            ? <Button label="Skip" tone="secondary" onClick={api.finish} />
            : <Button label="Back" icon={<ArrowLeft />} tone="secondary" onClick={api.back} />}
          <Button label={api.isLast ? 'Done' : 'Next'} icon={api.isLast ? <Check /> : <ArrowRight />} onClick={api.next} />
        </div>
      </div>
    </div>
  )
}

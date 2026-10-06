import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { ArrowLeft, ArrowRight, Check, Compass, X } from 'lucide-react'
import './GuidedTour.css'

export type TourStep<V extends string = string> = {
  /** CSS selector for the element to spotlight; omit for a centred card. */
  target?: string
  title: string
  body: string
  /** Page to show before this step. */
  view?: V
  /** Invite the person to use the highlighted control during the step. */
  tryIt?: string
}

type Props<V extends string> = {
  open: boolean
  steps: TourStep<V>[]
  onClose: (finished: boolean) => void
  onNavigate: (view: V) => void
}

type Box = { top: number; left: number; width: number; height: number }

const PAD = 8
const CARD_WIDTH = 340

function waitFor(selector: string, timeout = 1500): Promise<HTMLElement | null> {
  return new Promise((resolve) => {
    const started = performance.now()
    const look = () => {
      const element = document.querySelector<HTMLElement>(selector)
      if (element && element.getBoundingClientRect().height > 0) return resolve(element)
      if (performance.now() - started > timeout) return resolve(null)
      requestAnimationFrame(look)
    }
    look()
  })
}

/**
 * A highlighting guide: dims the page, spotlights one control at a time and
 * explains it. The spotlight is a real hole, so the highlighted control stays
 * usable while the guide is open.
 */
export function GuidedTour<V extends string>({ open, steps, onClose, onNavigate }: Props<V>) {
  const [index, setIndex] = useState(0)
  const [box, setBox] = useState<Box | null>(null)
  const [ready, setReady] = useState(false)
  const target = useRef<HTMLElement | null>(null)
  const direction = useRef<1 | -1>(1)
  const card = useRef<HTMLDivElement>(null)
  const step = steps[index]

  const finish = useCallback((done: boolean) => {
    setIndex(0)
    setBox(null)
    target.current = null
    onClose(done)
  }, [onClose])

  const move = useCallback((delta: 1 | -1) => {
    direction.current = delta
    setIndex((current) => {
      const next = current + delta
      if (next >= steps.length) { window.setTimeout(() => finish(true)); return current }
      return Math.max(0, next)
    })
  }, [steps.length, finish])

  // Show the step: switch page, find the element, bring it into view.
  useEffect(() => {
    if (!open || !step) return
    let cancelled = false
    setReady(false)
    if (step.view) onNavigate(step.view)
    if (!step.target) {
      target.current = null
      setBox(null)
      setReady(true)
      return
    }
    waitFor(step.target).then((element) => {
      if (cancelled) return
      if (!element) {
        // This step doesn't apply right now (for example, no wallet yet).
        move(direction.current)
        return
      }
      target.current = element
      element.scrollIntoView({ block: 'center', behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' })
      window.setTimeout(() => { if (!cancelled) setReady(true) }, 350)
    })
    return () => { cancelled = true }
  }, [open, index, step, onNavigate, move])

  // Follow the element as the page scrolls, resizes or re-renders.
  useLayoutEffect(() => {
    if (!open) return
    let frame = 0
    const track = () => {
      const element = target.current
      if (element) {
        const r = element.getBoundingClientRect()
        setBox((previous) => {
          const next = { top: r.top - PAD, left: r.left - PAD, width: r.width + PAD * 2, height: r.height + PAD * 2 }
          return previous && Math.abs(previous.top - next.top) < 0.5 && Math.abs(previous.left - next.left) < 0.5
            && Math.abs(previous.width - next.width) < 0.5 && Math.abs(previous.height - next.height) < 0.5 ? previous : next
        })
      }
      frame = requestAnimationFrame(track)
    }
    frame = requestAnimationFrame(track)
    return () => cancelAnimationFrame(frame)
  }, [open])

  useEffect(() => {
    if (!open) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') finish(false)
      if (event.key === 'ArrowRight') move(1)
      if (event.key === 'ArrowLeft') move(-1)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, finish, move])

  useEffect(() => {
    if (open && ready) card.current?.focus({ preventScroll: true })
  }, [open, ready, index])

  if (!open || !step) return null

  const vw = window.innerWidth
  const vh = window.innerHeight
  const compact = vw < 640
  const spot = step.target ? box : null

  // Place the card under the spotlight, or above it when there's no room.
  let cardStyle: React.CSSProperties = {}
  if (!compact && spot) {
    const below = spot.top + spot.height + 14
    const cardHeight = card.current?.offsetHeight ?? 220
    const top = below + cardHeight < vh - 12 ? below : Math.max(12, spot.top - cardHeight - 14)
    const left = Math.min(Math.max(12, spot.left + spot.width / 2 - CARD_WIDTH / 2), vw - CARD_WIDTH - 12)
    cardStyle = { top, left, width: CARD_WIDTH }
  }

  const last = index === steps.length - 1
  return (
    <div className="tour" role="dialog" aria-modal="true" aria-labelledby="tour-title">
      {spot ? <>
        <div className="tour-shade" style={{ top: 0, left: 0, right: 0, height: Math.max(0, spot.top) }} />
        <div className="tour-shade" style={{ top: spot.top + spot.height, left: 0, right: 0, bottom: 0 }} />
        <div className="tour-shade" style={{ top: spot.top, left: 0, width: Math.max(0, spot.left), height: spot.height }} />
        <div className="tour-shade" style={{ top: spot.top, left: spot.left + spot.width, right: 0, height: spot.height }} />
        <div className="tour-ring" style={{ top: spot.top, left: spot.left, width: spot.width, height: spot.height }} />
      </> : <div className="tour-shade" style={{ inset: 0 }} />}

      <div
        ref={card}
        key={index}
        tabIndex={-1}
        className={`tour-card ${compact ? 'sheet' : ''} ${!spot ? 'centered' : ''} ${ready ? 'ready' : ''}`}
        style={cardStyle}
      >
        <div className="tour-top">
          <span className="tour-step"><Compass size={14} /> {index + 1} of {steps.length}</span>
          <button type="button" className="tour-skip" onClick={() => finish(false)} aria-label="Close the guide"><X size={16} /></button>
        </div>
        <div className="tour-progress"><i style={{ width: `${((index + 1) / steps.length) * 100}%` }} /></div>
        <h3 id="tour-title">{step.title}</h3>
        <p>{step.body}</p>
        {step.tryIt && <p className="tour-try">{step.tryIt}</p>}
        <div className="tour-actions">
          {index > 0 && <button type="button" className="button button-ghost" onClick={() => move(-1)}><ArrowLeft size={15} /> Back</button>}
          {index === 0 && <button type="button" className="button button-ghost" onClick={() => finish(false)}>Skip</button>}
          <button type="button" className="button button-primary" onClick={() => (last ? finish(true) : move(1))}>
            {last ? <><Check size={15} /> Done</> : <>Next <ArrowRight size={15} /></>}
          </button>
        </div>
      </div>
    </div>
  )
}

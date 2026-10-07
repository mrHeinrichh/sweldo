import { useEffect, useRef, useState, type CSSProperties, type PointerEvent, type ReactNode } from 'react'
import { easeInOutCubic } from './curves'
import { useReducedMotion } from './hooks'

/** Tailwind's `animate-ping`: a solid dot with a ring that keeps radiating. */
export function PingDot({ color = 'var(--payday)', size = 8 }: { color?: string; size?: number }) {
  return (
    <span className="sw-ping" style={{ width: size, height: size, ['--ping' as string]: color }} aria-hidden>
      <span />
      <span />
    </span>
  )
}

/** Tailwind's `animate-pulse` placeholder for content that is loading. */
export function Skeleton({ width = '100%', height, radius = 6 }: { width?: number | string; height: number; radius?: number }) {
  return <span className="sw-skeleton" style={{ width, height, borderRadius: radius }} aria-hidden />
}

/** A card with two faces that turns over in 3D when `flipped` changes. */
export function FlipCard({ front, back, flipped, vertical, duration = 700 }: {
  front: ReactNode; back: ReactNode; flipped: boolean; vertical?: boolean; duration?: number
}) {
  const angle = useTween(flipped ? Math.PI : 0, duration, easeInOutCubic)
  const showBack = angle > Math.PI / 2
  // Lift toward the viewer mid-turn, so the card reads as an object.
  const lift = 1 + Math.sin(angle) * 0.06
  const turn = vertical ? `rotateX(${-angle}rad)` : `rotateY(${-angle}rad)`
  return (
    <div className="sw-flip" style={{ transform: `perspective(714px) ${turn} scale(${lift})` }}>
      <div className="sw-flip-face" style={showBack ? { transform: vertical ? 'rotateX(180deg)' : 'rotateY(180deg)' } : undefined}>
        {showBack ? back : front}
      </div>
    </div>
  )
}

/** Fades and rises a section into place the first time it scrolls into view. */
export function Reveal({ children, delay = 0, className = '' }: { children: ReactNode; delay?: number; className?: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const reduced = useReducedMotion()
  const [shown, setShown] = useState(false)
  useEffect(() => {
    const node = ref.current
    if (!node || shown) return
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.intersectionRatio >= 0.12)) {
        window.setTimeout(() => setShown(true), delay)
        observer.disconnect()
      }
    }, { threshold: [0, 0.12, 0.5] })
    observer.observe(node)
    return () => observer.disconnect()
  }, [delay, shown])
  return <div ref={ref} className={`sw-reveal ${shown || reduced ? 'shown' : ''} ${className}`}>{children}</div>
}

/** Whether `node` has scrolled into view (fraction ≥ threshold). */
export function useInView<T extends Element>(threshold = 0.3) {
  const ref = useRef<T>(null)
  const [inView, setInView] = useState(false)
  useEffect(() => {
    const node = ref.current
    if (!node) return
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) setInView(entry.intersectionRatio >= threshold)
    }, { threshold: [0, threshold, 1] })
    observer.observe(node)
    return () => observer.disconnect()
  }, [threshold])
  return [ref, inView] as const
}

/**
 * Turns its child in 3D toward the pointer, with a soft glare that slides
 * across the surface, then springs back when the pointer leaves.
 */
export function Tilt3D({ children, maxTilt = 10, baseX = 0, baseY = 0, perspective = 833, glare = true, radius = 6, className = '', style }: {
  children: ReactNode; maxTilt?: number; baseX?: number; baseY?: number; perspective?: number
  glare?: boolean; radius?: number; className?: string; style?: CSSProperties
}) {
  const reduced = useReducedMotion()
  const [pointer, setPointer] = useState({ x: 0, y: 0, settle: false })
  const engaged = useRef(false)

  function aim(event: PointerEvent<HTMLDivElement>) {
    const rect = event.currentTarget.getBoundingClientRect()
    const x = Math.max(-1, Math.min(1, ((event.clientX - rect.left) / rect.width) * 2 - 1))
    const y = Math.max(-1, Math.min(1, ((event.clientY - rect.top) / rect.height) * 2 - 1))
    setPointer({ x, y, settle: false })
  }
  function release() {
    engaged.current = false
    setPointer({ x: 0, y: 0, settle: true })
  }

  const p = reduced ? { x: 0, y: 0, settle: false } : pointer
  // Flutter's z axis points away from the viewer and CSS's toward it, so
  // X and Y rotations take the opposite sign to look the same.
  const transform = `perspective(${perspective}px) rotateX(${-(baseX - p.y * maxTilt)}deg) rotateY(${-(baseY + p.x * maxTilt)}deg)`
  const distance = Math.min(1, Math.hypot(p.x, p.y))
  return (
    <div
      className={`sw-tilt ${p.settle ? 'settle' : ''} ${className}`}
      style={{ transform, ...style }}
      onPointerMove={(event) => { if (event.pointerType === 'mouse' || engaged.current) aim(event) }}
      onPointerDown={(event) => { engaged.current = true; aim(event) }}
      onPointerUp={release}
      onPointerCancel={release}
      onPointerLeave={release}
    >
      {children}
      {glare && !reduced && (
        <span
          className="sw-tilt-glare"
          style={{
            borderRadius: radius,
            background: `radial-gradient(circle at ${(p.x + 1) * 50}% ${(p.y + 1) * 50}%, rgba(255,255,255,${0.22 * distance}), rgba(255,255,255,0) 70%)`,
          }}
        />
      )}
    </div>
  )
}

/** Animates a number toward `target` (Flutter's TweenAnimationBuilder). */
export function useTween(target: number, duration: number, curve: (t: number) => number = (t) => t) {
  const reduced = useReducedMotion()
  const [value, setValue] = useState(target)
  const current = useRef(target)
  useEffect(() => {
    if (reduced || duration <= 0) {
      current.current = target
      setValue(target)
      return
    }
    const begin = current.current
    if (begin === target) return
    const started = performance.now()
    let frame = 0
    const tick = (now: number) => {
      const t = Math.min(1, (now - started) / duration)
      const next = begin + (target - begin) * curve(t)
      current.current = next
      setValue(next)
      if (t < 1) frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target, duration, reduced])
  return value
}

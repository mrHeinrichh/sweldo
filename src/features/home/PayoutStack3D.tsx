import { useEffect, useRef, useState } from 'react'
import { CalendarClock, ChevronDown, Layers, LockKeyhole } from 'lucide-react'
import { clamp, easeInOutCubic, easeOutCubic, lerp } from '../../ui/curves'
import { useTween } from '../../ui/Motion'

const PAYDAYS = ['Nov 3', 'Dec 3', 'Jan 3', 'Feb 3', 'Mar 3', 'Apr 3']

/**
 * Six locked payouts as a 3D pile. Hovering (or tapping on touch) spreads
 * them into a grid so each payday can be read; leaving stacks them again.
 */
export function PayoutStack3D({ assetLabel }: { assetLabel: string }) {
  const [hovering, setHovering] = useState(false)
  const [pinned, setPinned] = useState(false)
  const open = hovering || pinned
  const t = useTween(open ? 1 : 0, 750, easeInOutCubic)
  const box = useRef<HTMLButtonElement>(null)
  const [width, setWidth] = useState(480)

  useEffect(() => {
    const node = box.current
    if (!node) return
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(node)
    return () => observer.disconnect()
  }, [])

  const w = 176
  const h = 116
  const columns = width < 480 ? 2 : 3
  const rows = Math.ceil(PAYDAYS.length / columns)
  const gapX = Math.min(196, (width - w) / Math.max(1, columns - 1))

  return (
    <div className="stack3d">
      <button
        ref={box}
        type="button"
        className="stack3d-stage"
        aria-label={open ? 'Stack the six payouts' : 'Spread the six payouts'}
        onPointerEnter={(event) => { if (event.pointerType === 'mouse') setHovering(true) }}
        onPointerLeave={(event) => { if (event.pointerType === 'mouse') setHovering(false) }}
        onClick={() => setPinned((value) => !value)}
      >
        {PAYDAYS.map((payday, i) => {
          const col = i % columns
          const row = Math.floor(i / columns)
          // Stacked: a leaning pile seen from above. Spread: a tidy grid.
          const spreadX = (col - (columns - 1) / 2) * gapX
          const spreadY = (row - (rows - 1) / 2) * (h + 16)
          // Each ticket leaves the pile slightly after the one below it.
          const local = easeOutCubic(clamp(t * 1.4 - i * 0.08, 0, 1))
          const x = lerp(0, spreadX, local)
          const y = lerp(46 - i * 15, spreadY, local)
          const rotX = lerp(0.98, 0.22, local)
          const rotZ = lerp(-0.62 + i * 0.03, -0.04, local)
          return (
            <div
              key={payday}
              className="stack3d-ticket"
              style={{
                width: w,
                height: h,
                marginLeft: -w / 2,
                marginTop: -h / 2,
                transform: `perspective(909px) translate(${x}px, ${y}px) rotateX(${-rotX}rad) rotateZ(${rotZ}rad)`,
                boxShadow: `0 ${10 - 4 * local}px 18px -4px rgba(20, 33, 58, ${0.1 + 0.06 * (1 - local)})`,
              }}
            >
              <div className="stack3d-ticket-head">
                <CalendarClock size={14} />
                <span className="t-label">{payday}</span>
                <LockKeyhole size={16} className="stack3d-lock" />
              </div>
              <div className="t-amount" style={{ fontSize: 22 }}>300 {assetLabel}</div>
            </div>
          )
        })}
      </button>
      <div className="stack3d-hint" key={String(open)}>
        {open ? <Layers size={14} /> : <ChevronDown size={14} />}
        <span className="t-caption">{open ? 'Six paydays, each locked until its date' : 'Hover or tap to spread the payouts'}</span>
      </div>
    </div>
  )
}

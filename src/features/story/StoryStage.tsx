import { useLayoutEffect, useRef, useState } from 'react'
import { LockKeyhole } from 'lucide-react'
import { stampCurve } from '../../ui/curves'
import { FRAME, IPhoneFrame, SCREEN } from './IPhoneFrame'
import { ConvertScreen, EmployerScreen, WorkerScreen } from './PhoneScreens'
import { easeBack, easeInOut, easeOut, SCENES, seg, type StoryScene } from './script'

/** Fixed-size stages, scaled to fit by the player. */
export const STAGE = {
  landscape: { width: 1280, height: 720 },
  portrait: { width: 720, height: 1080 },
}
export type StageFormat = keyof typeof STAGE

/**
 * One frame of the story at time g (seconds). The film is printed on
 * continuous-form payroll paper: lines print in, and between scenes the
 * paper feeds up to make room for the next.
 */
export function StoryStage({ g, format }: { g: number; format: StageFormat }) {
  const size = STAGE[format]
  const landscape = format === 'landscape'
  let feed = 0
  for (const scene of SCENES.slice(1)) feed += 96 * easeInOut(seg(g, scene.start - 0.5, scene.start))

  return (
    <div className="stage" style={{ width: size.width, height: size.height }}>
      <PaperBackground feed={feed} width={size.width} height={size.height} />
      {SCENES.map((scene, index) => <SceneWords key={index} scene={scene} index={index} g={g} landscape={landscape} />)}
      <LatePayslip g={g} landscape={landscape} />
      <Ledger g={g} landscape={landscape} />
      <Phone g={g} landscape={landscape} />
    </div>
  )
}

function PaperBackground({ feed, width, height }: { feed: number; width: number; height: number }) {
  const band = 48
  const margin = 34
  const bands: number[] = []
  for (let y = -(feed % (band * 2)); y < height; y += band * 2) bands.push(y)
  const holes: number[] = []
  for (let y = -(feed % 24) + 12; y < height; y += 24) holes.push(y)
  return (
    <svg className="stage-paper" width={width} height={height} aria-hidden>
      <rect width={width} height={height} fill="#F2F5F0" />
      {bands.map((y) => <rect key={`b${y}`} x={margin} y={y} width={width - margin * 2} height={band} fill="rgba(225, 235, 221, .7)" />)}
      {holes.map((y) => [margin / 2, width - margin / 2].map((x) => (
        <circle key={`h${x}-${y}`} cx={x} cy={y} r={5} fill="#fff" stroke="#D2DBCF" strokeWidth={1.2} />
      )))}
      {[margin, width - margin].map((x) => (
        <line key={`p${x}`} x1={x} y1={0} x2={x} y2={height} stroke="#D2DBCF" strokeWidth={1} strokeDasharray="4 4" />
      ))}
    </svg>
  )
}

/** A scene's lines, printed one after another with a print head running along each. */
function SceneWords({ scene, index, g, landscape }: { scene: StoryScene; index: number; g: number; landscape: boolean }) {
  if (g < scene.start - 0.01 || g > scene.end + 0.01) return null
  const outro = index === SCENES.length - 1
  // Last scene holds its words on screen.
  const exit = outro ? 0 : easeInOut(seg(g, scene.end - 0.5, scene.end))
  const first = landscape ? 58 : 56
  const rest = landscape ? 40 : 38
  const left = landscape ? 88 : 64
  const top = landscape ? (outro ? 200 : 170) : 92
  const width = landscape ? (outro ? 1000 : 600) : 600

  return (
    <div className="stage-words" style={{ left, top, width, transform: `translateY(${-140 * exit}px)`, opacity: 1 - exit }}>
      {scene.lines.map((text, i) => {
        const a = scene.start + 0.25 + i * 0.75
        const printed = seg(g, a, a + 0.6)
        const quiet = i >= scene.quietFrom
        const fontSize = outro ? (i === 0 ? (landscape ? 120 : 104) : (landscape ? 44 : 32)) : (quiet ? rest : first)
        return (
          <PrintedLine
            key={i}
            text={text}
            printed={printed}
            fontSize={fontSize}
            style={{
              fontSize,
              lineHeight: 1.06,
              letterSpacing: fontSize > 80 ? -4 : -1.6,
              color: quiet ? 'var(--ink-muted)' : 'var(--ink)',
              fontWeight: quiet ? 700 : 800,
            }}
          />
        )
      })}
    </div>
  )
}

function PrintedLine({ text, printed, fontSize, style }: { text: string; printed: number; fontSize: number; style: React.CSSProperties }) {
  const inner = useRef<HTMLSpanElement>(null)
  const [natural, setNatural] = useState<number | null>(null)
  const visible = printed > 0
  useLayoutEffect(() => {
    const measure = () => { if (inner.current) setNatural(inner.current.offsetWidth) }
    measure()
    // Webfonts can land after the first measurement.
    document.fonts?.ready.then(measure)
  }, [text, fontSize, visible])
  if (printed <= 0) return <div style={{ height: fontSize * 1.06, marginBottom: 6 }} />
  const printing = printed < 1
  return (
    <div className="stage-line">
      <span className="stage-line-clip" style={natural === null ? { clipPath: `inset(-20% ${(1 - printed) * 100}% -20% 0)` } : { width: natural * printed }}>
        <span ref={inner} className="stage-line-text" style={{ ...style, transform: `translateY(${6 * (1 - easeOut(printed))}px)` }}>{text}</span>
      </span>
      {printing && <span className="stage-print-head" style={{ height: fontSize * 0.9 }} />}
    </div>
  )
}

/** Scene 1: the old way. A payslip arrives, its payday slips, and it gets stamped late. */
function LatePayslip({ g, landscape }: { g: number; landscape: boolean }) {
  const s = SCENES[0]
  if (g < s.start + 0.6 || g > s.end + 0.05) return null
  const enter = easeBack(seg(g, s.start + 0.6, s.start + 1.3))
  const slip = easeOut(seg(g, 2.4, 2.9))
  const stamp = seg(g, 2.9, 3.4)
  const exit = easeInOut(seg(g, s.end - 0.5, s.end))
  const w = 380
  const h = 236
  const left = landscape ? 930 - w / 2 : (720 - w) / 2
  const top = landscape ? 230 : 430
  // Ink fades from ink to faint as the payday slips.
  const mix = (a: number[], b: number[]) => a.map((value, i) => Math.round(value + (b[i] - value) * slip))
  const [r, gr, b] = mix([20, 33, 58], [125, 135, 153])

  return (
    <div
      className="stage-payslip"
      style={{
        left, top: top - 120 * (1 - enter) - 140 * exit, width: w, height: h,
        opacity: Math.min(1, enter * 2) * (1 - exit),
        transform: `rotate(${-0.04 + (1 - enter) * 0.1}rad)`,
      }}
    >
      <div className="t-label t-muted">Payslip</div>
      <div className="t-title" style={{ marginTop: 4 }}>Ana Santos</div>
      <div style={{ flex: 1 }} />
      <div className="t-caption">Payday</div>
      <div className="stage-payslip-days">
        <span className="stage-payslip-old">
          <span className="t-amount" style={{ fontSize: 26, color: `rgb(${r}, ${gr}, ${b})` }}>Oct 30</span>
          <span className="stage-strike" style={{ width: 92 * slip }} />
        </span>
        <span className="t-amount" style={{ fontSize: 26, color: 'var(--danger)', opacity: slip, transform: `translateY(${10 * (1 - slip)}px)`, display: 'inline-block' }}>Nov 6?</span>
      </div>
      {stamp > 0 && (
        <span className="stage-late" style={{ opacity: Math.min(1, stamp * 2.5), transform: `scale(${1.9 - 0.9 * stampCurve(stamp)})` }}>
          <span>Late</span>
        </span>
      )}
    </div>
  )
}

const MONTHS = ['Nov 3', 'Dec 3', 'Jan 3', 'Feb 3', 'Mar 3', 'Apr 3']

/** Scene 3: six payouts drop onto the ledger and lock. */
function Ledger({ g, landscape }: { g: number; landscape: boolean }) {
  const s = SCENES[2]
  if (g < s.start + 0.3 || g > s.end + 0.05) return null
  const exit = easeInOut(seg(g, s.end - 0.5, s.end))
  const columns = landscape ? 3 : 2
  const cardW = 172
  const cardH = 128
  const gap = 18
  const gridW = columns * cardW + (columns - 1) * gap
  const origin = landscape ? { x: 700, y: 210 } : { x: (720 - gridW) / 2, y: 430 }

  return (
    <div className="stage-ledger" style={{ opacity: 1 - exit, transform: `translateY(${-140 * exit}px)` }}>
      <span className="t-label t-muted stage-ledger-label" style={{ left: origin.x, top: origin.y - 46, opacity: seg(g, s.start + 0.3, s.start + 0.7) }}>
        Stellar ledger, Testnet
      </span>
      {MONTHS.map((month, i) => {
        const dropAt = s.start + 0.6 + i * 0.28
        const drop = seg(g, dropAt, dropAt + 0.55)
        if (drop <= 0) return null
        const lock = seg(g, dropAt + 0.5, dropAt + 0.8)
        const col = i % columns
        const row = Math.floor(i / columns)
        return (
          <div
            key={month}
            className="stage-ticket"
            style={{
              left: origin.x + col * (cardW + gap),
              top: origin.y + row * (cardH + gap) - 220 * (1 - easeBack(drop)),
              width: cardW, height: cardH,
              opacity: Math.min(1, drop * 2.5),
              transform: `rotate(${(1 - easeOut(drop)) * (i % 2 === 0 ? -0.12 : 0.1)}rad)`,
            }}
          >
            <div className="stage-ticket-head">
              <span className="t-label">{month}</span>
              <span style={{ opacity: lock, transform: `scale(${0.6 + 0.4 * easeBack(lock)})`, display: 'inline-flex', color: 'var(--stamp)' }}>
                <LockKeyhole size={20} />
              </span>
            </div>
            <div style={{ flex: 1 }} />
            <div className="t-amount" style={{ fontSize: 26 }}>300 USDC</div>
            <div className="t-caption">Locked until payday</div>
          </div>
        )
      })}
    </div>
  )
}

/** The iPhone: in for the employer, out for the ledger, back for Ana. */
function Phone({ g, landscape }: { g: number; landscape: boolean }) {
  const presence = Math.max(seg(g, 5, 5.8) - seg(g, 10.5, 11.1), seg(g, 16, 16.8) - seg(g, 31.4, 32.2))
  if (presence <= 0) return null
  const p = easeOut(presence)
  const scale = landscape ? 0.76 : 0.78
  const left = landscape ? 930 - (FRAME.width * scale) / 2 : 360 - (FRAME.width * scale) / 2
  const top = landscape ? (720 - FRAME.height * scale) / 2 : 262

  // Screens push left like an iOS navigation between Ana's pay and the conversion sheet.
  const push = easeInOut(seg(g, 26.5, 27))
  let screen
  if (g < 13) screen = <EmployerScreen g={g} />
  else if (push <= 0) screen = <WorkerScreen g={g} />
  else if (push >= 1) screen = <ConvertScreen g={g} />
  else {
    screen = (
      <div className="phone-push">
        <div style={{ transform: `translateX(${-130 * push}px)` }}><WorkerScreen g={g} /></div>
        <div style={{ transform: `translateX(${SCREEN.width * (1 - push)}px)`, boxShadow: '0 0 24px rgba(20, 33, 58, .13)' }}><ConvertScreen g={g} /></div>
      </div>
    )
  }

  // Flutter: rotate about the box center, then scale from the top-left corner.
  const w = FRAME.width * scale
  const h = FRAME.height * scale
  return (
    <div className="stage-phone" style={{ left, top: top + (1 - p) * 520, width: w, height: h, opacity: Math.min(1, presence * 1.6), transform: `rotate(${(1 - p) * 0.09}rad)`, transformOrigin: `${FRAME.width / 2}px ${FRAME.height / 2}px` }}>
      <div style={{ transform: `scale(${scale})`, transformOrigin: '0 0', width: FRAME.width, height: FRAME.height }}>
        <IPhoneFrame screen={screen} />
      </div>
    </div>
  )
}

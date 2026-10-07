import { useCallback, useEffect, useRef, useState, type KeyboardEvent } from 'react'
import { ArrowRightLeft, ChevronRight, HandCoins, Hourglass, PenLine, UsersRound, type LucideIcon } from 'lucide-react'
import { easeOutBack } from '../../ui/curves'
import { useReducedMotion, useResponsive, useUp } from '../../ui/hooks'
import { Tilt3D } from '../../ui/Motion'
import { FRAME, IPhoneFrame } from '../story/IPhoneFrame'
import { ConvertScreen, EmployerScreen, WorkerScreen } from '../story/PhoneScreens'

type Screen = 'employer' | 'worker' | 'convert'
type Step = { icon: LucideIcon; title: string; body: string; screen: Screen; from: number; to: number }

const STEPS: Step[] = [
  { icon: UsersRound, title: 'Add your team', body: 'A wallet, a name and the total pay for each person.', screen: 'employer', from: 4.6, to: 6.4 },
  { icon: PenLine, title: 'Sign once', body: 'Freighter approves one transaction that locks every payout.', screen: 'employer', from: 6.4, to: 10.3 },
  { icon: Hourglass, title: 'Payday unlocks', body: 'Each payout opens on its payday, to the second.', screen: 'worker', from: 16.9, to: 20.6 },
  { icon: HandCoins, title: 'Claim in one tap', body: 'The worker approves in Freighter and the pay lands in their wallet.', screen: 'worker', from: 21.3, to: 25.4 },
  { icon: ArrowRightLeft, title: 'Take it in pesos', body: 'Or convert USDC to PHPT in the same transaction.', screen: 'convert', from: 27.0, to: 30.4 },
]

/**
 * "How a payroll runs", hands-on: pick a step and a 3D iPhone turns to
 * play it. A short tour runs on its own until someone takes over.
 */
export function ProcessExplorer() {
  const reduced = useReducedMotion()
  const wide = useUp('lg')
  const [step, setStep] = useState(0)
  const [progress, setProgress] = useState(0)
  const [tourStarted, setTourStarted] = useState(false)
  const touring = useRef(false)
  const advance = useRef<number | null>(null)
  const root = useRef<HTMLDivElement>(null)
  const playToken = useRef(0)

  const play = useCallback((index: number) => {
    const token = ++playToken.current
    const duration = (STEPS[index].to - STEPS[index].from) * 1000
    if (reduced) { setProgress(1); return }
    const started = performance.now()
    const tick = (now: number) => {
      if (token !== playToken.current) return
      const t = Math.min(1, (now - started) / duration)
      setProgress(t)
      if (t < 1) { requestAnimationFrame(tick); return }
      if (!touring.current) return
      advance.current = window.setTimeout(() => {
        if (touring.current) select((index + 1) % STEPS.length, false)
      }, 1400)
    }
    setProgress(0)
    requestAnimationFrame(tick)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [reduced])

  const select = useCallback((index: number, byPerson = true) => {
    if (advance.current) window.clearTimeout(advance.current)
    if (byPerson) touring.current = false
    const next = Math.max(0, Math.min(STEPS.length - 1, index))
    setStep(next)
    play(next)
  }, [play])

  // Start the self-running tour once the explorer is mostly in view.
  useEffect(() => {
    const node = root.current
    if (!node || tourStarted) return
    const observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.intersectionRatio >= 0.35)) return
      observer.disconnect()
      setTourStarted(true)
      touring.current = !reduced
      select(0, false)
    }, { threshold: [0, 0.35, 0.6] })
    observer.observe(node)
    return () => observer.disconnect()
  }, [tourStarted, reduced, select])

  useEffect(() => () => {
    playToken.current += 1
    if (advance.current) window.clearTimeout(advance.current)
  }, [])

  const g = tourStarted ? STEPS[step].from + (STEPS[step].to - STEPS[step].from) * progress : STEPS[0].to
  const stageHeight = useResponsive(470, { md: 560, lg: 640 })
  const scale = useResponsive(0.48, { md: 0.56, lg: 0.64 })

  const onKey = (event: KeyboardEvent) => {
    if (event.key === 'ArrowDown') { event.preventDefault(); select(step + 1) }
    else if (event.key === 'ArrowUp') { event.preventDefault(); select(step - 1) }
  }

  const list = (
    <div className="process-list">
      {STEPS.map((item, index) => (
        <StepTile key={item.title} index={index} step={item} selected={index === step} progress={progress} onClick={() => select(index)} />
      ))}
    </div>
  )
  const stage = <PhoneStage step={step} g={g} scale={scale} height={stageHeight} />

  return (
    <div ref={root} className={`process ${wide ? 'wide' : ''}`} onKeyDown={onKey}>
      {wide ? <>{list}{stage}</> : <>{stage}{list}</>}
    </div>
  )
}

function StepTile({ index, step, selected, progress, onClick }: { index: number; step: Step; selected: boolean; progress: number; onClick: () => void }) {
  const Icon = step.icon
  return (
    <button
      type="button"
      className={`process-tile ${selected ? 'selected' : ''}`}
      aria-pressed={selected}
      aria-label={`Step ${index + 1}: ${step.title}. ${step.body}`}
      onClick={onClick}
    >
      <span className="process-tile-row">
        <span className="process-tile-icon"><Icon size={19} /></span>
        <span className="process-tile-text">
          <span className="t-subtitle process-tile-title">{index + 1}. {step.title}</span>
          {/* The description opens on the selected step. */}
          <span className={`sw-collapse ${selected ? 'open' : ''}`}>
            <span><span className="t-body-sm process-tile-body">{step.body}</span></span>
          </span>
        </span>
        <ChevronRight size={18} className="process-tile-chevron" />
      </span>
      {selected && <span className="process-tile-progress"><span style={{ width: `${progress * 100}%` }} /></span>}
    </button>
  )
}

/** The phone in 3D: extruded body, ground shadow, a swing toward the viewer whenever the step changes, and pointer tilt on top. */
function PhoneStage({ step, g, scale, height }: { step: number; g: number; scale: number; height: number }) {
  const screen = STEPS[step].screen === 'employer'
    ? <EmployerScreen g={g} />
    : STEPS[step].screen === 'worker' ? <WorkerScreen g={g} /> : <ConvertScreen g={g} />
  const w = FRAME.width * scale
  const h = FRAME.height * scale
  const swing = useSwing(step)
  const baseY = -16 + 34 * swing // turns in from the right

  return (
    <div className="process-stage" style={{ height }}>
      <span className="process-ground" style={{ width: w * (0.9 + 0.15 * Math.abs(swing)), bottom: (height - h) / 2 - 18 }} />
      <Tilt3D maxTilt={9} baseX={7} baseY={baseY} perspective={1111} radius={68 * scale} style={{ width: w, height: h }}>
        <div style={{ width: FRAME.width, height: FRAME.height, transform: `scale(${scale})`, transformOrigin: '0 0' }}>
          <ExtrudedPhone screen={screen} />
        </div>
      </Tilt3D>
    </div>
  )
}

/** 1 → 0 with an overshoot every time `key` changes. */
function useSwing(key: number) {
  const reduced = useReducedMotion()
  const [value, setValue] = useState(0)
  useEffect(() => {
    if (reduced) { setValue(0); return }
    const started = performance.now()
    let frame = 0
    const tick = (now: number) => {
      const t = Math.min(1, (now - started) / 900)
      setValue(1 - easeOutBack(t))
      if (t < 1) frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [key, reduced])
  return value
}

/** The frame plus solid layers behind it, so a turned phone shows a body with thickness. */
function ExtrudedPhone({ screen }: { screen: React.ReactNode }) {
  const layers = 9
  return (
    <div className="extruded-phone" style={{ width: FRAME.width, height: FRAME.height }}>
      {Array.from({ length: layers }, (_, k) => layers - k).map((i) => {
        const t = i / layers
        const mix = (a: number, b: number) => Math.round(a + (b - a) * t)
        return (
          <span
            key={i}
            className="extruded-layer"
            // Flutter's +z is farther away; CSS's is closer.
            style={{ transform: `translateZ(${-i * 3.2}px)`, background: `rgb(${mix(0x3A, 0x15)}, ${mix(0x3D, 0x17)}, ${mix(0x46, 0x1C)})` }}
          />
        )
      })}
      <IPhoneFrame screen={screen} />
      <span className="extruded-rim" />
    </div>
  )
}


import { useCallback, useEffect, useRef, useState } from 'react'
import { Play, Pause, RotateCcw, SkipBack, SkipForward } from 'lucide-react'
import { Button } from '../../ui/Button'
import { useReducedMotion } from '../../ui/hooks'
import { keyFrame, SCENES, sceneAt, seg, STORY_TOTAL } from './script'
import { STAGE, StoryStage, type StageFormat } from './StoryStage'
import './story.css'

/** A poster frame that shows the payoff: Ana's payout, stamped. */
const POSTER_AT = 25.6

const clock = (seconds: number) => {
  const s = Math.floor(seconds)
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}

/**
 * A video-style player for the Sweldo story: scene progress bars, play and
 * pause, scene skipping, replay, keyboard control and captions. Starts on a
 * poster frame; with reduced motion it steps through still frames.
 */
export function StoryPlayer({ onFinishedAction, finishedLabel, autoplay = false }: {
  onFinishedAction?: () => void; finishedLabel?: string; autoplay?: boolean
}) {
  const reduced = useReducedMotion()
  const root = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(0)
  const [g, setG] = useState(POSTER_AT)
  const [playing, setPlaying] = useState(false)
  const [started, setStarted] = useState(false)
  const gRef = useRef(g)
  gRef.current = g
  const finished = g >= STORY_TOTAL

  useEffect(() => {
    const node = root.current
    if (!node) return
    const observer = new ResizeObserver(([entry]) => setWidth(entry.contentRect.width))
    observer.observe(node)
    return () => observer.disconnect()
  }, [])

  // The clock: advance story time while playing.
  useEffect(() => {
    if (!playing) return
    let frame = 0
    let last = performance.now()
    const tick = (now: number) => {
      const next = Math.min(STORY_TOTAL, gRef.current + (now - last) / 1000)
      last = now
      gRef.current = next
      setG(next)
      if (next >= STORY_TOTAL) { setPlaying(false); return }
      frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [playing])

  const start = useCallback(() => {
    setStarted(true)
    if (reduced) { setG(keyFrame(SCENES[0])); setPlaying(false); return }
    setG(0)
    gRef.current = 0
    setPlaying(true)
  }, [reduced])

  useEffect(() => { if (autoplay) start() }, [autoplay, start])

  const seekScene = useCallback((index: number) => {
    const i = Math.max(0, Math.min(SCENES.length - 1, index))
    setStarted(true)
    if (reduced) { setG(keyFrame(SCENES[i])); return }
    gRef.current = SCENES[i].start
    setG(SCENES[i].start)
  }, [reduced])

  const step = useCallback((delta: number) => seekScene(sceneAt(gRef.current) + delta), [seekScene])

  const toggle = useCallback(() => {
    if (!started) return start()
    if (reduced) return step(1)
    if (playing) setPlaying(false)
    else if (gRef.current >= STORY_TOTAL) { gRef.current = 0; setG(0); setPlaying(true) }
    else setPlaying(true)
  }, [started, start, reduced, step, playing])

  const format: StageFormat = width >= 700 ? 'landscape' : 'portrait'
  const stage = STAGE[format]
  const scale = width ? width / stage.width : 0
  const scene = SCENES[sceneAt(g)]

  return (
    <div
      ref={root}
      className="story-player"
      style={{ aspectRatio: `${stage.width} / ${stage.height}` }}
      tabIndex={0}
      onKeyDown={(event) => {
        if (event.key === ' ') { event.preventDefault(); toggle() }
        else if (event.key === 'ArrowRight') { event.preventDefault(); step(1) }
        else if (event.key === 'ArrowLeft') { event.preventDefault(); step(-1) }
      }}
    >
      <div className="story-stage-hit" onClick={() => { root.current?.focus(); toggle() }} role="img" aria-label={`Sweldo story. ${scene.caption}`} aria-live={started ? 'polite' : undefined}>
        {scale > 0 && (
          <div className="story-stage-scale" style={{ transform: `scale(${scale})` }} aria-hidden>
            <StoryStage g={g} format={format} />
          </div>
        )}
      </div>

      {started && (
        <>
          <div className="story-bars">
            {SCENES.map((item, index) => (
              <button
                key={index}
                type="button"
                className="story-bar"
                style={{ flex: Math.round((item.end - item.start) * 10) }}
                aria-label={`Scene ${index + 1} of ${SCENES.length}`}
                onClick={() => seekScene(index)}
              >
                <span><span style={{ width: `${seg(g, item.start, item.end) * 100}%` }} /></span>
              </button>
            ))}
          </div>
          <div className="story-controls">
            <RoundControl
              label={reduced ? 'Previous scene' : playing ? 'Pause' : 'Play'}
              onClick={reduced ? () => step(-1) : toggle}
              icon={reduced ? <SkipBack size={20} /> : playing ? <Pause size={20} /> : <Play size={20} />}
              iconKey={reduced ? 'prev' : playing ? 'pause' : 'play'}
            />
            <RoundControl label="Next scene" onClick={() => step(1)} icon={<SkipForward size={20} />} iconKey="next" />
            <span className="t-figures story-clock">{clock(g)} / {clock(STORY_TOTAL)}</span>
            <span className="story-controls-spacer" />
            <RoundControl label="Replay from the start" onClick={start} icon={<RotateCcw size={20} />} iconKey="replay" />
          </div>
        </>
      )}

      {!started && (
        <div className={`story-poster ${format === 'portrait' ? 'compact' : ''}`}>
          <button type="button" className="story-poster-play" onClick={start} aria-label="Play the Sweldo story">
            <Play size={34} fill="#fff" strokeWidth={0} />
          </button>
          <div>
            <div className="t-title">Watch Ana get paid</div>
            <div className="t-body-sm" style={{ marginTop: 2 }}>
              {reduced ? '7 scenes. Step through at your own pace.' : `${Math.round(STORY_TOTAL)} seconds, from payroll to pesos`}
            </div>
          </div>
        </div>
      )}

      {started && finished && !reduced && (
        <div className="story-end">
          {onFinishedAction && <Button label={finishedLabel ?? 'Get started'} onClick={onFinishedAction} />}
          <Button label="Watch again" icon={<RotateCcw />} tone="secondary" onClick={start} />
        </div>
      )}
    </div>
  )
}

function RoundControl({ label, onClick, icon, iconKey }: { label: string; onClick: () => void; icon: React.ReactNode; iconKey: string }) {
  return (
    <button type="button" className="story-round" onClick={onClick} aria-label={label} title={label}>
      <span key={iconKey} className="story-round-icon">{icon}</span>
    </button>
  )
}

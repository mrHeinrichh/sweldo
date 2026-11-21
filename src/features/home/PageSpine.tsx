import { useCallback, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { clamp } from '../../ui/curves'
import { useUp } from '../../ui/hooks'
import { pageScroller, smoothScroller, viewportBox } from '../../ui/scroll-progress'
import { ensureVisible } from '../../ui/scroll'

export type SpineSection = { id: string; label: string }

/**
 * The page's tractor-feed margin: the payroll paper's own edge, at the
 * scale of the whole page. One punch slot per section, in the vocabulary
 * the app already uses everywhere else — empty while a section is still
 * ahead of you, ringed for the one you are in, punched violet once you
 * have passed it. The feed line fills as the paper advances.
 */
export function PageSpine({ sections }: { sections: SpineSection[] }) {
  const interactive = useUp('sm')
  const [current, setCurrent] = useState(0)
  const [fill, setFill] = useState(0)

  useEffect(() => {
    const scroller = pageScroller()
    const read = () => {
      const view = viewportBox()
      const marker = view.height * 0.42
      let index = 0
      sections.forEach((section, i) => {
        const node = document.getElementById(section.id)
        if (node && node.getBoundingClientRect().top - view.top <= marker) index = i
      })
      setCurrent((prev) => (prev === index ? prev : index))
      const max = view.scroller.scrollHeight - view.scroller.clientHeight
      const next = max > 0 ? clamp(view.scroller.scrollTop / max, 0, 1) : 0
      setFill((prev) => (Math.abs(prev - next) < 0.004 ? prev : next))
    }
    read()
    scroller.addEventListener('scroll', read, { passive: true })
    window.addEventListener('resize', read)
    return () => {
      scroller.removeEventListener('scroll', read)
      window.removeEventListener('resize', read)
    }
  }, [sections])

  const jump = useCallback((id: string) => {
    const node = document.getElementById(id)
    if (!node) return
    const lenis = smoothScroller()
    if (lenis) lenis.scrollTo(node, { offset: -24 })
    else ensureVisible(node, 0)
  }, [])

  // The page shell animates its own transform, which would make a fixed
  // child resolve against the page instead of the viewport. The margin
  // belongs to the window, so it hangs off the body.
  const holes = sections.map((section, index) => {
    const state = index < current ? 'punched' : index === current ? 'ready' : 'locked'
    return { ...section, state, key: section.id }
  })

  // On a phone the sheet's own sprocket margin is already on screen a
  // few millimetres away, and a second column of holes beside it reads as
  // noise rather than as the page's edge. There the margin keeps the feed
  // line alone, which still says how far through the paper you are, and
  // the bottom bar does the navigating.
  const body = interactive
    ? holes.map((hole) => (
        <button
          key={hole.key}
          type="button"
          className={`spine-punch is-${hole.state}`}
          aria-current={hole.state === 'ready' ? 'true' : undefined}
          onClick={() => jump(hole.id)}
        >
          <span className="spine-hole" aria-hidden />
          <span className="spine-label">{hole.label}</span>
        </button>
      ))
    : null

  return createPortal(
    <nav
      className={`spine ${fill > 0.985 ? 'is-done' : ''}`}
      aria-label={interactive ? 'Sections on this page' : undefined}
      aria-hidden={interactive ? undefined : true}
    >
      <span className="spine-feed" aria-hidden>
        <span className="spine-feed-fill" style={{ height: `${fill * 100}%` }} />
      </span>
      {body}
    </nav>,
    document.body,
  )
}

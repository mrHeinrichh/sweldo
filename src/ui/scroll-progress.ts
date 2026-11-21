import { useEffect, useRef, useState } from 'react'
import Lenis from 'lenis'
import { clamp } from './curves'
import { useReducedMotion } from './hooks'

/** The shell's scrolling element — the Flutter app's page scroll view. */
export function pageScroller(): HTMLElement {
  return (document.querySelector('.shell-main') as HTMLElement | null) ?? (document.scrollingElement as HTMLElement)
}

let active: Lenis | null = null

/** The smooth scroller, while the landing page has one mounted. */
export const smoothScroller = () => active

/**
 * Momentum scrolling, mounted by the landing page only. Every other
 * destination keeps the platform's own scrolling, exactly as the Flutter
 * app leaves its form pages on the default physics.
 */
export function useSmoothScroll() {
  const reduced = useReducedMotion()
  useEffect(() => {
    if (reduced) return
    const wrapper = pageScroller()
    const content = wrapper.firstElementChild as HTMLElement | null
    if (!content || wrapper === document.scrollingElement) return
    const lenis = new Lenis({
      wrapper,
      content,
      duration: 1.05,
      // The same ease-out-cubic the rest of the app enters on.
      easing: (t: number) => 1 - Math.pow(1 - t, 3),
      smoothWheel: true,
      // Sheets, dialogs and anything that scrolls itself keep their own scroll.
      prevent: (node: HTMLElement) => !!node.closest?.('.sw-sheet, .sw-dialog, [data-lenis-prevent]'),
    })
    active = lenis
    let frame = requestAnimationFrame(function raf(time: number) {
      lenis.raf(time)
      frame = requestAnimationFrame(raf)
    })
    return () => {
      cancelAnimationFrame(frame)
      lenis.destroy()
      active = null
    }
  }, [reduced])
}

/** The scroller's viewport, in page coordinates. */
export function viewportBox() {
  const scroller = pageScroller()
  const isPage = scroller === document.scrollingElement
  return {
    scroller,
    top: isPage ? 0 : scroller.getBoundingClientRect().top,
    height: isPage ? window.innerHeight : scroller.clientHeight,
  }
}

/**
 * How far an element has travelled through the viewport, 0 to 1, read from
 * scroll position rather than fired once on entry — so it runs backwards
 * when the reader scrolls back up. `start` and `end` are where the
 * element's top sits, as a fraction of the viewport height.
 */
export function useScrollProgress<T extends HTMLElement>(start = 0.94, end = 0.56) {
  const ref = useRef<T>(null)
  const [progress, setProgress] = useState(0)
  const reduced = useReducedMotion()

  useEffect(() => {
    const node = ref.current
    if (!node) return
    if (reduced) { setProgress(1); return }
    let frame = 0
    let running = false

    const measure = () => {
      const view = viewportBox()
      const top = (node.getBoundingClientRect().top - view.top) / Math.max(1, view.height)
      const next = clamp((start - top) / (start - end), 0, 1)
      setProgress((prev) => (Math.abs(prev - next) < 0.003 ? prev : next))
      if (running) frame = requestAnimationFrame(measure)
    }

    // Measure only while the section is anywhere near the viewport.
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting && !running) {
        running = true
        frame = requestAnimationFrame(measure)
      } else if (!entry.isIntersecting && running) {
        running = false
        cancelAnimationFrame(frame)
        measure()
      }
    }, { rootMargin: '25% 0px 25% 0px' })

    observer.observe(node)
    measure()
    return () => {
      running = false
      cancelAnimationFrame(frame)
      observer.disconnect()
    }
  }, [start, end, reduced])

  return [ref, progress] as const
}

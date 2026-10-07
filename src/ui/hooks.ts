import { useEffect, useState, useSyncExternalStore } from 'react'

// Tailwind's breakpoints, matching the Flutter app's `Breakpoint` enum.
export const BREAKPOINTS = { sm: 640, md: 768, lg: 1024, xl: 1280 } as const
export type Breakpoint = keyof typeof BREAKPOINTS

function subscribeResize(callback: () => void) {
  window.addEventListener('resize', callback)
  return () => window.removeEventListener('resize', callback)
}

export function useWidth() {
  return useSyncExternalStore(subscribeResize, () => window.innerWidth, () => 1280)
}

/** `true` from the breakpoint up, like Tailwind's `md:` prefix. */
export function useUp(bp: Breakpoint) {
  return useWidth() >= BREAKPOINTS[bp]
}

/** Desktop layout from `lg` (1024px) up, as in the Flutter app. */
export function useWide() {
  return useUp('lg')
}

/** Mobile-first cascade: `responsive(16, { sm: 24, lg: 32 })`. */
export function useResponsive<T>(base: T, overrides: Partial<Record<Breakpoint, T>>): T {
  const width = useWidth()
  let value = base
  for (const bp of ['sm', 'md', 'lg', 'xl'] as Breakpoint[]) {
    if (overrides[bp] !== undefined && width >= BREAKPOINTS[bp]) value = overrides[bp] as T
  }
  return value
}

function subscribeMotion(callback: () => void) {
  const query = window.matchMedia('(prefers-reduced-motion: reduce)')
  query.addEventListener('change', callback)
  return () => query.removeEventListener('change', callback)
}

export function useReducedMotion() {
  return useSyncExternalStore(subscribeMotion, () => window.matchMedia('(prefers-reduced-motion: reduce)').matches, () => false)
}

/** The current time, ticking once a second. */
export function useNow(intervalMs = 1000) {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), intervalMs)
    return () => window.clearInterval(timer)
  }, [intervalMs])
  return now
}

export function isPhonePlatform() {
  return /Android|iPhone|iPad|iPod/i.test(navigator.userAgent)
}

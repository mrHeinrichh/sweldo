import { useSyncExternalStore } from 'react'
import { House, UsersRound, Wallet, type LucideIcon } from 'lucide-react'

// Hash routes, the same URLs as the Flutter web build: /#/, /#/employer, /#/pay, /#/story.

export type AppRoute = { path: string; label: string; icon: LucideIcon }

export const ROUTES: AppRoute[] = [
  { path: '/', label: 'Overview', icon: House },
  { path: '/employer', label: 'Pay your team', icon: UsersRound },
  { path: '/pay', label: 'My pay', icon: Wallet },
]

export const STORY_PATH = '/story'
const KNOWN = new Set([...ROUTES.map((route) => route.path), STORY_PATH])

function readPath() {
  const raw = window.location.hash.replace(/^#/, '') || '/'
  const path = raw.split('?')[0]
  return KNOWN.has(path) ? path : '/'
}

function subscribe(callback: () => void) {
  window.addEventListener('hashchange', callback)
  return () => window.removeEventListener('hashchange', callback)
}

export function useLocation() {
  return useSyncExternalStore(subscribe, readPath, () => '/')
}

export function navigate(path: string) {
  if (readPath() === path && window.location.hash) return
  window.location.hash = path
}

/** The top-level destination a path belongs to. */
export function routeFor(path: string) {
  return ROUTES.find((route) => route.path !== '/' && path.startsWith(route.path)) ?? ROUTES[0]
}

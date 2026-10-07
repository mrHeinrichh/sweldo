// Formatting shared by every screen; mirrors sweldo_flutter/lib/core/utils.

export function shortKey(value: string, edge = 5) {
  if (value.length <= edge * 2 + 1) return value
  return `${value.slice(0, edge)}…${value.slice(-edge)}`
}

const dateTimeFormat = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
const clockFormat = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit' })
const shortDateFormat = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' })
const timeFormat = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: '2-digit', second: '2-digit' })

/** "Oct 26, 2026 at 11:35 PM" */
export function formatDateTime(value: Date) {
  return `${dateTimeFormat.format(value)} at ${clockFormat.format(value)}`
}
export const formatShortDate = (value: Date) => shortDateFormat.format(value)
export const formatTime = (value: Date) => timeFormat.format(value)

/** Countdown label: "3d 4h", "2h 15m", "4m 07s". */
export function countdownLabel(milliseconds: number) {
  const seconds = Math.max(0, Math.ceil(milliseconds / 1000))
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const secs = seconds % 60
  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${minutes}m`
  return `${minutes}m ${String(secs).padStart(2, '0')}s`
}

export function plural(count: number, singular: string, pluralForm?: string) {
  return count === 1 ? singular : (pluralForm ?? `${singular}s`)
}

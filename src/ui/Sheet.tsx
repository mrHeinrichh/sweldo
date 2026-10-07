import { useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { useWide } from './hooks'

/**
 * A dialog on wide screens and a bottom sheet with a drag handle on phones,
 * like Flutter's showDialog / showModalBottomSheet pair.
 */
export function Sheet({ open, onClose, children, maxWidth = 460, label, dismissible = true }: {
  open: boolean; onClose: () => void; children: ReactNode; maxWidth?: number; label: string
  /** False keeps it open on scrim taps and Escape (Flutter's barrierDismissible). */
  dismissible?: boolean
}) {
  const wide = useWide()
  const [mounted, setMounted] = useState(open)
  const [leaving, setLeaving] = useState(false)
  const panel = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (open) {
      setMounted(true)
      setLeaving(false)
      return
    }
    if (!mounted) return
    setLeaving(true)
    const timer = window.setTimeout(() => { setMounted(false); setLeaving(false) }, 220)
    return () => window.clearTimeout(timer)
  }, [open, mounted])

  useEffect(() => {
    if (!open) return
    const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape' && dismissible) onClose() }
    window.addEventListener('keydown', onKey)
    const previous = document.activeElement as HTMLElement | null
    window.setTimeout(() => panel.current?.focus(), 0)
    return () => {
      window.removeEventListener('keydown', onKey)
      previous?.focus?.()
    }
  }, [open, onClose, dismissible])

  if (!mounted) return null
  return createPortal(
    <div className={`sw-sheet-layer ${wide ? 'dialog' : 'bottom'} ${leaving ? 'leaving' : ''}`}>
      <div className="sw-sheet-scrim" onClick={dismissible ? onClose : undefined} />
      <div ref={panel} className="sw-sheet" role="dialog" aria-modal="true" aria-label={label} tabIndex={-1} style={wide ? { maxWidth } : undefined}>
        {!wide && dismissible && <span className="sw-sheet-handle" aria-hidden />}
        <div className="sw-sheet-body">{children}</div>
      </div>
    </div>,
    document.body,
  )
}

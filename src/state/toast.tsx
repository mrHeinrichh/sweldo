import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react'

// The floating snackbar: one message at a time, ink on paper.

export type Toast = { id: number; text: string; isError?: boolean; action?: { label: string; href: string } }
type ToastApi = (text: string, options?: { isError?: boolean; action?: Toast['action'] }) => void

const ToastContext = createContext<ToastApi>(() => {})

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toast, setToast] = useState<Toast | null>(null)
  const [leaving, setLeaving] = useState(false)
  const nextId = useRef(0)

  const show = useCallback<ToastApi>((text, options = {}) => {
    nextId.current += 1
    setLeaving(false)
    setToast({ id: nextId.current, text, ...options })
  }, [])

  useEffect(() => {
    if (!toast) return
    const hide = window.setTimeout(() => setLeaving(true), toast.isError ? 8000 : 4000)
    return () => window.clearTimeout(hide)
  }, [toast])

  useEffect(() => {
    if (!leaving) return
    const remove = window.setTimeout(() => setToast(null), 220)
    return () => window.clearTimeout(remove)
  }, [leaving])

  // Components that can't reach the context (e.g. KeyText) dispatch an event.
  useEffect(() => {
    const listener = (event: Event) => show(String((event as CustomEvent).detail))
    window.addEventListener('sweldo:toast', listener)
    return () => window.removeEventListener('sweldo:toast', listener)
  }, [show])

  return (
    <ToastContext.Provider value={show}>
      {children}
      <div className="sw-toast-host" aria-live="polite">
        {toast && (
          <div key={toast.id} className={`sw-toast ${leaving ? 'leaving' : ''}`} role={toast.isError ? 'alert' : 'status'}>
            <span>{toast.text}</span>
            {toast.action && (
              <a href={toast.action.href} target="_blank" rel="noreferrer" className="sw-toast-action">{toast.action.label}</a>
            )}
          </div>
        )}
      </div>
    </ToastContext.Provider>
  )
}

export const useToast = () => useContext(ToastContext)

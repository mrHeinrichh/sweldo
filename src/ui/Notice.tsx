import { useEffect, useRef, useState, type ReactNode } from 'react'
import { CircleAlert, CircleCheck, Info, TriangleAlert } from 'lucide-react'
import { ExternalLink } from './ExternalLink'

export type NoticeTone = 'success' | 'error' | 'caution' | 'info'
export type NoticeData = { tone: NoticeTone; text: string; link?: string; linkLabel?: string }

const ICONS: Record<NoticeTone, ReactNode> = {
  success: <CircleCheck size={20} />,
  error: <CircleAlert size={20} />,
  caution: <TriangleAlert size={20} />,
  info: <Info size={20} />,
}

export function Notice({ data }: { data: NoticeData }) {
  return (
    <div className={`sw-notice tone-${data.tone}`} role={data.tone === 'error' ? 'alert' : 'status'}>
      <span className="sw-notice-icon">{ICONS[data.tone]}</span>
      <div>
        <p className="t-body-sm t-ink">{data.text}</p>
        {data.link && <ExternalLink href={data.link} label={data.linkLabel ?? 'View transaction'} className={`tone-${data.tone}`} />}
      </div>
    </div>
  )
}

/** Grows and shrinks with the notice so content below moves instead of jumping. */
export function AnimatedNotice({ data, gap = 'bottom' }: { data: NoticeData | null; gap?: 'top' | 'bottom' }) {
  const [shown, setShown] = useState(data)
  const last = useRef(data)
  useEffect(() => {
    if (data) {
      last.current = data
      setShown(data)
    } else {
      const timer = window.setTimeout(() => setShown(null), 280)
      return () => window.clearTimeout(timer)
    }
  }, [data])
  const visible = shown ?? last.current
  return (
    <Collapse open={!!data}>
      {visible && <div className={`sw-notice-gap-${gap}`} key={visible.text}><div className="sw-notice-enter"><Notice data={visible} /></div></div>}
    </Collapse>
  )
}

/** Animates height between 0 and its content (Flutter's AnimatedSize). */
export function Collapse({ open, children, className = '' }: { open: boolean; children: ReactNode; className?: string }) {
  return (
    <div className={`sw-collapse ${open ? 'open' : ''} ${className}`} aria-hidden={!open}>
      <div>{children}</div>
    </div>
  )
}

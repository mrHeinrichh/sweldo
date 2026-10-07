import { forwardRef, type CSSProperties, type ReactNode } from 'react'
import { useNow } from './hooks'

/** Centers page content and caps its width: `px-4 sm:px-6 lg:px-8`. */
export const ContentWidth = forwardRef<HTMLDivElement, { children: ReactNode; className?: string; flush?: boolean }>(
  function ContentWidth({ children, className = '', flush }, ref) {
    return <div ref={ref} className={`sw-content ${flush ? 'flush' : ''} ${className}`}>{children}</div>
  },
)

/** A flat surface for forms and lists. Hierarchy comes from the rule and radius, not depth. */
export function Panel({ children, padding, color, className = '', style }: {
  children: ReactNode; padding?: number | string; color?: string; className?: string; style?: CSSProperties
}) {
  return (
    <div className={`sw-panel ${className}`} style={{ padding, background: color, ...style }}>
      {children}
    </div>
  )
}

/** A heading with an optional line of explanation underneath. */
export function SectionHeading({ title, description, trailing, titleClass = 't-title', as: Tag = 'h2' }: {
  title: string; description?: string; trailing?: ReactNode; titleClass?: string; as?: 'h2' | 'h3'
}) {
  return (
    <div className="sw-section-heading">
      <div>
        <Tag className={`${titleClass} m0`}>{title}</Tag>
        {description && <p className="t-body-sm m0 sw-section-desc">{description}</p>}
      </div>
      {trailing && <div className="sw-section-trailing">{trailing}</div>}
    </div>
  )
}

/** Rebuilds once a second with the current time. */
export function SecondTicker({ children }: { children: (now: Date) => ReactNode }) {
  const now = useNow()
  return <>{children(now)}</>
}

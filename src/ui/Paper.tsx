import type { ReactNode } from 'react'

/**
 * Continuous-form payroll paper: a tractor-feed edge with sprocket holes and
 * greenbar banding on alternate rows. Used wherever a list *is* a pay schedule.
 */
export function PayrollPaper({ header, children, elevated, className = '' }: {
  header?: ReactNode; children: ReactNode; elevated?: boolean; className?: string
}) {
  return (
    <div className={`sw-paper ${elevated ? 'elevated' : ''} ${className}`}>
      <div className="sw-paper-body">
        {header}
        <div className="sw-paper-rows">{children}</div>
      </div>
    </div>
  )
}

/** The column header printed at the top of the payroll paper. */
export function PaperHeader({ title, trailing }: { title: string; trailing?: ReactNode }) {
  return (
    <div className="sw-paper-header">
      <span className="t-subtitle">{title}</span>
      {trailing}
    </div>
  )
}

/** A violet rubber stamp. Lands with a thump when `animate` is true. */
export function ClaimedStamp({ label = 'Claimed', animate, color = 'var(--stamp)' }: { label?: string; animate?: boolean; color?: string }) {
  return (
    <span className={`sw-stamp ${animate ? 'animate' : ''}`} style={{ ['--stamp-color' as string]: color }}>
      <span className="sw-stamp-inner">{label}</span>
    </span>
  )
}

export type PunchState = 'locked' | 'ready' | 'punched'

/** Empty while locked, ringed when payday has come, punched through once claimed. */
export function PunchSlot({ state }: { state: PunchState }) {
  return <span className={`sw-punch is-${state}`} aria-hidden />
}

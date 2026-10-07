import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { LoaderCircle } from 'lucide-react'

export type ButtonTone = 'primary' | 'payday' | 'secondary' | 'quiet' | 'danger'

type Props = Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'children'> & {
  label: string
  icon?: ReactNode
  tone?: ButtonTone
  loading?: boolean
  expand?: boolean
  large?: boolean
}

/**
 * The single button: `hover:-translate-y-px` with a tinted shadow,
 * `active:scale-[.97]`, a focus ring, and an icon that grows on hover.
 */
export function Button({ label, icon, tone = 'primary', loading, expand, large, disabled, className = '', ...rest }: Props) {
  return (
    <button
      type="button"
      {...rest}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={`sw-button tone-${tone} ${large ? 'large' : ''} ${expand ? 'expand' : ''} ${disabled ? 'is-disabled' : ''} ${className}`}
    >
      <span className="sw-button-row" key={loading ? 'loading' : 'idle'}>
        {loading ? <LoaderCircle size={16} className="spin" /> : icon && <span className="sw-button-icon">{icon}</span>}
        <span className="sw-button-label">{label}</span>
      </span>
    </button>
  )
}

/** A square icon-only button, used for copy and refresh. */
export function IconButton({ icon, label, onClick, loading, size = 40 }: {
  icon: ReactNode; label: string; onClick?: () => void; loading?: boolean; size?: number
}) {
  return (
    <button type="button" className="sw-icon-button" style={{ width: size, height: size }} aria-label={label} title={label} onClick={onClick} disabled={loading}>
      {loading ? <LoaderCircle size={16} className="spin" /> : <span className="sw-icon-button-glyph">{icon}</span>}
    </button>
  )
}

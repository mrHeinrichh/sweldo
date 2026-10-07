import { Banknote } from 'lucide-react'

/** The original Sweldo mark: a banknote on a violet tile. */
export function SweldoMark({ size = 34 }: { size?: number }) {
  return (
    <span
      className="sw-mark"
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.29,
        boxShadow: `0 ${size * 0.18}px ${size * 0.47}px rgba(102, 77, 213, .25)`,
      }}
      aria-hidden
    >
      <Banknote size={size * 0.62} color="#fff" strokeWidth={2} />
    </span>
  )
}

/** Mark plus the "sweldo." wordmark in Manrope ExtraBold with a violet full stop. */
export function SweldoLogo({ size = 34, compact, onClick }: { size?: number; compact?: boolean; onClick?: () => void }) {
  const content = (
    <span className="sw-logo" style={{ gap: size * 0.27 }}>
      <SweldoMark size={size} />
      {!compact && (
        <span className="sw-wordmark" style={{ fontSize: size * 0.66, letterSpacing: -size * 0.03 }}>
          sweldo<span>.</span>
        </span>
      )}
    </span>
  )
  if (!onClick) return content
  return (
    <button type="button" className="sw-logo-button" onClick={onClick} aria-label="Sweldo home">
      {content}
    </button>
  )
}

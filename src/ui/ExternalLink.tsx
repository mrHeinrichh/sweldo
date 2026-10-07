import { ArrowUpRight } from 'lucide-react'

/** A text link that leaves the app, marked with an "opens elsewhere" glyph. */
export function ExternalLink({ href, label, className = '', small }: { href: string; label: string; className?: string; small?: boolean }) {
  return (
    <a className={`sw-link ${small ? 'small' : ''} ${className}`} href={href} target="_blank" rel="noreferrer">
      <span>{label}</span>
      <ArrowUpRight size={13} />
    </a>
  )
}

import { useState } from 'react'
import { Check, Copy } from 'lucide-react'
import { shortKey } from './format'

/** A Stellar key or hash in monospace, with a copy action that confirms itself. */
export function KeyText({ value, edge = 6, copyable = true, strong }: { value: string; edge?: number; copyable?: boolean; strong?: boolean }) {
  const [copied, setCopied] = useState(false)

  async function copy() {
    try {
      await navigator.clipboard.writeText(value)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      window.dispatchEvent(new CustomEvent('sweldo:toast', { detail: 'Copy is unavailable here. Select the text instead.' }))
    }
  }

  return (
    <span className="sw-key">
      <span className={`t-mono ${strong ? 'strong' : ''}`} title={value} aria-label={value}>{shortKey(value, edge)}</span>
      {copyable && (
        <button type="button" className={`sw-key-copy ${copied ? 'copied' : ''}`} onClick={copy} aria-label={copied ? 'Copied' : 'Copy'} title={copied ? 'Copied' : 'Copy'}>
          <span key={String(copied)} className="sw-key-glyph">{copied ? <Check size={16} /> : <Copy size={16} />}</span>
        </button>
      )}
    </span>
  )
}

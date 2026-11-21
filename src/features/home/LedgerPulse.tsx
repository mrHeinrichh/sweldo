import { useEffect, useState } from 'react'
import { server } from '../../lib/stellar'
import { PingDot } from '../../ui/Motion'

type Pulse = { sequence: number; closedAt: number }

/**
 * The ledger Sweldo writes to, closing in real time. One true number that
 * keeps moving: it says the network holding everyone's pay is alive right
 * now. Says nothing about Sweldo's own traffic, and shows nothing at all
 * when Horizon can't be reached.
 */
export function LedgerPulse() {
  const [pulse, setPulse] = useState<Pulse | null>(null)
  const [age, setAge] = useState(0)

  useEffect(() => {
    let live = true
    let timer = 0
    const read = async () => {
      try {
        const page = await server.ledgers().order('desc').limit(1).call()
        const record = page.records[0]
        if (live && record) {
          setPulse({ sequence: Number(record.sequence), closedAt: new Date(record.closed_at).getTime() })
        }
      } catch {
        // Offline, or Horizon is down: the hero simply doesn't show a pulse.
      }
      if (live) timer = window.setTimeout(read, 5000)
    }
    read()
    return () => { live = false; window.clearTimeout(timer) }
  }, [])

  useEffect(() => {
    if (!pulse) return
    const tick = window.setInterval(() => setAge(Math.max(0, Math.round((Date.now() - pulse.closedAt) / 1000))), 500)
    setAge(Math.max(0, Math.round((Date.now() - pulse.closedAt) / 1000)))
    return () => window.clearInterval(tick)
  }, [pulse])

  if (!pulse) return null
  return (
    <p className="ledger-pulse m0" aria-live="off">
      <PingDot size={7} />
      <span className="t-caption ledger-pulse-text">
        Stellar Testnet ledger <span className="ledger-pulse-seq">{pulse.sequence.toLocaleString()}</span>
        {' '}closed {age < 1 ? 'just now' : `${age}s ago`}
      </span>
    </p>
  )
}

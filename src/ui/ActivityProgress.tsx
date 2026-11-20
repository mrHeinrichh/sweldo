import { useEffect, useState } from 'react'
import { Check, LoaderCircle } from 'lucide-react'
import type { TransactionPhase } from '../lib/transaction-progress'
import './activity.css'

/** Completed stages come from application events; time never advances the steps. */
export function ActivityProgress({ title, steps, current, detail, approval = false }: {
  title: string; steps: string[]; current: number; detail: string; approval?: boolean
}) {
  const [started] = useState(Date.now)
  const [elapsed, setElapsed] = useState(0)
  const [returned, setReturned] = useState(false)
  useEffect(() => {
    const tick = () => setElapsed(Math.floor((Date.now() - started) / 1000))
    const timer = window.setInterval(tick, 1000)
    const visible = () => {
      tick()
      if (document.visibilityState === 'visible') setReturned(true)
    }
    document.addEventListener('visibilitychange', visible)
    return () => { window.clearInterval(timer); document.removeEventListener('visibilitychange', visible) }
  }, [started])
  const active = Math.max(0, Math.min(current, steps.length - 1))
  return (
    <section className="activity-progress" aria-label={title} aria-busy="true">
      <div className="activity-heading"><LoaderCircle className="spin" size={22} aria-hidden /><strong>{title}</strong><span className="activity-time" aria-label={`${elapsed} seconds elapsed`}>{elapsed < 60 ? `${elapsed}s` : `${Math.floor(elapsed / 60)}m ${elapsed % 60}s`}</span></div>
      <p className="activity-detail" role="status">{approval && returned ? 'Welcome back. Checking for your wallet approval…' : detail}</p>
      <div className="activity-track" aria-hidden><span style={{ width: `${active / steps.length * 100}%` }} /><i /></div>
      <ol className="activity-steps">
        {steps.map((step, index) => <li key={step} className={index < active ? 'done' : index === active ? 'active' : ''} aria-current={index === active ? 'step' : undefined}>
          <span className="activity-step-icon">{index < active ? <Check size={12} /> : index === active ? <LoaderCircle size={12} className="spin" /> : index + 1}</span>
          <span>{step}<span className="sr-only">{index < active ? ', completed' : index === active ? ', in progress' : ', upcoming'}</span></span>
        </li>)}
      </ol>
      {elapsed >= 15 && <p className="activity-help">{approval ? 'Approve the request in your wallet, then return here. Your approval is still pending.' : 'Stellar is taking a little longer. Keep this page open while we check the result.'} Elapsed time is shown above; completion depends on your wallet and the network.</p>}
    </section>
  )
}

export function TransactionActivity({ phase, title = 'Your transaction is being processed' }: { phase: TransactionPhase; title?: string }) {
  const phases: TransactionPhase[] = ['preparing', 'approval', 'submitting', 'receipt']
  const messages: Record<TransactionPhase, string> = {
    preparing: 'Checking your account and preparing the transaction…',
    approval: 'Transaction prepared. Review and approve the request in your wallet.',
    submitting: 'Wallet approval received. Submitting your transaction to Stellar…',
    receipt: 'Stellar confirmed your transaction. Reading your receipt…',
    registry: 'Payroll confirmed on Stellar. Approve the optional registry proof in your wallet.',
  }
  return <ActivityProgress title={title} steps={phase === 'registry' ? ['Prepared', 'Wallet approved', 'Payroll confirmed', 'Registry proof'] : ['Prepare', 'Wallet approval', 'Stellar confirmation', 'Receipt']} current={phase === 'registry' ? 3 : phases.indexOf(phase)} detail={messages[phase]} approval={phase === 'approval' || phase === 'registry'} />
}

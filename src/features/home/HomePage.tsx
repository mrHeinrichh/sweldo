import type { ReactNode } from 'react'
import { ArrowRightLeft, CirclePlay, Coins, ShieldCheck, Undo2 } from 'lucide-react'
import { PageFrame } from '../../app/Shell'
import { navigate } from '../../app/router'
import { assetLabel, conversionPair } from '../../state/config'
import { Button } from '../../ui/Button'
import { easeOutCubic } from '../../ui/curves'
import { useWide } from '../../ui/hooks'
import { PayrollPaper } from '../../ui/Paper'
import { useScrollProgress, useSmoothScroll } from '../../ui/scroll-progress'
import { StoryPlayer } from '../story/StoryPlayer'
import { DemoPayCard } from './DemoPayCard'
import { LedgerPulse } from './LedgerPulse'
import { PageSpine, type SpineSection } from './PageSpine'
import { PayoutStack3D } from './PayoutStack3D'
import { ProcessExplorer } from './ProcessExplorer'
import './home.css'

const SECTIONS: SpineSection[] = [
  { id: 'home-overview', label: 'Overview' },
  { id: 'home-process', label: 'How it runs' },
  { id: 'home-story', label: 'The story' },
  { id: 'home-money', label: 'The money' },
]

export function HomePage() {
  const wide = useWide()
  // Momentum scrolling belongs to the landing page only.
  useSmoothScroll()

  return (
    <PageFrame>
      <PageSpine sections={SECTIONS} />
      <div className="home-page">
        <section id="home-overview" className={`home-hero ${wide ? 'wide' : ''}`}>
          <Intro wide={wide} />
          <DemoPayCard assetLabel={assetLabel} />
        </section>
        <div className="home-gap" />
        <Section id="home-process" title="How a payroll runs" lede="Pick a step to see it on the phone. Arrow keys move between steps.">
          <div data-tour="process"><ProcessExplorer /></div>
        </Section>
        <div className="home-gap" />
        <Section id="home-story" title="Watch it start to finish" lede="A 36-second story: one worker, from a locked payroll to pay in her wallet.">
          <StoryPlayer finishedLabel="Set up payroll" onFinishedAction={() => navigate('/employer')} />
        </Section>
        <div className="home-gap" />
        <Section id="home-money" title="Where the money is">
          <MoneyFacts />
        </Section>
      </div>
    </PageFrame>
  )
}

/**
 * A section of the sheet. Its rule draws itself as the paper advances —
 * scroll position drives it, so it runs back the other way when the
 * reader scrolls up. Nothing here fades or slides in on arrival.
 */
function Section({ id, title, lede, children }: { id: string; title: string; lede?: string; children: ReactNode }) {
  const [ref, progress] = useScrollProgress<HTMLElement>(0.92, 0.62)
  return (
    <section id={id} ref={ref}>
      <h2 className="home-section-title m0">{title}</h2>
      <span className="home-section-rule" aria-hidden>
        <span style={{ transform: `scaleX(${easeOutCubic(progress)})` }} />
      </span>
      {lede && <p className="t-body t-muted m0 home-section-lede">{lede}</p>}
      {children}
    </section>
  )
}

function Intro({ wide }: { wide: boolean }) {
  return (
    <div className="home-intro">
      <h1 className={`t-display m0 home-title home-seq ${wide ? 'wide' : ''}`} style={{ animationDelay: '60ms' }}>
        Every payday, locked in.
      </h1>
      <p className="t-body m0 home-lede home-seq" style={{ animationDelay: '180ms' }}>
        Sign once to lock a team’s salaries on Stellar. Each person claims their pay the moment it unlocks, straight to their own wallet. Sweldo never holds the money.
      </p>
      <div className="home-pulse home-seq" style={{ animationDelay: '300ms' }}><LedgerPulse /></div>
      <div className="home-actions home-seq" data-tour="hero-actions" style={{ animationDelay: '380ms' }}>
        <Button label="Set up payroll" large onClick={() => navigate('/employer')} />
        <Button label="See my pay" large tone="secondary" onClick={() => navigate('/pay')} />
      </div>
      <div className="home-story-link home-seq" style={{ animationDelay: '460ms' }}>
        <Button label="Watch the 36-second story" icon={<CirclePlay />} tone="quiet" onClick={() => navigate('/story')} />
      </div>
      <p className="t-body-sm m0 home-note home-seq" style={{ animationDelay: '520ms' }}>
        Runs on Stellar Testnet with test money. Connect Varial or xBull.
      </p>
    </div>
  )
}

/** Plain answers to "where is the money?", beside the payouts themselves. */
function MoneyFacts() {
  const wide = useWide()
  const facts = [
    { icon: ShieldCheck, label: 'Who holds the money', body: 'The Stellar ledger. Each payout is a claimable balance that only the employee can claim, and only from payday on.' },
    { icon: Undo2, label: 'Who can cancel', body: 'The employer, for payouts whose payday hasn’t arrived. Pay that has unlocked belongs to the employee.' },
    { icon: Coins, label: 'What it costs', body: 'A network fee of a fraction of a cent, plus a 1 XLM reserve per payout (0.5 XLM for each of its two claimants), returned to the employer once the payout is claimed or cancelled.' },
    {
      icon: ArrowRightLeft,
      label: 'Local currency',
      body: conversionPair
        ? 'Workers can claim test-USDC as PHPT in the same transaction, through Stellar’s built-in exchange.'
        : 'With a test-USDC build, workers can claim straight into PHPT through Stellar’s built-in exchange.',
    },
  ]
  const paper = (
    <PayrollPaper>
      {facts.map(({ icon: Icon, label, body }) => (
        <div key={label} className="fact-row">
          <span className="fact-icon"><Icon size={18} /></span>
          <div>
            <div className="t-subtitle">{label}</div>
            <p className="t-body-sm t-ink m0" style={{ marginTop: 4 }}>{body}</p>
          </div>
        </div>
      ))}
    </PayrollPaper>
  )
  const stack = <PayoutStack3D assetLabel={assetLabel} />
  return wide
    ? <div className="facts wide">{paper}{stack}</div>
    : <div className="facts">{stack}{paper}</div>
}

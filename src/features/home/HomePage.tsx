import { ArrowRightLeft, CirclePlay, Coins, ShieldCheck, Undo2 } from 'lucide-react'
import { PageFrame } from '../../app/Shell'
import { navigate } from '../../app/router'
import { assetLabel, conversionPair } from '../../state/config'
import { Button } from '../../ui/Button'
import { useWide } from '../../ui/hooks'
import { Reveal } from '../../ui/Motion'
import { PayrollPaper } from '../../ui/Paper'
import { StoryPlayer } from '../story/StoryPlayer'
import { DemoPayCard } from './DemoPayCard'
import { PayoutStack3D } from './PayoutStack3D'
import { ProcessExplorer } from './ProcessExplorer'
import './home.css'

export function HomePage() {
  const wide = useWide()
  return (
    <PageFrame>
      <div className={`home-hero ${wide ? 'wide' : ''}`}>
        <Intro wide={wide} />
        <DemoPayCard assetLabel={assetLabel} />
      </div>
      <div className="home-gap" />
      <Reveal><ProcessSection /></Reveal>
      <div className="home-gap" />
      <Reveal><StorySection /></Reveal>
      <div className="home-gap" />
      <Reveal><MoneyFacts /></Reveal>
    </PageFrame>
  )
}

function Intro({ wide }: { wide: boolean }) {
  return (
    <div className="home-intro">
      <h1 className={`t-display m0 home-title ${wide ? 'wide' : ''}`}>Every payday, locked in.</h1>
      <p className="t-body m0 home-lede">
        Sign once to lock a team’s salaries on Stellar. Each person claims their pay the moment it unlocks, straight to their own wallet. Sweldo never holds the money.
      </p>
      <div className="home-actions" data-tour="hero-actions">
        <Button label="Set up payroll" large onClick={() => navigate('/employer')} />
        <Button label="See my pay" large tone="secondary" onClick={() => navigate('/pay')} />
      </div>
      <div className="home-story-link">
        <Button label="Watch the 36-second story" icon={<CirclePlay />} tone="quiet" onClick={() => navigate('/story')} />
      </div>
      <p className="t-body-sm m0 home-note">Runs on Stellar Testnet with test money. Connect Freighter in your browser or on your phone.</p>
    </div>
  )
}

/** The process, hands-on: steps on one side, a 3D phone on the other. */
function ProcessSection() {
  return (
    <section>
      <h2 className="home-section-title m0">How a payroll runs</h2>
      <p className="t-body t-muted m0 home-section-lede">Pick a step to see it on the phone. Arrow keys move between steps.</p>
      <div data-tour="process"><ProcessExplorer /></div>
    </section>
  )
}

/** The product, told as a short film: words first, then the app on a phone. */
function StorySection() {
  return (
    <section>
      <h2 className="home-section-title m0">Watch it start to finish</h2>
      <p className="t-body t-muted m0 home-section-lede">A 36-second story: one worker, from a locked payroll to pay in her wallet.</p>
      <StoryPlayer finishedLabel="Set up payroll" onFinishedAction={() => navigate('/employer')} />
    </section>
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
  return (
    <section>
      <h2 className="home-section-title m0 facts-title">Where the money is</h2>
      {wide
        ? <div className="facts wide">{paper}{stack}</div>
        : <div className="facts">{stack}{paper}</div>}
    </section>
  )
}

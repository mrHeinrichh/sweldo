// The guide, in the order someone meets the app. Same copy as
// sweldo_flutter/lib/features/tour/tour_steps.dart.

export type TourStep = {
  /** `data-tour` id to spotlight; none shows a centred card. */
  target?: string
  /** Page to open before the step. */
  route?: string
  title: string
  body: string
  /** Invites the person to use the highlighted control during the step. */
  tryIt?: string
  /** Payroll wizard step to open first (0 team, 1 schedule, 2 review). */
  payrollStep?: 0 | 1 | 2
}

export const SWELDO_TOUR: TourStep[] = [
  {
    route: '/',
    title: 'Welcome to Sweldo',
    body: 'Lock a team’s pay on Stellar once, and each person claims it on payday. This guide takes about a minute. Use → and ← to move, Esc to close.',
  },
  {
    route: '/',
    target: 'hero-actions',
    title: 'Two sides, one app',
    body: 'Employers start from “Set up payroll”. Workers open “See my pay” to claim.',
  },
  {
    route: '/',
    target: 'process',
    title: 'See each step on a phone',
    body: 'Pick a step and the phone plays it: adding a team, signing once, payday, the claim, and pay in pesos.',
    tryIt: 'Click a step in the list.',
  },
  {
    target: 'connect',
    title: 'Connect Freighter',
    body: 'Use the Freighter extension in this browser, or scan a QR code with the Freighter app on your phone. Sweldo never sees your keys.',
  },
  {
    route: '/employer',
    target: 'employees',
    payrollStep: 0,
    title: 'Add your team',
    body: 'Each card is one person: a name, their Stellar wallet address, and the total to pay them. Sample names and pay are filled in fresh each visit.',
  },
  {
    route: '/employer',
    target: 'schedule-sentence',
    payrollStep: 1,
    title: 'Read the schedule as a sentence',
    body: 'Each highlighted part is a menu: how often, how many times, and when pay starts. “Pay until a date” counts the paydays for you.',
    tryIt: 'Open one of the highlighted parts.',
  },
  {
    route: '/employer',
    target: 'payout-track',
    payrollStep: 1,
    title: 'Set the number of payouts',
    body: 'Each slot is one payout. Hatched slots are past what one Stellar transaction can hold for your team.',
    tryIt: 'Drag the handle, or tap − and +.',
  },
  {
    route: '/employer',
    target: 'presets',
    payrollStep: 1,
    title: 'Or start from a preset',
    body: 'A live demo, daily, weekly or monthly plan sets everything at once.',
  },
  {
    route: '/employer',
    target: 'insights',
    payrollStep: 2,
    title: 'Check before you sign',
    body: 'Live notes on the first and last payday, the transaction limit, and whether your wallet covers the total plus reserves.',
  },
  {
    route: '/employer',
    target: 'lock',
    payrollStep: 2,
    title: 'Lock it with one signature',
    body: 'Freighter shows the transaction. Once you approve, every payout is locked on Stellar. You can cancel future payouts until each payday.',
  },
  {
    route: '/pay',
    target: 'connect-pay',
    title: 'Workers: connect to see your pay',
    body: 'Use the wallet your employer paid. Payouts unlock on their payday and you claim them straight to your wallet.',
  },
  {
    route: '/pay',
    target: 'pay-schedule',
    title: 'Claim on payday',
    body: 'Each locked payout counts down. When it reaches zero, Claim appears. Claimed payouts flip over to their receipt.',
  },
  {
    route: '/pay',
    target: 'claim-history',
    title: 'Every claim has a receipt',
    body: 'Claimed pay is listed here with a link to its transaction on Stellar Expert.',
  },
  {
    title: 'You’re set',
    body: 'Open this guide any time from Guide in the top bar.',
  },
]

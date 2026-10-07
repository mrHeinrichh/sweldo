import 'tour_controller.dart';

/// The guide, in the order someone meets the app.
const sweldoTour = [
  TourStep(
    route: '/',
    title: 'Welcome to Sweldo',
    body:
        'Lock a team’s pay on Stellar once, and each person claims it on '
        'payday. This guide takes about a minute. Use → and ← to move, Esc to '
        'close.',
  ),
  TourStep(
    route: '/',
    target: 'hero-actions',
    title: 'Two sides, one app',
    body:
        'Employers start from “Set up payroll”. Workers open “See my pay” '
        'to claim.',
  ),
  TourStep(
    route: '/',
    target: 'process',
    title: 'See each step on a phone',
    body:
        'Pick a step and the phone plays it: adding a team, signing once, '
        'payday, the claim, and pay in pesos.',
    tryIt: 'Click a step in the list.',
  ),
  TourStep(
    target: 'connect',
    title: 'Connect Freighter',
    body:
        'Use the Freighter extension in this browser, or scan a QR code '
        'with the Freighter app on your phone. Sweldo never sees your keys.',
  ),
  TourStep(
    route: '/employer',
    target: 'employees',
    title: 'Add your team',
    body:
        'Each card is one person: a name, their Stellar wallet address, '
        'and the total to pay them.',
  ),
  TourStep(
    route: '/employer',
    target: 'shuffle',
    title: 'Try it with sample values',
    body:
        'Shuffle fills in names, pay and a schedule so you can explore. '
        'Wallet addresses you typed stay put.',
    tryIt: 'Press Shuffle and watch the form roll.',
  ),
  TourStep(
    route: '/employer',
    target: 'schedule-sentence',
    title: 'Read the schedule as a sentence',
    body:
        'Each highlighted part is a menu: how often, how many times, and '
        'when pay starts. “Pay until a date” counts the paydays for you.',
    tryIt: 'Open one of the highlighted parts.',
  ),
  TourStep(
    route: '/employer',
    target: 'payout-track',
    title: 'Drag to set the number of payouts',
    body:
        'Each slot is one payout. Hatched slots are past what one Stellar '
        'transaction can hold for your team.',
    tryIt: 'Drag the handle left or right.',
  ),
  TourStep(
    route: '/employer',
    target: 'presets',
    title: 'Or start from a preset',
    body: 'A live demo, daily, weekly or monthly plan sets everything at once.',
  ),
  TourStep(
    route: '/employer',
    target: 'insights',
    title: 'Check before you sign',
    body:
        'Live notes on the first and last payday, the transaction limit, '
        'and whether your wallet covers the total plus reserves.',
  ),
  TourStep(
    route: '/employer',
    target: 'lock',
    title: 'Lock it with one signature',
    body:
        'Freighter shows the transaction. Once you approve, every payout is '
        'locked on Stellar. You can cancel future payouts until each payday.',
  ),
  TourStep(
    route: '/pay',
    target: 'connect-pay',
    title: 'Workers: connect to see your pay',
    body:
        'Use the wallet your employer paid. Payouts unlock on their payday '
        'and you claim them straight to your wallet.',
  ),
  TourStep(
    route: '/pay',
    target: 'pay-schedule',
    title: 'Claim on payday',
    body:
        'Each locked payout counts down. When it reaches zero, Claim '
        'appears. Claimed payouts flip over to their receipt.',
  ),
  TourStep(
    route: '/pay',
    target: 'claim-history',
    title: 'Every claim has a receipt',
    body:
        'Claimed pay is listed here with a link to its transaction on '
        'Stellar Expert.',
  ),
  TourStep(
    title: 'You’re set',
    body: 'Open this guide any time from Guide in the top bar.',
  ),
];

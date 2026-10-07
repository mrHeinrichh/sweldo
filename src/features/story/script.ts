import { clamp, easeInOutCubic, easeOutBack, easeOutCubic } from '../../ui/curves'

// "Ana gets paid": the whole product in 36 seconds. Same script and timing
// as sweldo_flutter/lib/features/story/domain/story_script.dart.

export type StoryScene = {
  start: number
  end: number
  lines: string[]
  /** Lines from this index on are set quieter, as a follow-up thought. */
  quietFrom: number
  /** Plain-language description for screen readers and reduced motion. */
  caption: string
}

export const SCENES: StoryScene[] = [
  { start: 0, end: 4.5, lines: ['Ana gets paid', 'every month.', 'Some paydays came late.'], quietFrom: 2, caption: 'Ana is paid monthly, and some of her paydays came late.' },
  { start: 4.5, end: 11, lines: ['Her employer', 'locks six paydays.', 'One signature does it.'], quietFrom: 2, caption: 'Her employer opens Sweldo, sets six monthly payouts, and signs once in Freighter. The payroll is locked.' },
  { start: 11, end: 16, lines: ['The money waits', 'on Stellar.', 'Not with Sweldo.', 'Not with her employer.'], quietFrom: 2, caption: 'Six time-locked payouts sit on the Stellar ledger. Nobody can take them early.' },
  { start: 16, end: 21, lines: ['Payday arrives', 'to the second.'], quietFrom: 99, caption: "On Ana's phone, the countdown reaches zero and her first payout turns ready to claim." },
  { start: 21, end: 26.5, lines: ['One tap.', 'Her pay is in her wallet.'], quietFrom: 1, caption: 'Ana taps Claim, approves in Freighter, and 300 USDC lands in her wallet. The payout is stamped claimed.' },
  { start: 26.5, end: 31.5, lines: ['Next month,', 'she takes pesos.', 'Converted on Stellar.'], quietFrom: 2, caption: "The next payday she claims as PHPT, converted through Stellar's built-in exchange in the same transaction." },
  { start: 31.5, end: 36, lines: ['Sweldo.', 'Payroll that keeps its promise.'], quietFrom: 1, caption: 'Sweldo: payroll that keeps its promise.' },
]

export const STORY_TOTAL = SCENES[SCENES.length - 1].end

/** The frame that best summarises a scene, used as a still. */
export const keyFrame = (scene: StoryScene) => scene.end - 0.7

export function sceneAt(seconds: number) {
  const index = SCENES.findIndex((scene) => seconds < scene.end)
  return index === -1 ? SCENES.length - 1 : index
}

/** Progress of g through the window [a, b], clamped to 0…1. */
export function seg(g: number, a: number, b: number) {
  if (b <= a) return g >= b ? 1 : 0
  return clamp((g - a) / (b - a), 0, 1)
}

export const easeOut = easeOutCubic
export const easeInOut = easeInOutCubic
export const easeBack = easeOutBack

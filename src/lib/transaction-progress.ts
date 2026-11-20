/** Emitted only when the corresponding transaction work actually starts. */
export type TransactionPhase = 'preparing' | 'approval' | 'submitting' | 'receipt' | 'registry'
export type TransactionProgress = (phase: TransactionPhase) => void

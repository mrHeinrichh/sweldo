import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { claimBalance, getClaimableBalances, getClaimHistory, parseUnlockTime, type BalanceRecord } from '../lib/stellar'
import type { ConversionReceipt } from '../lib/claim-convert'
import type { NoticeData } from '../ui/Notice'
import { formatAmount, tryUnits } from './amount'
import { explorer } from './config'
import { friendlyError } from './errors'
import { useWallet } from './wallet'

// Port of PayoutsBloc: the employee's vesting timeline and claims.

export type Payout = {
  balanceId: string
  amount: string
  /** `native` or `CODE:ISSUER`, as Horizon writes it. */
  asset: string
  assetCode: string
  sponsor?: string
  claimants: BalanceRecord['claimants']
}

export type ClaimRecord = {
  id: string
  balanceId: string
  transactionHash?: string
  claimedAt: string
  amount?: string
  asset?: string
  source: 'stellar' | 'local'
}

export function unlockTimeFor(payout: Payout, address: string): Date | null {
  const claimant = payout.claimants.find((item) => item.destination === address)
  return claimant ? parseUnlockTime(claimant.predicate) : null
}

export function isUnlockedFor(payout: Payout, address: string, now: Date) {
  const unlock = unlockTimeFor(payout, address)
  return unlock === null || now.getTime() >= unlock.getTime()
}

const proofKey = (record: ClaimRecord) => (record.transactionHash ? `tx:${record.transactionHash}` : `balance:${record.balanceId}`)
export { proofKey as claimProofKey }

/** Joins local and on-chain history by transaction, keeping the richer local amount. Newest first. */
export function mergeClaimHistory(local: ClaimRecord[], onChain: ClaimRecord[]) {
  const byProof = new Map<string, ClaimRecord>()
  for (const record of [...local, ...onChain]) {
    const previous = byProof.get(proofKey(record))
    byProof.set(proofKey(record), {
      ...record,
      amount: previous?.amount ?? record.amount,
      asset: previous?.asset ?? record.asset,
      source: previous?.source === 'local' ? 'local' : record.source,
    })
  }
  return [...byProof.values()].sort((a, b) => Date.parse(b.claimedAt) - Date.parse(a.claimedAt))
}

const HISTORY_PREFIX = 'sweldo-claim-history-v1'
function readHistory(address: string): ClaimRecord[] {
  try {
    const raw = JSON.parse(localStorage.getItem(`${HISTORY_PREFIX}:${address}`) ?? '[]')
    return Array.isArray(raw) ? raw.map((item) => ({ ...item, source: item.source === 'stellar' ? 'stellar' : 'local' })) : []
  } catch {
    return []
  }
}
function saveHistory(address: string, record: ClaimRecord) {
  try {
    const next = mergeClaimHistory([record, ...readHistory(address)], []).slice(0, 50)
    localStorage.setItem(`${HISTORY_PREFIX}:${address}`, JSON.stringify(next))
  } catch { /* a full storage quota must not hide a confirmed receipt */ }
}

type PayoutsState = {
  address: string | null
  loading: boolean
  loaded: boolean
  payouts: Payout[]
  history: ClaimRecord[]
  claimingId: string | null
  /** Payouts claimed this session → transaction hash. They stay stamped until Horizon stops listing them. */
  claimedHashes: Record<string, string>
  freshClaimKey: string | null
  receipt: ConversionReceipt | null
  notice: NoticeData | null
}

type PayoutsApi = PayoutsState & {
  openPayouts: Payout[]
  totalUnits: bigint
  refresh: () => void
  claim: (payout: Payout) => void
  conversionCompleted: (receipt: ConversionReceipt) => void
  dismissNotice: () => void
}

const EMPTY = (address: string | null): PayoutsState => ({
  address, loading: false, loaded: false, payouts: [], history: [], claimingId: null, claimedHashes: {}, freshClaimKey: null, receipt: null, notice: null,
})

const PayoutsContext = createContext<PayoutsApi | null>(null)

function toPayout(record: BalanceRecord): Payout {
  return {
    balanceId: record.balance_id,
    amount: record.amount,
    asset: record.asset,
    assetCode: record.asset === 'native' ? 'XLM' : record.asset.split(':')[0],
    sponsor: record.sponsor,
    claimants: record.claimants,
  }
}

export function PayoutsProvider({ children }: { children: ReactNode }) {
  const { session } = useWallet()
  const [state, setState] = useState<PayoutsState>(() => EMPTY(null))
  const stateRef = useRef(state)
  stateRef.current = state
  const addressRef = useRef<string | null>(null)

  const load = useCallback(async (address: string, clearNotice: boolean) => {
    setState((previous) => ({ ...previous, loading: true }))
    try {
      const [records, onChain] = await Promise.all([getClaimableBalances(address), getClaimHistory(address)])
      if (addressRef.current !== address) return
      const payouts = records.map(toPayout)
      const live = new Set(payouts.map((payout) => payout.balanceId))
      setState((previous) => ({
        ...previous,
        loading: false,
        loaded: true,
        payouts,
        history: mergeClaimHistory(readHistory(address), onChain),
        claimedHashes: Object.fromEntries(Object.entries(previous.claimedHashes).filter(([id]) => live.has(id))),
        notice: clearNotice ? null : previous.notice,
      }))
    } catch (error) {
      if (addressRef.current !== address) return
      setState((previous) => ({ ...previous, loading: false, loaded: true, notice: { tone: 'error', text: friendlyError(error) } }))
    }
  }, [])

  const address = session?.address ?? null
  useEffect(() => {
    if (addressRef.current === address) return
    addressRef.current = address
    setState(EMPTY(address))
    if (address) void load(address, true)
  }, [address, load])

  const refresh = useCallback(() => {
    const target = addressRef.current
    if (!target || stateRef.current.loading) return
    void load(target, true)
  }, [load])

  const claim = useCallback(async (payout: Payout) => {
    const target = addressRef.current
    if (!target || stateRef.current.claimingId) return
    setState((previous) => ({ ...previous, claimingId: payout.balanceId, notice: null }))
    try {
      const response = await claimBalance(target, payout.balanceId)
      const record: ClaimRecord = {
        id: payout.balanceId, balanceId: payout.balanceId, transactionHash: response.hash,
        claimedAt: new Date().toISOString(), amount: payout.amount, asset: payout.assetCode, source: 'local',
      }
      saveHistory(target, record)
      setState((previous) => ({
        ...previous,
        claimingId: null,
        claimedHashes: { ...previous.claimedHashes, [payout.balanceId]: response.hash },
        history: mergeClaimHistory([record], previous.history),
        freshClaimKey: proofKey(record),
        notice: { tone: 'success', text: `${formatAmount(payout.amount)} ${payout.assetCode} claimed. It is in your wallet now.`, link: explorer.transaction(response.hash) },
      }))
    } catch (error) {
      setState((previous) => ({ ...previous, claimingId: null, notice: { tone: 'error', text: friendlyError(error) } }))
    }
  }, [])

  const conversionCompleted = useCallback((receipt: ConversionReceipt) => {
    const target = addressRef.current
    if (!target) return
    const record: ClaimRecord = {
      id: receipt.balanceId, balanceId: receipt.balanceId, transactionHash: receipt.hash,
      claimedAt: new Date().toISOString(), amount: receipt.receivedAmount ?? undefined, asset: 'PHPT', source: 'local',
    }
    saveHistory(target, record)
    setState((previous) => ({
      ...previous,
      receipt,
      claimedHashes: { ...previous.claimedHashes, [receipt.balanceId]: receipt.hash },
      history: mergeClaimHistory([record], previous.history),
      freshClaimKey: proofKey(record),
    }))
    void load(target, false)
  }, [load])

  const api = useMemo<PayoutsApi>(() => {
    const openPayouts = state.payouts.filter((payout) => !(payout.balanceId in state.claimedHashes))
    return {
      ...state,
      openPayouts,
      totalUnits: openPayouts.reduce((sum, payout) => sum + (tryUnits(payout.amount) ?? 0n), 0n),
      refresh,
      claim: (payout) => { void claim(payout) },
      conversionCompleted,
      dismissNotice: () => setState((previous) => ({ ...previous, notice: null })),
    }
  }, [state, refresh, claim, conversionCompleted])

  return <PayoutsContext.Provider value={api}>{children}</PayoutsContext.Provider>
}

export function usePayouts() {
  const value = useContext(PayoutsContext)
  if (!value) throw new Error('usePayouts needs a PayoutsProvider.')
  return value
}

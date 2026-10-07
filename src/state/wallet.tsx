import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import * as wallets from '../lib/wallets'
import type { WalletKind } from '../lib/wallets'
import { getXlmBalance } from '../lib/stellar'
import { formatAmount } from './amount'
import { friendlyError, isNotFound } from './errors'
import { useToast } from './toast'

// Port of WalletBloc: who is connected, through which Freighter, and the
// pairing URI while the phone app is being linked.

export type WalletStatus = 'initial' | 'restoring' | 'disconnected' | 'connecting' | 'connected'
export type WalletSession = { address: string; network: string; kind: WalletKind; onTestnet: boolean }

type WalletContextValue = {
  status: WalletStatus
  session: WalletSession | null
  connectingKind: WalletKind | null
  pairingUri: string | null
  xlmBalance: string | null
  isBusy: boolean
  sheetOpen: boolean
  openSheet: () => void
  closeSheet: () => void
  connect: (kind: WalletKind) => void
  dismissPairing: () => void
  disconnect: () => void
}

const WalletContext = createContext<WalletContextValue | null>(null)

function toSession(state: wallets.WalletState): WalletSession {
  return { address: state.address, network: state.network, kind: state.kind, onTestnet: state.network === 'TESTNET' }
}

export function WalletProvider({ children }: { children: ReactNode }) {
  const toast = useToast()
  const [status, setStatus] = useState<WalletStatus>('initial')
  const [session, setSession] = useState<WalletSession | null>(null)
  const [connectingKind, setConnectingKind] = useState<WalletKind | null>(null)
  const [pairingUri, setPairingUri] = useState<string | null>(null)
  const [xlmBalance, setXlmBalance] = useState<string | null>(null)
  const [sheetOpen, setSheetOpen] = useState(false)
  const pairing = useRef<AbortController | null>(null)
  const statusRef = useRef(status)
  statusRef.current = status
  const sessionRef = useRef(session)
  sessionRef.current = session

  useEffect(() => {
    let cancelled = false
    setStatus('restoring')
    wallets.restore().then(async (restored) => {
      if (cancelled) return
      if (!restored) { setStatus('disconnected'); return }
      const next = toSession(restored)
      setSession(next)
      setStatus('connected')
      try { setXlmBalance(await getXlmBalance(next.address)) } catch { /* unfunded wallets get the funding prompt */ }
    }).catch(() => { if (!cancelled) setStatus('disconnected') })
    const off = wallets.onWalletDisconnected(() => {
      setSession(null)
      setXlmBalance(null)
      setStatus('disconnected')
    })
    return () => { cancelled = true; off() }
  }, [])

  const connect = useCallback(async (kind: WalletKind) => {
    if (statusRef.current === 'connecting') return
    const controller = new AbortController()
    pairing.current = controller
    setStatus('connecting')
    setConnectingKind(kind)
    setPairingUri(null)
    try {
      const connected = toSession(await wallets.connect(kind, { onPairingUri: setPairingUri, signal: controller.signal }))
      let balance: string | null = null
      let text: string
      try {
        balance = await getXlmBalance(connected.address)
        text = `Connected. ${formatAmount(balance)} XLM available.`
      } catch (error) {
        text = isNotFound(error) ? "Connected. This wallet isn't funded on Testnet yet." : 'Connected.'
      }
      setSession(connected)
      setXlmBalance(balance)
      setStatus('connected')
      setConnectingKind(null)
      setPairingUri(null)
      setSheetOpen(false)
      toast(text)
    } catch (error) {
      if (controller.signal.aborted) return
      setStatus(sessionRef.current ? 'connected' : 'disconnected')
      setConnectingKind(null)
      setPairingUri(null)
      const missing = error instanceof wallets.FreighterMissingError
      toast(friendlyError(error), {
        isError: true,
        action: missing ? { label: 'Get Freighter', href: 'https://www.freighter.app/' } : undefined,
      })
    }
  }, [toast])

  const dismissPairing = useCallback(() => {
    if (statusRef.current !== 'connecting') return
    pairing.current?.abort()
    setStatus(sessionRef.current ? 'connected' : 'disconnected')
    setConnectingKind(null)
    setPairingUri(null)
  }, [])

  const disconnect = useCallback(async () => {
    await wallets.disconnect()
    setSession(null)
    setXlmBalance(null)
    setStatus('disconnected')
    toast('Wallet disconnected.')
  }, [toast])

  const closeSheet = useCallback(() => {
    setSheetOpen(false)
    dismissPairing()
  }, [dismissPairing])

  const value = useMemo<WalletContextValue>(() => ({
    status, session, connectingKind, pairingUri, xlmBalance,
    isBusy: status === 'connecting' || status === 'restoring',
    sheetOpen,
    openSheet: () => setSheetOpen(true),
    closeSheet,
    connect: (kind) => { void connect(kind) },
    dismissPairing,
    disconnect: () => { void disconnect() },
  }), [status, session, connectingKind, pairingUri, xlmBalance, sheetOpen, closeSheet, connect, dismissPairing, disconnect])

  return <WalletContext.Provider value={value}>{children}</WalletContext.Provider>
}

export function useWallet() {
  const value = useContext(WalletContext)
  if (!value) throw new Error('useWallet needs a WalletProvider.')
  return value
}

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import * as wallets from '../lib/wallets'
import type { WalletKind } from '../lib/wallets'
import { getXlmBalance } from '../lib/stellar'
import { formatAmount } from './amount'
import { friendlyError, isNotFound } from './errors'
import { useToast } from './toast'
import { Networks } from '@stellar/stellar-sdk'
import { pendingWallet } from '../lib/wallets/pending'

// Wallet session and the optional mobile pairing request.

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
  const onTestnet = state.networkPassphrase ? state.networkPassphrase === Networks.TESTNET : state.network === 'TESTNET'
  return { address: state.address, network: state.network, kind: state.kind, onTestnet }
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
    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(), 12_000)
    setStatus('restoring')
    pendingWallet(wallets.restore(controller.signal), controller.signal).then(async (restored) => {
      if (cancelled || pairing.current) return
      window.clearTimeout(timeout)
      if (!restored) { setStatus('disconnected'); return }
      const next = toSession(restored)
      setSession(next)
      setStatus('connected')
      try { setXlmBalance(await getXlmBalance(next.address)) } catch { /* unfunded wallets get the funding prompt */ }
    }).catch(() => { if (!cancelled && !pairing.current) setStatus('disconnected') }).finally(() => window.clearTimeout(timeout))
    const off = wallets.onWalletDisconnected(() => {
      setSession(null)
      setXlmBalance(null)
      setStatus('disconnected')
    })
    return () => { cancelled = true; controller.abort(); window.clearTimeout(timeout); off() }
  }, [])

  const connect = useCallback(async (kind: WalletKind) => {
    if (statusRef.current === 'connecting') return
    pairing.current?.abort()
    const controller = new AbortController()
    const timeout = window.setTimeout(() => controller.abort(new Error('Your wallet has not replied after 2 minutes. Reopen Varial and approve the connection, or try connecting again.')), 120_000)
    pairing.current = controller
    statusRef.current = 'connecting'
    setStatus('connecting')
    setConnectingKind(kind)
    setPairingUri(null)
    try {
      const connected = toSession(await pendingWallet(wallets.connect(kind, { onPairingUri: (uri) => { if (!controller.signal.aborted) setPairingUri(uri) }, signal: controller.signal }), controller.signal))
      window.clearTimeout(timeout)
      if (controller.signal.aborted) return
      setSession(connected)
      setXlmBalance(null)
      setStatus('connected')
      setConnectingKind(null)
      setPairingUri(null)
      setSheetOpen(false)
      let balance: string | null = null
      let text: string
      try {
        balance = await getXlmBalance(connected.address)
        text = `Connected. ${formatAmount(balance)} XLM available.`
      } catch (error) {
        text = isNotFound(error) ? "Connected. This wallet isn't funded on Testnet yet." : 'Connected.'
      }
      if (controller.signal.aborted) return
      setXlmBalance(balance)
      toast(text)
    } catch (error) {
      if (controller.signal.aborted && controller.signal.reason?.name === 'AbortError') return
      setStatus(sessionRef.current ? 'connected' : 'disconnected')
      setConnectingKind(null)
      setPairingUri(null)
      const missing = error instanceof wallets.FreighterMissingError
      toast(friendlyError(error), {
        isError: true,
        action: missing ? { label: 'Get Varial', href: 'https://varialwallet.com/' } : undefined,
      })
    } finally {
      window.clearTimeout(timeout)
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
    pairing.current?.abort()
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

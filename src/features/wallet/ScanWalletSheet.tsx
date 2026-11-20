import { useCallback, useEffect, useRef, useState } from 'react'
import { Camera, Check, ImageUp, ScanLine, ShieldCheck, X } from 'lucide-react'
import { parseWalletQr } from '../../lib/wallet-qr'
import { Button, IconButton } from '../../ui/Button'
import { Sheet } from '../../ui/Sheet'
import './wallet-qr.css'

type CameraStatus = 'idle' | 'starting' | 'scanning' | 'paused'

/**
 * Reads an employee's public address from the QR code their wallet shows.
 * It only fills the address field; it never signs or pays anything.
 * Mirrors sweldo_flutter/lib/features/wallet/view/wallet_qr_scanner.dart.
 */
export function ScanWalletSheet({ open, onClose, onAddress, onManual }: {
  open: boolean; onClose: () => void; onAddress: (address: string) => void
  /** "Enter address manually": the sheet closes and the caller focuses its field. */
  onManual?: () => void
}) {
  return <Sheet open={open} onClose={onClose} label="Scan wallet address" maxWidth={500}>
    <Scanner active={open} onClose={onClose} onAddress={onAddress} onManual={onManual} />
  </Sheet>
}

function cameraError(error: unknown) {
  const name = error instanceof Error ? error.name : ''
  if (name === 'NotAllowedError' || name === 'SecurityError') return 'Camera access was not allowed. Allow the camera for Sweldo in your settings, upload a QR image, or enter the address manually.'
  if (name === 'NotFoundError' || name === 'OverconstrainedError') return 'No camera was found. Upload a QR image or enter the address manually.'
  if (name === 'NotReadableError') return 'The camera is busy. Close other apps using it, or upload a QR image instead.'
  return 'The camera could not start. Try again, upload a QR image, or enter the address manually.'
}

/** Groups of four make a 56-character key easy to read back to its owner. */
export function AddressGroups({ address }: { address: string }) {
  const groups = address.match(/.{1,4}/g) ?? []
  return (
    <p className="wallet-qr-address wallet-qr-groups" aria-label={address}>
      {groups.map((group, index) => (
        <span key={index} className={index === 0 || index === groups.length - 1 ? 'edge' : undefined}>{group}</span>
      ))}
    </p>
  )
}

function Scanner({ active, onClose, onAddress, onManual }: {
  active: boolean; onClose: () => void; onAddress: (address: string) => void; onManual?: () => void
}) {
  const video = useRef<HTMLVideoElement>(null)
  const fileInput = useRef<HTMLInputElement>(null)
  const stream = useRef<MediaStream | null>(null)
  const timer = useRef<number | null>(null)
  const generation = useRef(0)
  const [camera, setCamera] = useState<CameraStatus>('idle')
  const [readingImage, setReadingImage] = useState(false)
  const [candidate, setCandidate] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  const stopCamera = useCallback(() => {
    generation.current += 1
    if (timer.current !== null) window.clearTimeout(timer.current)
    timer.current = null
    stream.current?.getTracks().forEach((track) => track.stop())
    stream.current = null
    if (video.current) video.current.srcObject = null
  }, [])

  /** True once an address is found. A wrong code leaves the camera scanning, so the right one can follow. */
  const accept = useCallback((payload: string) => {
    let address: string
    try { address = parseWalletQr(payload) } catch (problem) {
      setCandidate(null)
      setError(problem instanceof Error ? problem.message : 'This QR does not contain a supported Stellar wallet address.')
      return false
    }
    stopCamera()
    setCamera('idle')
    setReadingImage(false)
    setCandidate(address)
    setError(null)
    navigator.vibrate?.(35)
    return true
  }, [stopCamera])

  const startCamera = useCallback(async () => {
    stopCamera()
    const id = generation.current
    setCandidate(null)
    setError(null)
    setCamera('starting')
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
      setCamera('idle')
      setError('Camera scanning needs a supported browser on HTTPS. Upload a QR image or enter the address manually.')
      return
    }
    try {
      const { default: decode } = await import('jsqr')
      if (generation.current !== id) return
      const next = await navigator.mediaDevices.getUserMedia({ audio: false, video: { facingMode: { ideal: 'environment' }, width: { ideal: 1280 }, height: { ideal: 720 } } })
      if (generation.current !== id) { next.getTracks().forEach((track) => track.stop()); return }
      stream.current = next
      const preview = video.current
      if (!preview) { stopCamera(); return }
      preview.srcObject = next
      await preview.play()
      if (generation.current !== id) return
      setCamera('scanning')
      const canvas = document.createElement('canvas')
      const context = canvas.getContext('2d', { willReadFrequently: true })
      if (!context) throw new Error('Camera preview unavailable')
      let rejected = ''
      const scan = () => {
        if (generation.current !== id) return
        if (preview.readyState >= 2 && preview.videoWidth) {
          const scale = Math.min(1, 960 / preview.videoWidth)
          canvas.width = Math.round(preview.videoWidth * scale)
          canvas.height = Math.round(preview.videoHeight * scale)
          context.drawImage(preview, 0, 0, canvas.width, canvas.height)
          const frame = context.getImageData(0, 0, canvas.width, canvas.height)
          const result = decode(frame.data, frame.width, frame.height, { inversionAttempts: 'attemptBoth' })
          // A code already explained stays explained; anything new is read.
          if (result && result.data !== rejected) {
            if (accept(result.data)) return
            rejected = result.data
          }
        }
        timer.current = window.setTimeout(scan, 250)
      }
      next.getVideoTracks().forEach((track) => track.addEventListener('ended', () => {
        if (generation.current !== id) return
        stopCamera(); setCamera('paused'); setError('The camera stopped. Start it again or upload a QR image.')
      }, { once: true }))
      scan()
    } catch (problem) {
      if (generation.current !== id) return
      stopCamera(); setCamera('idle'); setError(cameraError(problem))
    }
  }, [accept, stopCamera])

  // Choosing Scan is the request for the camera, so it starts straight away.
  // Closing turns it off at once, while the sheet animates away.
  useEffect(() => {
    if (!active) return
    const start = window.setTimeout(() => void startCamera(), 0)
    return () => { window.clearTimeout(start); stopCamera() }
  }, [active, startCamera, stopCamera])

  useEffect(() => {
    const pause = () => {
      if (document.visibilityState !== 'hidden') return
      stopCamera()
      setCamera((current) => current === 'scanning' || current === 'starting' ? 'paused' : current)
      setReadingImage(false)
    }
    document.addEventListener('visibilitychange', pause)
    return () => document.removeEventListener('visibilitychange', pause)
  }, [stopCamera])

  const readImage = async (file?: File) => {
    if (!file) return
    stopCamera()
    const id = generation.current
    setCamera('idle'); setCandidate(null); setError(null); setReadingImage(true)
    let objectUrl: string | null = null
    try {
      if (!/^image\/(png|jpeg|webp|gif|bmp)$/.test(file.type) || file.size > 10_000_000) throw new Error('Choose a PNG, JPG, WebP, GIF or BMP image under 10 MB.')
      const { default: decode } = await import('jsqr')
      if (generation.current !== id) return
      objectUrl = URL.createObjectURL(file)
      const image = new Image()
      image.src = objectUrl
      await image.decode()
      if (generation.current !== id) return
      const canvas = document.createElement('canvas')
      const scale = Math.min(1, 1800 / Math.max(image.naturalWidth, image.naturalHeight))
      canvas.width = Math.round(image.naturalWidth * scale)
      canvas.height = Math.round(image.naturalHeight * scale)
      const context = canvas.getContext('2d', { willReadFrequently: true })
      if (!context || !canvas.width || !canvas.height) throw new Error('This image could not be read. Try a clear screenshot of the QR code.')
      context.drawImage(image, 0, 0, canvas.width, canvas.height)
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height)
      const result = decode(pixels.data, pixels.width, pixels.height, { inversionAttempts: 'attemptBoth' })
      if (!result) throw new Error('No QR code was found. Try a clearer image with the whole QR code visible.')
      accept(result.data)
    } catch (problem) {
      if (generation.current === id) setError(problem instanceof Error ? problem.message : 'The QR image could not be read.')
    } finally {
      if (objectUrl) URL.revokeObjectURL(objectUrl)
      if (generation.current === id) setReadingImage(false)
    }
  }

  const live = camera === 'scanning'
  const status = readingImage ? 'Reading your QR image…'
    : live ? 'Hold the QR code inside the frame. Sweldo stops as soon as it reads one.'
      : camera === 'starting' ? 'Allow camera access if you’re asked.'
        : camera === 'paused' ? 'Start the camera again when you’re ready.'
          : 'Start the camera, or upload a screenshot of the QR code.'

  return <div className="wallet-qr-content">
    <div className="wallet-qr-heading"><h2 className="t-title m0">Scan wallet address</h2><IconButton icon={<X />} label="Close wallet scanner" onClick={onClose} /></div>
    <p className="t-body-sm m0">Scan the QR code in your employee’s Stellar wallet, or upload a screenshot of it.</p>
    {!candidate && <>
      <div className={`wallet-scan-frame ${live ? 'is-live' : ''}`}>
        <video ref={video} muted playsInline aria-label="Wallet QR camera preview" />
        {!live && (
          <div className="wallet-scan-placeholder">
            <ScanLine size={40} strokeWidth={1.6} />
            <span>{camera === 'starting' ? 'Starting your camera…' : camera === 'paused' ? 'Camera paused' : 'Camera is off'}</span>
          </div>
        )}
        <span className="wallet-scan-corners" aria-hidden><i /><i /><i /><i /></span>
        {live && <span className="wallet-scan-line" aria-hidden />}
      </div>
      <p className="t-caption m0" role="status">{status}</p>
      <div className="wallet-qr-actions">
        {live || camera === 'starting'
          ? <Button label="Stop camera" tone="secondary" onClick={() => { stopCamera(); setCamera('idle') }} />
          : <Button label={camera === 'paused' ? 'Restart camera' : 'Start camera'} icon={<Camera />} onClick={() => void startCamera()} disabled={readingImage} />}
        <Button label="Upload QR image" icon={<ImageUp />} tone="secondary" loading={readingImage} onClick={() => fileInput.current?.click()} />
      </div>
      <input ref={fileInput} type="file" accept="image/png,image/jpeg,image/webp,image/gif,image/bmp" hidden aria-label="Upload wallet QR image" onChange={(event) => { void readImage(event.target.files?.[0]); event.target.value = '' }} />
    </>}
    {error && <p role="alert" className="wallet-qr-error t-body-sm">{error}</p>}
    {candidate && <div className="wallet-qr-found">
      <span className="wallet-qr-found-title"><Check size={18} /> Wallet address found</span>
      <AddressGroups address={candidate} />
      <p className="t-body-sm m0">Check it with your employee: it should start with <strong>{candidate.slice(0, 4)}</strong> and end with <strong>{candidate.slice(-4)}</strong>. Only the address is added.</p>
      <div className="wallet-qr-actions">
        <Button label="Scan again" tone="secondary" onClick={() => void startCamera()} />
        <Button label="Use this address" icon={<Check />} onClick={() => { onAddress(candidate); onClose() }} />
      </div>
    </div>}
    {!candidate && <Button label="Enter address manually" tone="quiet" onClick={() => { onClose(); onManual?.() }} />}
    <p className="wallet-qr-privacy t-caption m0"><ShieldCheck size={14} aria-hidden /> QR codes are read on this device. Sweldo never asks for a secret key or recovery phrase.</p>
  </div>
}

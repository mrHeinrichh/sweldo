import { StrKey } from '@stellar/stellar-sdk'

// The same messages as sweldo_flutter/lib/features/wallet/domain/wallet_qr.dart.
export const WALLET_QR_INVALID = 'Scan a Stellar wallet QR code containing a valid G… public address.'
export const WALLET_QR_SECRET = 'This QR code is a secret key, not a wallet address. Nothing was saved. Ask the employee to show their public address (starts with G) and to keep that secret key private.'
export const WALLET_QR_MUXED = 'This is a muxed (M…) address. Payroll needs the employee’s main wallet address, which starts with G.'
export const WALLET_QR_FEDERATION = 'This QR code shows a name*domain address. Ask the employee for the wallet address behind it: 56 characters starting with G.'

const isAddress = (value: string) => /^G[A-Z2-7]{55}$/.test(value) && StrKey.isValidEd25519PublicKey(value)

/** Names the common wrong codes (a secret key, a muxed or federation address) instead of a generic error. */
function explain(value: string): never {
  if (/^S[A-Z2-7]{55}$/.test(value) && StrKey.isValidEd25519SecretSeed(value)) throw new Error(WALLET_QR_SECRET)
  if (/^M[A-Z2-7]{68}$/.test(value) && StrKey.isValidMed25519PublicKey(value)) throw new Error(WALLET_QR_MUXED)
  if (/^[^*\s]+\*[a-z0-9-]+(\.[a-z0-9-]+)+$/i.test(value)) throw new Error(WALLET_QR_FEDERATION)
  throw new Error(WALLET_QR_INVALID)
}

/** Reads an address only. Payment amounts, assets and URLs are never acted on. */
export function parseWalletQr(raw: string): string {
  const text = raw.trim()
  if (!text || text.length > 8192 || /\s/.test(text)) throw new Error(WALLET_QR_INVALID)
  if (isAddress(text)) return text
  if (!text.startsWith('web+stellar:pay?')) explain(text)
  if (text.includes('#')) throw new Error(WALLET_QR_INVALID)

  const parameters = new Map<string, string>()
  for (const pair of text.slice('web+stellar:pay?'.length).split('&')) {
    const equals = pair.indexOf('=')
    if (equals < 1) throw new Error(WALLET_QR_INVALID)
    let key: string
    let value: string
    try {
      key = decodeURIComponent(pair.slice(0, equals).replaceAll('+', ' '))
      value = decodeURIComponent(pair.slice(equals + 1).replaceAll('+', ' '))
    } catch { throw new Error(WALLET_QR_INVALID) }
    const normalized = key.toLowerCase()
    if (parameters.has(normalized)) throw new Error('This QR code has duplicate fields. Use a QR code with one wallet address.')
    if (normalized === 'memo' || normalized === 'memo_type') {
      throw new Error('This QR code requires a memo. Payroll only supports wallet addresses without a memo.')
    }
    if (normalized === 'destination' && key !== 'destination') throw new Error(WALLET_QR_INVALID)
    parameters.set(normalized, value)
  }
  const address = parameters.get('destination') ?? ''
  if (!isAddress(address)) explain(address)
  return address
}

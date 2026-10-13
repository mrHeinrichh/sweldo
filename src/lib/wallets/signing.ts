import { Keypair, Networks, StrKey, Transaction, TransactionBuilder } from '@stellar/stellar-sdk'
import type { WalletAccount } from './types.ts'

export function requireTestnetAccount(account: WalletAccount, address: string) {
  const onTestnet = account.networkPassphrase
    ? account.networkPassphrase === Networks.TESTNET
    : account.network === 'TESTNET'
  if (!onTestnet) throw new Error('Switch your wallet to Testnet before signing, then reconnect.')
  if (!StrKey.isValidEd25519PublicKey(address) || account.address !== address) {
    throw new Error('The selected wallet account changed. Reconnect the intended account.')
  }
}

export function reviewedTransaction(xdr: string, address: string, networkPassphrase: string) {
  if (networkPassphrase !== Networks.TESTNET) throw new Error('Sweldo signs Stellar Testnet transactions only.')
  const transaction = TransactionBuilder.fromXDR(xdr, Networks.TESTNET)
  if (!(transaction instanceof Transaction) || transaction.source !== address) {
    throw new Error('The transaction source does not match the connected wallet. Nothing was submitted.')
  }
  return transaction
}

/** Validate the returned envelope before allowing submission to Horizon or RPC. */
export function verifiedSignature(original: string, signed: string, address: string, signerAddress?: string) {
  if (!signed) throw new Error('Signing was cancelled. Nothing was submitted.')
  if (signerAddress && signerAddress !== address) throw new Error('The signing wallet account changed. Nothing was submitted.')
  const reviewed = reviewedTransaction(original, address, Networks.TESTNET)
  const returned = reviewedTransaction(signed, address, Networks.TESTNET)
  if (!returned.hash().equals(reviewed.hash())) {
    throw new Error('The signed transaction differs from the reviewed transaction. Nothing was submitted.')
  }
  const key = Keypair.fromPublicKey(address)
  if (!returned.signatures.some((signature) => {
    try { return key.verify(returned.hash(), signature.signature()) } catch { return false }
  })) {
    throw new Error('No valid Testnet signature from the selected wallet was returned. Nothing was submitted.')
  }
  return signed
}

export type KitWalletKind = 'freighter-extension' | 'xbull'
export type KitTransport = {
  address: (kind: KitWalletKind, requestAccess: boolean) => Promise<{ address: string }>
  network: () => Promise<{ network: string; networkPassphrase?: string }>
  sign: (xdr: string, options: { address: string; networkPassphrase: string }) => Promise<{ signedTxXdr: string; signerAddress?: string }>
}

export async function kitAccount(transport: KitTransport, kind: KitWalletKind, requestAccess = false): Promise<WalletAccount> {
  const { address } = await transport.address(kind, requestAccess)
  if (!StrKey.isValidEd25519PublicKey(address)) throw new Error('The wallet did not return a valid Stellar public key.')
  // xBull cannot report its selected network. Each signing request explicitly targets Testnet.
  const network = kind === 'xbull'
    ? { network: 'TESTNET', networkPassphrase: Networks.TESTNET }
    : await transport.network()
  return { address, ...network }
}

export async function signWithKit(transport: KitTransport, kind: KitWalletKind, xdr: string, address: string, networkPassphrase: string) {
  reviewedTransaction(xdr, address, networkPassphrase)
  requireTestnetAccount(await kitAccount(transport, kind), address)
  const result = await transport.sign(xdr, { address, networkPassphrase: Networks.TESTNET })
  return verifiedSignature(xdr, result.signedTxXdr, address, result.signerAddress)
}

import { getNetwork, requestAccess, signTransaction } from '@stellar/freighter-api'
import { Horizon, Networks, TransactionBuilder } from '@stellar/stellar-sdk'
import { prepareClaimConversion, type ConversionQuote, type ConversionReceipt } from './claim-convert.ts'

export class SubmissionUncertain extends Error {
  transactionHash: string
  constructor(hash: string) {
    super('Submission confirmation is unavailable. Check this transaction on Stellar Expert before retrying.')
    this.transactionHash = hash
  }
}

export async function claimAndConvert(server: Horizon.Server, quote: ConversionQuote): Promise<ConversionReceipt> {
  const network = await getNetwork()
  if (network.error) throw new Error(network.error.message || 'Could not read Freighter network.')
  if (network.networkPassphrase !== Networks.TESTNET) throw new Error('Switch Freighter to Testnet before signing.')
  const access = await requestAccess()
  if (access.error) throw new Error(access.error.message || 'Wallet access was rejected.')
  if (access.address !== quote.address) throw new Error('The selected Freighter account changed. Reconnect the worker wallet.')
  const transaction = await prepareClaimConversion(server, quote)
  const signed = await signTransaction(transaction.toXDR(), { address: quote.address, networkPassphrase: Networks.TESTNET })
  if (signed.error) throw new Error(signed.error.message || 'Signing was cancelled. Nothing was submitted.')
  const signedTransaction = TransactionBuilder.fromXDR(signed.signedTxXdr, Networks.TESTNET)
  if (signedTransaction.hash().toString('hex') !== transaction.hash().toString('hex')) {
    throw new Error('The signed transaction did not match the reviewed payout. Nothing was submitted.')
  }
  const hash = transaction.hash().toString('hex')
  try {
    await server.submitTransaction(signedTransaction)
  } catch (error) {
    const codes = (error as { response?: { data?: { extras?: { result_codes?: unknown } } } })?.response?.data?.extras?.result_codes
    if (codes) throw error
    throw new SubmissionUncertain(hash)
  }
  // A delayed Horizon receipt must not turn a successful submission into a retry.
  let receivedAmount: string | null = null
  try {
    const operations = await server.operations().forTransaction(hash).call()
    const payment = operations.records.find((operation) => operation.type === 'path_payment_strict_send')
    if (payment && 'amount' in payment) receivedAmount = payment.amount
  } catch { /* The hash remains the authoritative receipt if Horizon indexing is delayed. */ }
  return { hash, balanceId: quote.balanceId, sentAmount: quote.sendAmount, receivedAmount, minimumAmount: quote.minimumAmount }
}

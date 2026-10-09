import Papa from 'papaparse'
import { StrKey } from '@stellar/stellar-sdk'
import { amountString, amountUnits } from './claim-convert.ts'
import { CADENCES, type Cadence } from './schedule.ts'

export type RosterRow = { employee: string; name: string; total: string }
export type RosterImport = { rows: RosterRow[]; cadence: Cadence }

/** One roster uses one cadence because the existing batch engine shares a pay schedule. */
export function parseRoster(text: string, payouts: number): RosterImport {
  if (text.length > 100_000) throw new Error('Keep the roster under 100 KB.')
  if (!Number.isInteger(payouts) || payouts < 1 || payouts > 50) throw new Error('Choose 1-50 payouts before importing.')
  const parsed = Papa.parse<string[]>(text.trim(), { skipEmptyLines: 'greedy', delimitersToGuess: [',', '\t'] })
  const errors = parsed.errors.filter((error) => error.code !== 'UndetectableDelimiter')
  if (errors.length) throw new Error(`The roster could not be read: ${errors[0].message}`)
  const [head, ...data] = parsed.data
  const headers = head?.map((value) => value.replace(/^\uFEFF/, '').trim().toLowerCase()) ?? []
  const expected = ['wallet', 'name', 'amount', 'cadence']
  if (headers.length !== 4 || !expected.every((key) => headers.includes(key))) {
    throw new Error('Use the header wallet,name,amount,cadence. CSV and tab-separated paste are supported.')
  }
  if (!data.length) throw new Error('Add at least one employee row below the header.')
  if (data.length * payouts > 100) throw new Error(`This roster needs ${data.length * payouts} operations. Keep employees x payouts at 100 or less.`)
  const field = (row: string[], key: string) => row[headers.indexOf(key)]?.trim() ?? ''
  const wallets = new Set<string>()
  let cadence: Cadence | null = null
  const rows = data.map((row, index) => {
    const line = index + 2
    if (row.length !== headers.length) throw new Error(`Row ${line}: expected four columns.`)
    const employee = field(row, 'wallet')
    const name = field(row, 'name')
    const amount = field(row, 'amount')
    const frequency = field(row, 'cadence').toLowerCase()
    if (!StrKey.isValidEd25519PublicKey(employee)) throw new Error(`Row ${line}: enter a valid Stellar G... public key.`)
    if (wallets.has(employee)) throw new Error(`Row ${line}: the same wallet appears more than once.`)
    wallets.add(employee)
    if (!name || name.length > 80) throw new Error(`Row ${line}: use a worker name of 1-80 characters.`)
    let units: bigint
    try { units = amountUnits(amount) } catch { throw new Error(`Row ${line}: use a positive amount with at most seven decimal places.`) }
    if (units <= 0n || units % BigInt(payouts) !== 0n) throw new Error(`Row ${line}: amount must split evenly into ${payouts} payouts without rounding.`)
    if (!Object.hasOwn(CADENCES, frequency)) throw new Error(`Row ${line}: cadence must be minute, day, week, or month.`)
    if (cadence !== null && cadence !== frequency) throw new Error('Use one cadence for the whole roster. Import different cadences as separate batches.')
    cadence = frequency as Cadence
    return { employee, name, total: amountString(units) }
  })
  return { rows, cadence: cadence! }
}

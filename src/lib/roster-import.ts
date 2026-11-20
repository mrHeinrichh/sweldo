import Papa from 'papaparse'
import { StrKey } from '@stellar/stellar-sdk'
import { amountString, amountUnits } from './claim-convert.ts'
import type { Cadence } from './schedule.ts'
import { ROSTER_COLUMNS, ROSTER_HEADER, ROSTER_PLACEHOLDER_PREFIX, type RosterColumn } from './roster-template.ts'

export type RosterRow = { employee: string; name: string; total: string }
export type RosterImport = { rows: RosterRow[]; cadence: Cadence }

/** Every problem in a roster, one line each, so a spreadsheet can be fixed in one pass. */
export class RosterError extends Error {
  readonly issues: string[]
  constructor(issues: string[]) {
    super(issues.join('\n'))
    this.name = 'RosterError'
    this.issues = issues
  }
}

const fail = (issue: string): never => { throw new RosterError([issue]) }

/** Spreadsheets write cadences in several ways; all of these mean the same schedule. */
const CADENCE_WORDS: Record<string, Cadence> = {
  minute: 'minute', minutes: 'minute', minutely: 'minute', 'every minute': 'minute',
  day: 'day', days: 'day', daily: 'day', 'every day': 'day',
  week: 'week', weeks: 'week', weekly: 'week', 'every week': 'week',
  month: 'month', months: 'month', monthly: 'month', 'every month': 'month',
}

/** Accepts 1600, 1600.50 and spreadsheet grouping like 1,600.50, but never a decimal comma like 1,5. */
function rosterUnits(value: string) {
  return amountUnits(/^\d{1,3}(,\d{3})+(\.\d+)?$/.test(value) ? value.replaceAll(',', '') : value)
}

function headerProblem(headers: string[]) {
  const missing = ROSTER_COLUMNS.filter((key) => !headers.includes(key))
  const extra = headers.filter((key) => !(ROSTER_COLUMNS as readonly string[]).includes(key))
  const details = [
    missing.length ? `missing ${missing.join(', ')}` : '',
    extra.length ? `remove ${extra.map((key) => key || '(blank)').join(', ')}` : '',
  ].filter(Boolean).join('; ')
  return `Row 1 must be the header ${ROSTER_HEADER}${details ? ` (${details})` : ''}. CSV and tab-separated paste are supported.`
}

function walletProblem(wallet: string) {
  if (!wallet) return 'add the employee’s Stellar wallet address (56 characters, starts with G).'
  if (wallet.toUpperCase().startsWith(ROSTER_PLACEHOLDER_PREFIX)) {
    return `replace ${wallet} with the employee’s Stellar wallet address (56 characters, starts with G).`
  }
  if (StrKey.isValidEd25519SecretSeed(wallet)) {
    return 'this is a secret key, not a wallet address. Delete it from the file and use the employee’s public address (starts with G).'
  }
  if (StrKey.isValidMed25519PublicKey(wallet)) return 'muxed (M…) addresses can’t receive payroll. Use the employee’s main G… address.'
  if (!StrKey.isValidEd25519PublicKey(wallet)) return 'enter a valid Stellar G… public key: 56 characters starting with G.'
  return null
}

/** One roster uses one cadence because the existing batch engine shares a pay schedule. */
export function parseRoster(text: string, payouts: number): RosterImport {
  if (text.length > 100_000) fail('Keep the roster under 100 KB.')
  if (!Number.isInteger(payouts) || payouts < 1 || payouts > 50) fail('Choose 1-50 payouts before importing.')
  const parsed = Papa.parse<string[]>(text.trim(), { skipEmptyLines: 'greedy', delimitersToGuess: [',', '\t'] })
  const errors = parsed.errors.filter((error) => error.code !== 'UndetectableDelimiter')
  if (errors.length) fail(`The roster could not be read: ${errors[0].message}`)
  const [head, ...data] = parsed.data
  const headers = head?.map((value) => value.replace(/^﻿/, '').trim().toLowerCase()) ?? []
  if (headers.length !== ROSTER_COLUMNS.length || ROSTER_COLUMNS.some((key) => !headers.includes(key))) fail(headerProblem(headers))
  if (!data.length) fail('Add at least one employee row below the header.')
  if (data.length * payouts > 100) {
    fail(`This roster needs ${data.length * payouts} operations. Keep employees × payouts at 100 or less: with ${payouts} payouts, that’s up to ${Math.floor(100 / payouts)} employees.`)
  }

  const issues: string[] = []
  const rows: RosterRow[] = []
  const firstRowFor = new Map<string, number>()
  const cadences = new Set<Cadence>()
  data.forEach((row, index) => {
    const line = index + 2
    const problem = (message: string) => { issues.push(`Row ${line}: ${message}`) }
    if (row.length !== headers.length) return problem(`expected four columns (${ROSTER_COLUMNS.join(', ')}) but found ${row.length}.`)
    const cell = (key: RosterColumn) => row[headers.indexOf(key)]?.trim() ?? ''
    const employee = cell('wallet')
    const name = cell('name')
    const amount = cell('amount')
    const walletIssue = walletProblem(employee)
    if (walletIssue) return problem(walletIssue)
    const firstRow = firstRowFor.get(employee)
    if (firstRow) return problem(`the same wallet appears more than once (also in row ${firstRow}).`)
    firstRowFor.set(employee, line)
    if (name.length > 80) return problem('keep the name to 80 characters or fewer.')
    let units: bigint
    try { units = rosterUnits(amount) } catch {
      return problem(amount
        ? 'write the amount as a plain number like 1600 or 1600.50, with at most seven decimal places and no currency.'
        : 'add the total amount for this employee.')
    }
    if (units <= 0n || units % BigInt(payouts) !== 0n) {
      return problem(`amount must be more than 0 and split evenly into ${payouts} payouts without rounding.`)
    }
    const cadence = CADENCE_WORDS[cell('cadence').toLowerCase().replace(/\s+/g, ' ')]
    if (!cadence) return problem('cadence must be minute, day, week, or month.')
    cadences.add(cadence)
    rows.push({ employee, name, total: amountString(units) })
  })
  if (cadences.size > 1) {
    issues.push(`Use one cadence for the whole roster (found ${[...cadences].join(' and ')}). Import different cadences as separate batches.`)
  }
  if (issues.length) throw new RosterError(issues)
  return { rows, cadence: [...cadences][0] }
}

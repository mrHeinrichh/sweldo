import type { Cadence } from './schedule.ts'

// Mirrors sweldo_flutter/lib/features/payroll/data/roster_import.dart.
export const ROSTER_COLUMNS = ['wallet', 'name', 'amount', 'cadence'] as const
export type RosterColumn = typeof ROSTER_COLUMNS[number]
export const ROSTER_HEADER = ROSTER_COLUMNS.join(',')
/** Sample wallets start with this so an unedited template can be recognised and explained. */
export const ROSTER_PLACEHOLDER_PREFIX = 'REPLACE_WITH_'

/**
 * The template as cells: row 1 is the header, then two sample employees paid
 * 100 and 200 per payout. The on-screen sample and the downloaded file both
 * come from here, so they always match.
 */
export function rosterTemplateRows(payouts: number, cadence: Cadence): string[][] {
  if (!Number.isInteger(payouts) || payouts < 1 || payouts > 50) {
    throw new Error('Choose 1-50 payouts before downloading a roster template.')
  }
  return [
    [...ROSTER_COLUMNS],
    [`${ROSTER_PLACEHOLDER_PREFIX}EMPLOYEE_1_G_ADDRESS`, 'Employee 1', String(100 * payouts), cadence],
    [`${ROSTER_PLACEHOLDER_PREFIX}EMPLOYEE_2_G_ADDRESS`, 'Employee 2', String(200 * payouts), cadence],
  ]
}

/** Sample wallets are intentionally invalid until replaced with employees' public keys. */
export function createRosterTemplate(payouts: number, cadence: Cadence): string {
  return [...rosterTemplateRows(payouts, cadence).map((row) => row.join(',')), ''].join('\r\n')
}

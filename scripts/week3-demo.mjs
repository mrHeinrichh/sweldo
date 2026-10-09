#!/usr/bin/env node
import { reconstructPayroll } from '../src/lib/payroll-ledger.ts'

const [address] = process.argv.slice(2)
try {
  if (!address) throw new Error('Use: npm run week3:inspect -- EMPLOYER_PUBLIC_KEY')
  const result = await reconstructPayroll(address)
  console.log('Stellar Testnet - read-only Horizon reconstruction. No transactions submitted.')
  console.log(`Employer: ${address}\nSchedules: ${result.schedules.length}\nChecked: ${result.checkedAt}`)
  for (const schedule of result.schedules) {
    console.log(`\nWorker: ${schedule.employee}\nTotal: ${schedule.total} ${schedule.asset}`)
    console.log(`Funding: https://stellar.expert/explorer/testnet/tx/${schedule.hash}`)
    for (const payout of schedule.payouts) {
      console.log(`  ${payout.status}: ${payout.amount} ${schedule.asset} | ${payout.unlockAt} | ${payout.balanceId}`)
      if (payout.settlementHash) console.log(`  Proof: https://stellar.expert/explorer/testnet/tx/${payout.settlementHash}`)
    }
  }
  for (const warning of result.warnings) console.warn(warning)
  if (result.warnings.length) process.exitCode = 1
} catch (error) {
  console.error(error.message)
  process.exitCode = 1
}

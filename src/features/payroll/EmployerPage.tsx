import { useLayoutEffect } from 'react'
import { PageFrame } from '../../app/Shell'
import { usePayrollForm } from '../../state/payroll-form'
import { useUp } from '../../ui/hooks'
import { PayrollForm } from './PayrollForm'
import { ScheduleList } from './ScheduleList'
import './payroll.css'

export function EmployerPage() {
  const twoColumns = useUp('lg')
  const { startDraft } = usePayrollForm()
  // Every visit opens a fresh draft with new sample values.
  useLayoutEffect(() => { startDraft() }, []) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <PageFrame title="Pay your team" description="Lock a payroll schedule once. Each payout unlocks on its payday and settles itself.">
      <div className={`employer ${twoColumns ? 'two-columns' : ''}`}>
        <PayrollForm />
        <div className="employer-history"><ScheduleList /></div>
      </div>
    </PageFrame>
  )
}

import { useLayoutEffect } from 'react'
import { PageFrame } from '../../app/Shell'
import { usePayrollForm } from '../../state/payroll-form'
import { useSchedules } from '../../state/schedules'
import { useUp } from '../../ui/hooks'
import { PayrollForm } from './PayrollForm'
import { ScheduleList } from './ScheduleList'
import './payroll.css'

export function EmployerPage() {
  const schedules = useSchedules()
  const { startDraft } = usePayrollForm()
  // Every visit opens a fresh draft with new sample values.
  useLayoutEffect(() => { startDraft() }, []) // eslint-disable-line react-hooks/exhaustive-deps
  // Recent payrolls appear only once there is something to show.
  const hasHistory = schedules.schedules.length > 0 || schedules.notice !== null
  const twoColumns = useUp('lg') && hasHistory

  return (
    <PageFrame title="Pay your team" description="Lock a payroll schedule once. Each payout unlocks on its payday and settles itself.">
      <div className={`employer ${twoColumns ? 'two-columns' : ''}`}>
        <PayrollForm />
        {hasHistory && <div className="employer-history"><ScheduleList /></div>}
      </div>
    </PageFrame>
  )
}

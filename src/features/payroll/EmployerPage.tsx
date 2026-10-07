import { PageFrame } from '../../app/Shell'
import { useSchedules } from '../../state/schedules'
import { useUp } from '../../ui/hooks'
import { PayrollForm } from './PayrollForm'
import { ScheduleList } from './ScheduleList'
import './payroll.css'

export function EmployerPage() {
  const schedules = useSchedules()
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

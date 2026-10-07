import { lazy, Suspense } from 'react'
import { Shell } from './app/Shell'
import { STORY_PATH, useLocation } from './app/router'
import { HomePage } from './features/home/HomePage'
import { TourProvider } from './features/tour/tour'
import { AccountProvider } from './state/account'
import { PayoutsProvider } from './state/payouts'
import { PayrollFormProvider } from './state/payroll-form'
import { SchedulesProvider } from './state/schedules'
import { ToastProvider } from './state/toast'
import { WalletProvider } from './state/wallet'

const EmployerPage = lazy(() => import('./features/payroll/EmployerPage').then((m) => ({ default: m.EmployerPage })))
const EmployeePage = lazy(() => import('./features/payouts/EmployeePage').then((m) => ({ default: m.EmployeePage })))
const StoryPage = lazy(() => import('./features/story/StoryPage').then((m) => ({ default: m.StoryPage })))

const presenting = import.meta.env.VITE_STORY_DEMO === 'true'

function Page() {
  const path = useLocation()
  if (path === '/employer') return <EmployerPage />
  if (path === '/pay') return <EmployeePage />
  if (path === STORY_PATH) return <StoryPage />
  return <HomePage />
}

/**
 * Providers mirror the Flutter app's MultiBlocProvider: wallet, account
 * setup, and the form and lists that survive tab switches.
 */
export default function App() {
  return (
    <ToastProvider>
      <WalletProvider>
        <AccountProvider>
          <PayrollFormProvider>
            <SchedulesProvider>
              <PayoutsProvider>
                <TourProvider autoStart={!presenting}>
                  <Shell>
                    <Suspense fallback={null}>
                      <Page />
                    </Suspense>
                  </Shell>
                </TourProvider>
              </PayoutsProvider>
            </SchedulesProvider>
          </PayrollFormProvider>
        </AccountProvider>
      </WalletProvider>
    </ToastProvider>
  )
}

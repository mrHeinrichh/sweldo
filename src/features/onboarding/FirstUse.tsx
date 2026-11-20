import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react'
import { ArrowRight, Check, ShieldCheck, UsersRound, Wallet } from 'lucide-react'
import { navigate } from '../../app/router'
import { useWallet } from '../../state/wallet'
import { Button } from '../../ui/Button'
import { Dialog } from '../../ui/Dialog'
import './onboarding.css'

type Role = 'employer' | 'employee'
const ROLE_KEY = 'sweldo-role-v1'
const rolePath = (role: Role) => role === 'employer' ? '/employer' : '/pay'

function savedRole(): Role | null {
  try {
    const value = localStorage.getItem(ROLE_KEY)
    return value === 'employer' || value === 'employee' ? value : null
  } catch { return null }
}

/** The role choice comes before the optional guide or a wallet approval. */
export function FirstUse({ children, enabled = true }: { children: ReactNode; enabled?: boolean }) {
  const wallet = useWallet()
  const [role, setRole] = useState<Role | null>(savedRole)
  const [offerWallet, setOfferWallet] = useState(true)
  const routed = useRef(false)

  useEffect(() => {
    if (!enabled || routed.current) return
    routed.current = true
    const path = window.location.hash.replace(/^#/, '').split('?')[0]
    if (role && (!path || path === '/')) navigate(rolePath(role))
  }, [enabled, role])

  const choose = (next: Role) => {
    try { localStorage.setItem(ROLE_KEY, next) } catch { /* The choice still works for this visit. */ }
    setRole(next)
    setOfferWallet(true)
    navigate(rolePath(next))
  }
  const dismissWallet = useCallback(() => setOfferWallet(false), [])
  const keepChoosing = useCallback(() => {}, [])
  const showRole = enabled && role === null
  const showWallet = enabled && role !== null && offerWallet && !wallet.session
    && wallet.status === 'disconnected' && !wallet.sheetOpen

  return (
    <>
      <div inert={showRole || showWallet} aria-hidden={showRole || showWallet || undefined}>{children}</div>
      {showRole && (
        <Dialog label="Choose your role" onClose={keepChoosing} className="first-use-dialog">
          <div className="first-use-step"><span>1</span> Choose your role</div>
          <h1 className="first-use-title">Welcome to Sweldo</h1>
          <p className="t-body-sm first-use-lede">Are you an employer or employee? We’ll take you to the right place.</p>
          <div className="first-use-roles">
            <RoleChoice role="employer" title="I’m an employer" description="Set up payroll, pay your team, and follow each payout." onChoose={choose} />
            <RoleChoice role="employee" title="I’m an employee" description="See your pay schedule and claim money to your wallet." onChoose={choose} />
          </div>
          <p className="t-caption first-use-footnote">You can switch between Pay your team and My pay anytime.</p>
        </Dialog>
      )}
      {showWallet && (
        <Dialog label="Wallet not connected" onClose={dismissWallet} className="first-use-dialog first-use-wallet">
          <div className="first-use-step"><Check size={15} /> Role selected <span>2</span> Connect your wallet</div>
          <span className="first-use-wallet-icon"><Wallet size={30} /></span>
          <h2 className="first-use-title">Wallet not connected</h2>
          <p className="t-body-sm first-use-lede">
            {role === 'employer'
              ? 'Connect your wallet to create payroll and approve payments to your team.'
              : 'Connect the wallet your employer added to payroll to see and claim your pay.'}
          </p>
          <div className="first-use-actions">
            <Button label="Connect it now" icon={<ArrowRight />} large expand onClick={() => { dismissWallet(); wallet.openSheet() }} />
            <Button label="Explore first" tone="quiet" expand onClick={dismissWallet} />
          </div>
          <p className="t-caption first-use-footnote"><ShieldCheck size={15} /> Your wallet stays in your control. Use Testnet to get started.</p>
        </Dialog>
      )}
    </>
  )
}

function RoleChoice({ role, title, description, onChoose }: { role: Role; title: string; description: string; onChoose: (role: Role) => void }) {
  const Icon = role === 'employer' ? UsersRound : Wallet
  return (
    <button type="button" className="first-use-role sw-interactive" onClick={() => onChoose(role)}>
      <span className="first-use-role-icon"><Icon size={24} /></span>
      <span className="first-use-role-copy"><span className="t-subtitle">{title}</span><span className="t-body-sm">{description}</span></span>
      <ArrowRight size={19} className="first-use-role-arrow" />
    </button>
  )
}

import { useState, type ReactNode } from 'react'
import { CalendarClock, Check, Coins, KeyRound, UserRound, X } from 'lucide-react'
import { formatAmount } from '../../state/amount'
import { hasValidAddress, usePayrollForm, type PayrollRecipient } from '../../state/payroll-form'
import { plural } from '../../ui/format'
import { useUp } from '../../ui/hooks'

/** One employee in the payroll form. */
export function RecipientRow({ recipient, index, assetLabel, removable, animateIn, disabled }: {
  recipient: PayrollRecipient; index: number; assetLabel: string; removable: boolean; animateIn: boolean; disabled?: boolean
}) {
  const form = usePayrollForm()
  const payouts = form.state.payouts
  const [addressTouched, setAddressTouched] = useState(false)
  const twoColumns = useUp('md')
  const perPayout = form.amountPerPayout(recipient.total)
  const valid = hasValidAddress(recipient)
  const showAddressError = addressTouched && recipient.employee.length > 0 && !valid
  const change = (patch: Partial<Omit<PayrollRecipient, 'id'>>) => form.changeRecipient(recipient.id, patch)
  const name = recipient.name.trim()

  const nameField = (
    <Field label="Name" hint="Optional">
      <InputBox icon={<UserRound size={18} />}>
        <input
          value={recipient.name}
          placeholder="e.g. Ana Santos"
          autoCapitalize="words"
          disabled={disabled}
          onChange={(event) => change({ name: event.target.value })}
        />
      </InputBox>
    </Field>
  )
  const addressField = (
    <Field label="Wallet address">
      <InputBox icon={valid ? <Check size={18} /> : <KeyRound size={18} />} iconTone={valid ? 'good' : undefined} error={showAddressError}>
        <input
          className="mono-input"
          value={recipient.employee}
          placeholder="G…"
          autoComplete="off"
          autoCorrect="off"
          spellCheck={false}
          disabled={disabled}
          aria-invalid={showAddressError}
          onBlur={() => setAddressTouched(true)}
          onChange={(event) => change({ employee: event.target.value.replace(/\s/g, '').toUpperCase() })}
        />
      </InputBox>
      {showAddressError && <p className="field-error">A Stellar public key has 56 characters and starts with G.</p>}
    </Field>
  )
  const totalField = (
    <Field label="Total pay">
      <InputBox icon={<Coins size={18} />} suffix={assetLabel}>
        <input
          className="figures-input"
          value={recipient.total}
          inputMode="decimal"
          disabled={disabled}
          onChange={(event) => change({ total: event.target.value.replace(/[^0-9.,]/g, '') })}
        />
      </InputBox>
    </Field>
  )
  const splitText = perPayout === '0'
    ? 'Enter an amount to split'
    : `${payouts} ${plural(payouts, 'payout')} of ${formatAmount(perPayout)} ${assetLabel}`
  const split = (
    <div className="recipient-split">
      <CalendarClock size={16} />
      <span key={`${perPayout}/${payouts}`} className="t-body-sm recipient-split-text">{splitText}</span>
    </div>
  )

  return (
    <div className={`recipient ${animateIn ? 'animate-in' : ''}`}>
      <div className="recipient-head">
        <span key={name ? name[0].toUpperCase() : ''} className="recipient-avatar">
          {name ? <span className="t-label">{name[0].toUpperCase()}</span> : <UserRound size={16} />}
        </span>
        <span className="t-subtitle recipient-name">{name || `Employee ${index + 1}`}</span>
        {removable && (
          <button type="button" className="recipient-remove" onClick={() => form.removeRecipient(recipient.id)} title={`Remove employee ${index + 1}`} aria-label={`Remove employee ${index + 1}`}>
            <X size={16} />
          </button>
        )}
      </div>
      {twoColumns
        ? <div className="recipient-grid-top">{nameField}{addressField}</div>
        : <div className="recipient-stack">{nameField}{addressField}</div>}
      {twoColumns
        ? <div className="recipient-grid-bottom">{totalField}{split}</div>
        : <div className="recipient-stack tight">{totalField}{split}</div>}
    </div>
  )
}

function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="field">
      <span className="field-label"><span className="t-label">{label}</span>{hint && <span className="t-caption">{hint}</span>}</span>
      {children}
    </label>
  )
}

function InputBox({ icon, iconTone, suffix, error, children }: { icon: ReactNode; iconTone?: 'good'; suffix?: string; error?: boolean; children: ReactNode }) {
  return (
    <span className={`input-box ${error ? 'error' : ''}`}>
      <span className={`input-icon ${iconTone === 'good' ? 'good' : ''}`}>{icon}</span>
      {children}
      {suffix && <span className="input-suffix t-label">{suffix}</span>}
    </span>
  )
}

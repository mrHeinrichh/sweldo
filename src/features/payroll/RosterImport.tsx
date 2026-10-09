import { useRef, useState } from 'react'
import { FileUp, Upload, X } from 'lucide-react'
import { parseRoster, type RosterImport as ImportedRoster } from '../../lib/roster-import'
import { assetLabel } from '../../state/config'
import { usePayrollForm } from '../../state/payroll-form'
import { Button, IconButton } from '../../ui/Button'
import { KeyText } from '../../ui/KeyText'
import { Sheet } from '../../ui/Sheet'

export function RosterImport() {
  const form = usePayrollForm()
  const [open, setOpen] = useState(false)
  const [text, setText] = useState('')
  const [preview, setPreview] = useState<ImportedRoster | null>(null)
  const [error, setError] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const payoutsRef = useRef(form.state.payouts)
  payoutsRef.current = form.state.payouts
  const changeText = (value: string) => { setText(value); setPreview(null); setError(null) }
  const loadFile = async (file: File | undefined) => {
    if (!file) return
    try {
      if (file.size > 100_000) throw new Error('Keep the roster under 100 KB.')
      changeText(await file.text())
    } catch (problem) { setError(problem instanceof Error ? problem.message : String(problem)) }
  }
  const check = () => {
    try { setPreview(parseRoster(text, form.state.payouts)); setError(null) }
    catch (problem) { setPreview(null); setError(problem instanceof Error ? problem.message : String(problem)) }
  }
  const apply = () => {
    try {
      form.importRoster(parseRoster(text, payoutsRef.current))
      setOpen(false)
    } catch (problem) { setPreview(null); setError(problem instanceof Error ? problem.message : String(problem)) }
  }
  return (
    <>
      <Button label="Import roster" icon={<FileUp />} tone="quiet" disabled={form.state.submitting} onClick={() => setOpen(true)} />
      <Sheet open={open} onClose={() => setOpen(false)} maxWidth={640} label="Import roster">
        <div className="roster-heading">
          <h2 className="t-title m0">Import roster</h2>
          <IconButton icon={<X />} label="Close roster import" onClick={() => setOpen(false)} />
        </div>
        <div className="roster-settings t-body-sm">Total amounts in {assetLabel} / {form.state.payouts} payouts per employee</div>
        <div className="roster-file">
          <Button label="Choose CSV" icon={<Upload />} tone="secondary" onClick={() => fileRef.current?.click()} />
          <input ref={fileRef} type="file" accept=".csv,.tsv,text/csv,text/tab-separated-values" hidden onChange={(event) => { void loadFile(event.target.files?.[0]); event.target.value = '' }} />
        </div>
        <label className="field">
          <span className="t-label">CSV or pasted rows</span>
          <textarea className="roster-text" rows={7} value={text} onChange={(event) => changeText(event.target.value)} placeholder={'wallet,name,amount,cadence\nG...,Ana Santos,6,minute'} spellCheck={false} />
        </label>
        {error && <p role="alert" className="roster-error t-body-sm">{error}</p>}
        {preview && (
          <div className="roster-preview">
            <div className="t-subtitle">{preview.rows.length} employees / {preview.cadence} cadence</div>
            <div className="roster-table-wrap">
              <table className="roster-table">
                <thead><tr><th>Worker</th><th>Wallet</th><th>Total ({assetLabel})</th></tr></thead>
                <tbody>{preview.rows.map((row) => <tr key={row.employee}><td>{row.name}</td><td><KeyText value={row.employee} edge={4} /></td><td>{row.total}</td></tr>)}</tbody>
              </table>
            </div>
          </div>
        )}
        <div className="roster-actions">
          <Button label="Preview roster" tone="secondary" onClick={check} disabled={!text.trim()} />
          {preview && <Button label="Use roster" onClick={apply} />}
        </div>
      </Sheet>
    </>
  )
}

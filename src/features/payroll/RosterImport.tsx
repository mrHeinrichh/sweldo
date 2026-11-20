import { useId, useRef, useState } from 'react'
import { CircleAlert, Download, FilePenLine, FileUp, Upload, X } from 'lucide-react'
import { parseRoster, RosterError, type RosterImport as ImportedRoster } from '../../lib/roster-import'
import { createRosterTemplate, ROSTER_PLACEHOLDER_PREFIX, rosterTemplateRows } from '../../lib/roster-template'
import { usePayrollForm } from '../../state/payroll-form'
import { Button, IconButton } from '../../ui/Button'
import { KeyText } from '../../ui/KeyText'
import { Sheet } from '../../ui/Sheet'

const MAX_SHOWN_ISSUES = 6

/**
 * Import a team from a spreadsheet: a sample of the exact file to fill in,
 * then the file itself, previewed before it replaces the draft.
 * Mirrors sweldo_flutter/lib/features/payroll/view/widgets/roster_import.dart.
 */
export function RosterImport() {
  const form = usePayrollForm()
  const assetLabel = form.assetLabel
  const [open, setOpen] = useState(false)
  const [text, setText] = useState('')
  const [preview, setPreview] = useState<ImportedRoster | null>(null)
  const [issues, setIssues] = useState<string[]>([])
  const fileRef = useRef<HTMLInputElement>(null)
  const textRef = useRef<HTMLTextAreaElement>(null)
  const sampleId = useId()
  const fileId = useId()
  const payouts = form.state.payouts
  const validPayouts = Number.isInteger(payouts) && payouts >= 1 && payouts <= 50
  const sampleRows = validPayouts ? rosterTemplateRows(payouts, form.state.cadence) : null
  const sample = validPayouts ? createRosterTemplate(payouts, form.state.cadence) : ''
  const maxEmployees = validPayouts ? Math.floor(100 / payouts) : 0

  const changeText = (value: string) => { setText(value); setPreview(null); setIssues([]) }
  const fail = (problem: unknown) => {
    setPreview(null)
    setIssues(problem instanceof RosterError ? problem.issues : [problem instanceof Error ? problem.message : String(problem)])
  }
  const downloadTemplate = () => {
    // The byte-order mark makes Excel read the file as UTF-8.
    const url = URL.createObjectURL(new Blob(['﻿', sample], { type: 'text/csv;charset=utf-8' }))
    const link = document.createElement('a')
    link.href = url
    link.download = 'sweldo-roster-template.csv'
    document.body.append(link)
    link.click()
    link.remove()
    window.setTimeout(() => URL.revokeObjectURL(url), 1000)
  }
  const fillHere = () => {
    changeText(sample)
    window.setTimeout(() => {
      const box = textRef.current
      if (!box) return
      box.focus()
      // Select the first placeholder so pasting a wallet replaces it. Indexes
      // come from the box's own value: a textarea turns \r\n into \n.
      const start = box.value.indexOf(ROSTER_PLACEHOLDER_PREFIX)
      if (start >= 0) box.setSelectionRange(start, box.value.indexOf(',', start))
    }, 0)
  }
  const loadFile = async (file: File | undefined) => {
    if (!file) return
    try {
      if (file.size > 100_000) throw new Error('Keep the roster under 100 KB.')
      changeText(await file.text())
    } catch (problem) { fail(problem) }
  }
  const check = () => {
    try { setPreview(parseRoster(text, form.state.payouts)); setIssues([]) } catch (problem) { fail(problem) }
  }
  const apply = () => {
    try {
      form.importRoster(parseRoster(text, form.state.payouts))
      setOpen(false)
    } catch (problem) { fail(problem) }
  }

  return (
    <>
      <Button label="Import roster" icon={<FileUp />} tone="quiet" disabled={form.state.submitting} onClick={() => setOpen(true)} />
      <Sheet open={open} onClose={() => setOpen(false)} maxWidth={720} label="Import roster">
        <div className="roster-heading">
          <h2 className="t-title m0">Import roster</h2>
          <IconButton icon={<X />} label="Close roster import" onClick={() => setOpen(false)} />
        </div>
        <p className="roster-intro t-body-sm">Add your whole team from a spreadsheet. You’ll check every row before it replaces your draft.</p>

        <section className="roster-step" aria-labelledby={sampleId}>
          <div className="roster-step-head">
            <span className="roster-step-number" aria-hidden>1</span>
            <div>
              <h3 id={sampleId} className="t-subtitle m0">Fill in the template</h3>
              <p className="t-body-sm m0">One employee per row, in this column order. Keep row 1 exactly as it is.</p>
            </div>
          </div>
          {sampleRows
            ? <>
              <RosterSample rows={sampleRows} />
              <dl className="roster-legend">
                <div><dt><span aria-hidden>A</span>wallet</dt><dd>The employee’s public address: 56 characters, starts with G.</dd></div>
                <div><dt><span aria-hidden>B</span>name</dt><dd>Optional, up to 80 characters. Quote names with commas: "Santos, Ana".</dd></div>
                <div><dt><span aria-hidden>C</span>amount</dt><dd>Total {assetLabel} for all {payouts} payouts. {100 * payouts} = 100 a payout.</dd></div>
                <div><dt><span aria-hidden>D</span>cadence</dt><dd>minute, day, week or month, the same on every row.</dd></div>
              </dl>
              <div className="roster-template-actions">
                <Button label="Download CSV template" icon={<Download />} tone="secondary" onClick={downloadTemplate} />
                <Button label="Fill it in here" icon={<FilePenLine />} tone="quiet" onClick={fillHere} />
              </div>
            </>
            : <p role="alert" className="roster-error t-body-sm">Choose 1–50 payouts in Schedule before importing.</p>}
        </section>

        <section className="roster-step" aria-labelledby={fileId}>
          <div className="roster-step-head">
            <span className="roster-step-number" aria-hidden>2</span>
            <div>
              <h3 id={fileId} className="t-subtitle m0">Add your file</h3>
              <p className="t-body-sm m0">Choose the CSV you saved, or paste rows straight from your spreadsheet.</p>
            </div>
          </div>
          <div className="roster-file">
            <Button label="Choose CSV file" icon={<Upload />} tone="secondary" onClick={() => fileRef.current?.click()} />
            <input ref={fileRef} type="file" accept=".csv,.tsv,text/csv,text/tab-separated-values" hidden onChange={(event) => { void loadFile(event.target.files?.[0]); event.target.value = '' }} />
          </div>
          <label className="field">
            <span className="t-label">CSV or pasted rows</span>
            <textarea ref={textRef} className="roster-text" rows={6} value={text} onChange={(event) => changeText(event.target.value)} placeholder={sample} spellCheck={false} aria-describedby="roster-input-help" />
            <span id="roster-input-help" className="t-caption">
              {validPayouts ? `With ${payouts} payouts each, one import holds up to ${maxEmployees} ${maxEmployees === 1 ? 'employee' : 'employees'}.` : 'Set your payouts in Schedule first.'} CSV or tab-separated, up to 100 KB.
            </span>
          </label>
          {issues.length > 0 && <RosterIssues issues={issues} />}
          {preview && (
            <div className="roster-preview">
              <div className="t-subtitle">{preview.rows.length} {preview.rows.length === 1 ? 'employee' : 'employees'} · {preview.cadence} cadence</div>
              <p className="t-body-sm roster-preview-help">Choose Use roster to replace the {form.state.recipients.length} {form.state.recipients.length === 1 ? 'employee' : 'employees'} in your draft. You’ll review Schedule and Lock next.</p>
              <div className="roster-table-wrap">
                <table className="roster-table">
                  <thead><tr><th>Employee</th><th>Wallet</th><th>Total ({assetLabel})</th></tr></thead>
                  <tbody>{preview.rows.map((row, index) => (
                    <tr key={row.employee}>
                      <td className={row.name ? undefined : 't-muted'}>{row.name || `Employee ${index + 1}`}</td>
                      <td><KeyText value={row.employee} edge={4} /></td>
                      <td>{row.total}</td>
                    </tr>
                  ))}</tbody>
                </table>
              </div>
            </div>
          )}
        </section>

        <div className="roster-actions">
          <Button label="Preview roster" tone={preview ? 'secondary' : 'primary'} onClick={check} disabled={!text.trim() || !validPayouts} />
          {preview && <Button label="Use roster" onClick={apply} />}
        </div>
      </Sheet>
    </>
  )
}

/** The template as it looks in a spreadsheet: lettered columns, numbered rows, greenbar bands. */
function RosterSample({ rows }: { rows: string[][] }) {
  return (
    <div className="roster-sample" role="region" aria-label="Roster template layout" tabIndex={0}>
      <table>
        <thead aria-hidden>
          <tr><th />{rows[0].map((_, column) => <th key={column}>{String.fromCharCode(65 + column)}</th>)}</tr>
        </thead>
        <tbody>
          {rows.map((row, line) => (
            <tr key={line} className={line === 0 ? 'is-header' : undefined}>
              <th scope="row" aria-hidden>{line + 1}</th>
              {row.map((cell, column) => line === 0
                ? <th key={column} scope="col">{cell}</th>
                : <td key={column} className={cell.startsWith(ROSTER_PLACEHOLDER_PREFIX) ? 'is-placeholder' : undefined}>{cell}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

function RosterIssues({ issues }: { issues: string[] }) {
  const shown = issues.slice(0, MAX_SHOWN_ISSUES)
  return (
    <div role="alert" className="roster-issues">
      <p className="roster-issues-title"><CircleAlert size={16} aria-hidden /> {issues.length === 1 ? 'Fix this, then preview again' : `Fix these ${issues.length} problems, then preview again`}</p>
      <ul>{shown.map((issue, index) => <li key={index}>{issue}</li>)}</ul>
      {issues.length > shown.length && <p className="t-caption m0">…and {issues.length - shown.length} more.</p>}
    </div>
  )
}

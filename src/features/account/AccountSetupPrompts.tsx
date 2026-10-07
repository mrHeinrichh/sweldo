import { Link, PiggyBank } from 'lucide-react'
import { useAccount } from '../../state/account'
import { Button } from '../../ui/Button'
import { Collapse } from '../../ui/Notice'

/** "This wallet is empty" and "Enable USDC" prompts, each shown only while needed. */
export function AccountSetupPrompts({ trustlineMessage }: { trustlineMessage: string }) {
  const account = useAccount()
  const asset = account.assetCode
  const prompt = account.needsFunding
    ? (
      <Prompt key="fund" icon={<PiggyBank size={24} />} title="This wallet is empty" body="Get free Testnet XLM to try Sweldo. It has no real value.">
        <Button label="Get free test XLM" loading={account.funding} onClick={account.fund} />
      </Prompt>
    )
    : account.needsTrustline
      ? (
        <Prompt key="trust" icon={<Link size={24} />} title={`Enable ${asset} in this wallet`} body={trustlineMessage}>
          <Button label={`Enable ${asset}`} tone="secondary" loading={account.enabling} onClick={account.enableAsset} />
        </Prompt>
      )
      : null

  return (
    <Collapse open={prompt !== null}>
      {prompt && (
        <div className="account-prompts">
          {prompt}
          {account.error && <p className="t-caption account-error">{account.error}</p>}
        </div>
      )}
    </Collapse>
  )
}

function Prompt({ icon, title, body, children }: { icon: React.ReactNode; title: string; body: string; children: React.ReactNode }) {
  return (
    <div className="account-prompt">
      <div className="account-prompt-text">
        <span className="account-prompt-icon">{icon}</span>
        <div>
          <div className="t-subtitle">{title}</div>
          <p className="t-body-sm m0" style={{ marginTop: 2 }}>{body}</p>
        </div>
      </div>
      {children}
    </div>
  )
}

import { Coins, Link, PiggyBank } from 'lucide-react'
import { useAccount } from '../../state/account'
import { explorer } from '../../state/config'
import { formatAmount } from '../../state/amount'
import { Button } from '../../ui/Button'
import { Collapse } from '../../ui/Notice'

/** "This wallet is empty" and "Enable USDC" prompts, each shown only while needed. */
export function AccountSetupPrompts({ trustlineMessage, showTestUsdcFunding = true }: { trustlineMessage: string; showTestUsdcFunding?: boolean }) {
  return <AccountSetupPromptsView account={useAccount()} trustlineMessage={trustlineMessage} showTestUsdcFunding={showTestUsdcFunding} />
}

export function AccountSetupPromptsView({ account, trustlineMessage, showTestUsdcFunding = true }: {
  account: ReturnType<typeof useAccount>; trustlineMessage: string; showTestUsdcFunding?: boolean
}) {
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
      : showTestUsdcFunding && asset === 'USDC' && account.faucet && account.balances?.asset === 0
        ? <Prompt key="test-usdc" icon={<Coins size={24} />} title={`${formatAmount(account.balances.asset)} test-USDC available`} body="Local Testnet funds. No real monetary value.">
          <Button label="Get 25 test-USDC" icon={<Coins size={18} />} tone="secondary" loading={account.fundingAsset}
            disabled={account.fundingReceipt?.status === 'pending'} onClick={account.fundAsset} />
        </Prompt>
        : null

  return (
    <Collapse open={prompt !== null || !!account.fundingReceipt?.hash}>
      {(prompt || account.fundingReceipt?.hash) && (
        <div className="account-prompts">
          {prompt}
          {account.error && <p className="t-caption account-error">{account.error}</p>}
          {account.fundingReceipt?.hash && <p className="t-caption" role="status">
            {account.fundingReceipt.status === 'pending' ? 'Funding confirmation pending. Check the transaction before retrying. ' : 'Test-USDC received. '}
            <a href={explorer.transaction(account.fundingReceipt.hash)} target="_blank" rel="noreferrer">View funding transaction</a>
          </p>}
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

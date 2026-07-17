# Sweldo

**Payroll that keeps its promise.** Sweldo is a non-custodial payroll app on Stellar Testnet. An employer signs once to lock an entire pay schedule into protocol-native claimable balances; employees claim each payout (tranche) directly to their own wallet when it unlocks. Employers can cancel only future payouts before payday, while unlocked pay remains protected.

## Why Stellar

Sweldo uses Stellar's native building blocks instead of a custom custody service or smart contract:

- `createClaimableBalance` locks each salary payout with mutually exclusive employee and employer time predicates.
- `claimClaimableBalance` moves unlocked pay directly to the employee.
- Before payday, the employer can use the same operation to return an unearned future payout to the funding wallet.
- Freighter signs every transaction; the app never sees private keys.
- Horizon provides the employee's live vesting timeline.
- Issued assets use standard Stellar trustlines.

## Run locally

Requirements: Node 20+, a [Freighter](https://www.freighter.app/) wallet switched to Testnet, and a funded Testnet account.

```bash
npm install
npm run dev
```

The app uses XLM by default so the complete demo works without asset setup. To use test USDC, copy `.env.example` to `.env.local` and provide the code and issuer of an asset controlled by the employer account.

## Demo flow

1. Open **For employers** and connect a funded Freighter Testnet account.
2. Enter the employee's public key, amount, tranche count, and cadence.
3. For a live demo, select **Every minute** and fund the schedule.
4. Switch Freighter to the employee account and open **For employees**.
5. Watch the countdown reach zero, then claim the unlocked balance.
6. Follow the Stellar Expert links to verify every transaction and balance on-chain.

To demonstrate offboarding, create a schedule with multiple future payouts, stay connected as the employer, and select **Cancel remaining payroll** in Recent schedules. The app excludes payouts whose payday has already arrived.

## Configuration

| Variable | Purpose |
| --- | --- |
| `VITE_ASSET_CODE` | Issued asset code such as `USDC` |
| `VITE_ASSET_ISSUER` | Issuer's Stellar public key |

Both variables are required for issued-asset mode. If omitted, Sweldo uses native XLM. Employees must enable the issued asset before claiming.

## Architecture

The app is fully client-side. React builds operations, Freighter signs them, and the signed transaction is submitted to Stellar Testnet through Horizon. Schedule labels and the on-chain balance IDs needed for the local cancellation controls are stored in localStorage; private keys never enter the app.

## Safety and current scope

- Testnet only; this build does not represent real USDC or production payroll.
- New schedules allow the employer to cancel only future payouts before payday. At payday, the employer predicate expires and the employee predicate activates.
- Schedules created before cancellation support remain irrevocable because existing on-chain claimants cannot be edited.
- Unlocked or claimed pay cannot be cancelled through Sweldo.
- One transaction supports up to 50 tranches in the UI, leaving room below Stellar's 100-operation limit.
- A claimable balance adds ledger reserve requirements for its creator.
- Testnet can reset, so demo accounts and balances may need reseeding.

## Roadmap

- Local anchor integrations and real regional assets
- Claim-and-convert through Stellar path payments
- Bulk payroll import and team administration
- Team-level offboarding policies and approval workflows
- Mainnet hardening, compliance, and independent security review

Built for the APAC Stellar Hackathon 2026.

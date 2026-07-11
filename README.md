# Sweldo

**Payroll that keeps its promise.** Sweldo is a non-custodial payroll app on Stellar Testnet. An employer signs once to lock an entire pay schedule into protocol-native claimable balances; employees claim each tranche directly to their own wallet when it unlocks.

## Why Stellar

Sweldo uses Stellar's native building blocks instead of a custom custody service or smart contract:

- `createClaimableBalance` locks each salary tranche with an absolute-time predicate.
- `claimClaimableBalance` moves unlocked pay directly to the employee.
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

## Configuration

| Variable | Purpose |
| --- | --- |
| `VITE_ASSET_CODE` | Issued asset code such as `USDC` |
| `VITE_ASSET_ISSUER` | Issuer's Stellar public key |

Both variables are required for issued-asset mode. If omitted, Sweldo uses native XLM. Employees must enable the issued asset before claiming.

## Architecture

The app is fully client-side. React builds operations, Freighter signs them, and the signed transaction is submitted to Stellar Testnet through Horizon. Only cosmetic schedule labels are stored in localStorage.

## Safety and current scope

- Testnet only; this build does not represent real USDC or production payroll.
- Schedules are irrevocable once funded. This MVP deliberately does not give employers an unconditional reclaim path.
- One transaction supports up to 50 tranches in the UI, leaving room below Stellar's 100-operation limit.
- A claimable balance adds ledger reserve requirements for its creator.
- Testnet can reset, so demo accounts and balances may need reseeding.

## Roadmap

- Local anchor integrations and real regional assets
- Claim-and-convert through Stellar path payments
- Bulk payroll import and team administration
- Optional, policy-bound offboarding and reclaim flows
- Mainnet hardening, compliance, and independent security review

Built for the APAC Stellar Hackathon 2026.

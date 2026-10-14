# Sweldo

**Payroll that keeps its promise.** Sweldo is a non-custodial payroll app on Stellar Testnet. An employer signs once to lock an entire pay schedule into protocol-native claimable balances; employees claim each payout (tranche) directly to their own wallet when it unlocks. Employers can cancel only future payouts before payday, while unlocked pay remains protected.

Sweldo now includes a Soroban Payroll Registry contract. The contract records payroll schedule proof metadata on Stellar Testnet, while Stellar native claimable balances continue to execute the actual non-custodial payout flow.

## Why Stellar

Sweldo uses Soroban for registry/auditability and Stellar native operations for payout execution:

- `createClaimableBalance` locks each salary payout with mutually exclusive employee and employer time predicates.
- `claimClaimableBalance` moves unlocked pay directly to the employee.
- Before payday, the employer can use the same operation to return an unearned future payout to the funding wallet.
- `contracts/payroll_registry` is a Soroban contract that stores schedule proof references: employer, worker, amount, asset code, cadence, claimable balance ID, and payout transaction hash.
- Your wallet signs every transaction; the app never sees private keys.
- Horizon provides the employee's live vesting timeline.
- Issued assets use standard Stellar trustlines.

## Run locally

Requirements: Node 22.18+, [Freighter](https://www.freighter.app/) or [xBull](https://xbull.app/) for the local Week 4 flow, and a funded Testnet account.

```bash
npm install
npm run dev
```

The app uses XLM by default. The currency dropdown inside **Total pay** on **Pay your team** offers XLM and, when configured, USDC (the controlled Test-USDC asset). It selects the asset for the whole payroll and stays synchronized across employee rows. Choose USDC explicitly for the USDC-to-PHPT flow; trustlines alone do not fund a wallet. Use the existing Week 1/2 configuration helpers for the controlled issuer. No real funds are supported. Historical payouts keep their actual ledger asset when the draft selection changes.

## Soroban contract

The Soroban contract lives in `contracts/payroll_registry`.

```bash
npm run contract:test
npm run contract:build
```

Deploy to Stellar Testnet with the Stellar CLI:

```bash
stellar network add --global testnet \
  --rpc-url https://soroban-testnet.stellar.org \
  --network-passphrase "Test SDF Network ; September 2015"
stellar keys generate --global sweldo-deployer --network testnet
stellar contract deploy \
  --wasm target/wasm32v1-none/release/sweldo_payroll_registry.wasm \
  --source sweldo-deployer \
  --network testnet
```

Set the resulting `C...` contract ID as `VITE_PAYROLL_REGISTRY_CONTRACT_ID` for the web app and submission materials.

Current Testnet deployment:

- Contract ID: `CDAGOOIBW7EUHHHOXXNMFT23YWPE5F352HGKJOFCURU6S2KDG3XQLHUC`
- Wasm hash: `01a64d7e028d336ce305611cb254ddc714e3063c6367ee7a352e6b17681c6e57`
- Wasm upload transaction: `https://stellar.expert/explorer/testnet/tx/cd499f788185ba9fe89d4edffede0e5941926fb1f5f06ac3315aad9d3976a647`
- Contract deploy transaction: `https://stellar.expert/explorer/testnet/tx/a7a4cc42eccc449b83d9a76ccf6db1a77615dfac4922c2cb3f39d14a51966acc`

## Demo flow

1. Open **For employers** and connect a funded Freighter Testnet account.
2. Enter the employee's public key, amount, tranche count, and cadence.
3. For a live demo, select **Every minute** and fund the schedule.
4. Switch Freighter to the employee account and open **For employees**.
5. Watch the countdown reach zero, then claim the unlocked balance.
6. Follow the Stellar Expert links to verify every transaction and balance on-chain.

To demonstrate offboarding, create a schedule with multiple future payouts, stay connected as the employer, and select **Cancel remaining payroll** in Recent schedules. The app excludes payouts whose payday has already arrived.

## Instaward Week 1: PHPT path-payment validation

Week 1 is implemented as a local Testnet harness. It creates controlled PHPT and test-USDC assets, seeds a direct Stellar DEX offer, executes a USDC-to-PHPT strict-send path payment, and stores the transaction evidence in the ignored `.sweldo-local` directory.

```bash
npm run week1:all
```

See [`docs/week-1-testnet-demo.md`](docs/week-1-testnet-demo.md) for the flow chart, individual commands, expected balances, and verification steps. The test-USDC asset has no real value and is not Circle-issued USDC.

## Instaward Week 2: Worker claim-and-convert

The worker UI can claim a scheduled payout as PHPT for the configured Week 1 test-USDC/PHPT pair. It previews a quote with a 1% slippage limit, adds missing trustlines, combines the claim and path payment in one Testnet transaction, and displays a transaction-hash receipt.

```bash
npm run week2:test
npm run week2:configure
npm run week2:dev
```

Tests run locally without sending transactions. The dev server uses ignored `.env.week2.local`. See [the Week 2 flowchart and demo guide](docs/week-2-claim-convert-demo.md) for Testnet preparation, browser steps, expected results, failure checks, and a recording script. The test command requires Node 22.18+.

## Instaward Week 3: Ledger/Horizon payroll state

The employer dashboard reconstructs schedules, balance IDs, payout claims/cancellations and future-payout eligibility from Horizon operation history, creation effects and live claimable balances. A fresh browser can inspect any employer's public Testnet address without copying stored schedules. CSV or spreadsheet paste imports a validated roster into the existing batch funding form.

```bash
npm run week3:test
npm run week3:dev
npm run week3:inspect -- EMPLOYER_PUBLIC_KEY
```

See [the Week 3 flowchart and step-by-step demo](docs/week-3-ledger-payroll-demo.md) and [sample roster](docs/week-3-roster-example.csv). The inspect command only reads Horizon. Worker names are optional session labels; recovered payroll state uses public addresses and ledger records. The development server runs locally; wallet-signed demo transactions use Stellar Testnet.

## Connect with Freighter Mobile

**Connect wallet** offers both Freighters. The browser extension works as before. The Freighter app pairs
over WalletConnect: on a computer Sweldo shows a QR code to scan from the app; on a phone it offers
only the Freighter app and opens it directly through Freighter's registered link
(`freighterwallet://wc-redirect`). If Freighter isn't installed, the phone goes to the App Store or
Google Play instead. Signatures then happen in the app; the action button reads
"Confirm in Freighter…" while one is waiting. A paired session survives reloads.

Pairing needs `VITE_WALLETCONNECT_PROJECT_ID`; without it the option shows as not set up.

## Guide

A highlighting guide walks through the app: it dims the page, spotlights one control at a time, and
explains it, switching between the home, employer and pay pages as it goes. Highlighted controls stay
usable (drag the payout track mid-tour). It opens on a first visit and any time from **Guide** in the
top bar; → / ← move, Esc closes.

## Smart pay schedule

Creating a payroll takes three short steps, each about a screen tall: **Team** (who you're paying),
**Schedule** (when they get paid) and **Review and lock**. The progress bar at the top doubles as
navigation, and on phones Back and Continue stay pinned above the bottom navigation.

The schedule reads as one sentence you edit: "Pay *every week*, *6 times*, starting *in 1 week*."
Each highlighted part opens a menu, including "Pay until a date…" and "On a date…". A 50-slot
payout track sets the count by drag, click or arrow keys and locks slots beyond the team's
one-transaction limit. Presets (live demo, daily, weekly, monthly) fill everything at once. The
review step prints the payroll as a pay summary and checks the first and last payday, transaction
capacity, whether the connected wallet covers the total plus payout reserves, and anything still
missing, with a way back to fix it.

Every visit to **Pay your team** opens a fresh draft with random sample names, pay and schedule.
Wallet addresses are never invented, and any address you typed is kept.

## One design, two clients

[`DESIGN.md`](DESIGN.md) is the design reference for both clients: principles (aligned with
Apple's Human Interface Guidelines), what to avoid, tokens, signature elements, patterns and copy.

The web app and the Flutter app (`sweldo_flutter/`) render the same screens: the same tokens and
type scale, fonts (Archivo, IBM Plex Mono, Manrope for the wordmark), Lucide icons, copy, layout
breakpoints (Tailwind's `sm`/`md`/`lg`/`xl`), motion and story film. They differ only in how they
reach Freighter: the web uses the browser extension or a WalletConnect QR code for the Freighter
app, while iOS and Android open the Freighter app directly.

The React source mirrors the Flutter structure:

| Web (`src/`) | Flutter (`sweldo_flutter/lib/`) |
| --- | --- |
| `styles/tokens.css` | `core/theme/` |
| `ui/` (button, paper, stamp, motion, sheet, dialogs) | `core/widgets/`, `core/motion/` |
| `app/` (shell, hash router) | `app/shell/`, `app/router/` |
| `state/` (wallet, account, payroll form, schedules, payouts) | `features/*/bloc/` |
| `features/home`, `payroll`, `payouts`, `conversion`, `story`, `tour`, `wallet` | `features/*/view/` |
| `lib/` (Stellar, Freighter, claim-and-convert) | `features/*/data/`, `core/stellar/` |

## Configuration

| Variable | Purpose |
| --- | --- |
| `VITE_ASSET_CODE` | Issued asset code such as `USDC` |
| `VITE_ASSET_ISSUER` | Issuer's Stellar public key |
| `VITE_PHPT_ISSUER` | Controlled PHPT Testnet issuer; enables conversion for the configured USDC issuer |
| `VITE_WALLETCONNECT_PROJECT_ID` | Turns on **Freighter Mobile**: a QR code to scan on desktop, a deep link on phones. Free at [dashboard.reown.com](https://dashboard.reown.com); add your site's domain there. |

Both variables are required for issued-asset mode. If omitted, Sweldo uses native XLM. Employees must enable the issued asset before claiming.

## Architecture

The app is fully client-side (React on the web, Flutter on phones). The web client builds payout operations, the connected wallet signs them, and the signed transaction is submitted to Stellar Testnet through Horizon. The existing Soroban Payroll Registry stores optional proof metadata. The web employer dashboard reconstructs payroll schedules, balance IDs and claim/cancellation status from Horizon; worker names remain optional session labels. Private keys never enter the app.

## Week 4 Local Wallets Kit Validation

The web integration uses Stellar Wallets Kit 2.7.1 with Freighter and xBull, preserving the configured Freighter Mobile adapter. Shared Testnet/account/envelope checks cover existing payroll, claim-and-convert, cancellation and Soroban proof signing. The existing Flutter app has matching ledger reconstruction, CSV import and wallet/signing behavior; see the [Flutter parity demo](docs/flutter-web-parity-demo.md). No new contract or mainnet work is included.

```bash
npm run week4:configure
npm run week4:test
npm run week4:dev -- --port 5174 --strictPort
```

Open the local address printed by Vite. Follow the [Week 4 demo and test guide](docs/week-4-wallets-demo.md), [flowchart](docs/week-4-flowchart.svg), and [verification package checklist](docs/week-4-verification-package.md). xBull cannot report its current network; every request explicitly targets Testnet and returned signatures are verified for that network. The Week 4 source and guides are collected on `heinric/week-4-wallets-kit` in [PR #8](https://github.com/mrHeinrichh/sweldo/pull/8). A [demo recording](https://drive.google.com/file/d/1b8a5aGYPnLdT1uSq54mbWJX-d-z0HCRu/view?usp=sharing) is available. The updated deployment and final wallet-by-wallet transaction-hash verification remain pending; publishing the source does not complete those checks.

## Safety and current scope

- Testnet only; this build does not represent real USDC or production payroll.
- Soroban registry records proof metadata only; it does not custody funds or replace claimable balances.
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

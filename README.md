# Sweldo

**Payroll that keeps its promise.** Sweldo is a non-custodial payroll app on Stellar Testnet. An employer signs once to lock an entire pay schedule into protocol-native claimable balances; employees claim each payout (tranche) directly to their own wallet when it unlocks. Employers can cancel only future payouts before payday, while unlocked pay remains protected.

Sweldo now includes a Soroban Payroll Registry contract. The contract records payroll schedule proof metadata on Stellar Testnet, while Stellar native claimable balances continue to execute the actual non-custodial payout flow.

## Why Stellar

Sweldo uses Soroban for registry/auditability and Stellar native operations for payout execution:

- `createClaimableBalance` locks each salary payout with mutually exclusive employee and employer time predicates.
- `claimClaimableBalance` moves unlocked pay directly to the employee.
- Before payday, the employer can use the same operation to return an unearned future payout to the funding wallet.
- `contracts/payroll_registry` is a Soroban contract that stores schedule proof references: employer, worker, amount, asset code, cadence, claimable balance ID, and payout transaction hash.
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

## Connect with Freighter Mobile

**Connect wallet** offers both Freighters. The browser extension works as before. The Freighter app pairs
over WalletConnect: on a computer Sweldo shows a QR code to scan from the app; on a phone it opens
Freighter directly (`freighterwallet://`). Signatures then happen in the app; the action button reads
"Confirm in Freighter…" while one is waiting. A paired session survives reloads.

Pairing needs `VITE_WALLETCONNECT_PROJECT_ID`; without it the option shows as not set up.

## Guide

A highlighting guide walks through the app: it dims the page, spotlights one control at a time, and
explains it, switching between the home, employer and pay pages as it goes. Highlighted controls stay
usable (drag the payout track mid-tour). It opens on a first visit and any time from **Guide** in the
top bar; → / ← move, Esc closes.

## Smart pay schedule

The payroll form reads as one sentence you edit: "Pay *every week*, *6 times*, starting
*in 1 week*." Each highlighted part opens a menu, including "Pay until a date…" and "On a date…".
A 50-slot payout track sets the count by drag, click or arrow keys and locks slots beyond the
team's one-transaction limit. Presets (live demo, daily, weekly, monthly) fill everything at once,
and live insights show the first and last payday, transaction capacity, and whether the connected
wallet covers the total plus payout reserves. **Shuffle** fills the form with random sample values
(wallet addresses are kept). Recent schedules stay hidden until there is one, then collapse.

## One design, two clients

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

The app is fully client-side (React on the web, Flutter on phones). The client builds payout operations, Freighter signs them, and the signed transaction is submitted to Stellar Testnet through Horizon. The Soroban Payroll Registry contract stores schedule proof metadata for reviewer verification and future cross-device reconstruction. Schedule labels and the on-chain balance IDs needed for the current local cancellation controls are still stored in localStorage; private keys never enter the app.

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

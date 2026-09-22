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

## Configuration

| Variable | Purpose |
| --- | --- |
| `VITE_ASSET_CODE` | Issued asset code such as `USDC` |
| `VITE_ASSET_ISSUER` | Issuer's Stellar public key |

Both variables are required for issued-asset mode. If omitted, Sweldo uses native XLM. Employees must enable the issued asset before claiming.

## Architecture

The app is fully client-side. React builds payout operations, Freighter signs them, and the signed transaction is submitted to Stellar Testnet through Horizon. The Soroban Payroll Registry contract stores schedule proof metadata for reviewer verification and future cross-device reconstruction. Schedule labels and the on-chain balance IDs needed for the current local cancellation controls are still stored in localStorage; private keys never enter the app.

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

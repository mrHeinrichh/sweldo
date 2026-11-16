# November 2026 maintenance verification

Updated 16 November 2026 (Asia/Manila).

## Changes

- Renamed wallet labels, install links, errors, story captions, tours and guides to Varial in React and Flutter.
- Upgraded Stellar Wallets Kit to 2.8.0 and selected its `VarialModule` / `varial` product ID. Migrated direct extension access to `@stellar/varial-sdk` 7.0.0, including Flutter’s vendored bridge. The SDK still exposes `window.freighterApi`.
- Kept existing session identifiers, Android package and registered `freighterwallet://wc-redirect` links. Accepted `varial` receipts alongside historical `freighter` receipts without counting the same transaction twice.
- Refreshed dependencies within existing supported major versions, synchronized manifests and lockfiles, and added a single `npm test` command.
- Updated Flutter requirements to 3.47+ / Dart 3.13+, fixed the Cupertino transition import and applied current constructor lint fixes.
- Corrected XLM defaults and added the missing PHPT setting in `.env.example`. Fixed Flutter’s documented WalletConnect pairing route and stale draft-PR / roadmap descriptions.

## Verification

| Check | Result |
| --- | --- |
| Web regression suites | 76 tests pass (19 Week 2, 12 Week 3, 45 Week 4) |
| Web TypeScript / Vite build | Pass |
| npm lockfile installation dry run | Pass |
| Web lint | No errors; 42 React warnings remain |
| Flutter analyzer | Pass after current SDK fixes |
| Flutter regression suites | 96 tests pass |
| Flutter JavaScript web build | Pass; upstream Stellar SDK WASM dry-run warnings remain |
| Shared Flutter wallet bundle | Builds; Varial and xBull signing / Testnet checks pass against mocked bridges |
| React browser QA | Varial/xBull picker and signatures, mainnet rejection, rejected signatures, account changes, disconnect during signing, cancelled late approvals pass |
| Vendored Varial SDK | Authorized account read succeeds against mocked extension messaging |
| Existing Soroban registry | Instance present at Testnet ledger 5754571, checked read-only |

Browser wallet checks use generated Testnet keys and intercepted Horizon reads. No transaction was submitted. They establish integration behavior, not real-wallet approval evidence. Native iOS/Android builds and physical-phone approvals were not rerun for this maintenance update.

## Remaining items

`npm audit fix` applied compatible fixes. npm still reports 29 upstream advisories (11 high, 6 moderate, 12 low), primarily in Wallets Kit’s other-wallet dependency tree. Its proposed forced fix downgrades Wallets Kit to 1.x and is not applied. React lint warnings and large JavaScript chunks remain separate cleanup work.

The supplied Week 4 video and wallet-by-wallet receipts still require manual verification; no sample transaction was relabeled as real evidence. PR #8 is merged. GitHub’s existing Vercel integration deploys branch previews on push. Follow the [Vercel deployment check](https://github.com/mrHeinrichh/sweldo/commits/heinric/week-4-wallets-kit) for the exact deployed revision; the delivery response includes the completed build URL.

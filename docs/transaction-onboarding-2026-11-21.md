# Transaction receipts and first-use flow

Updated 21 November 2026 (Asia/Manila).

## Changes

- React and Flutter now translate Horizon claimable-balance XDR IDs to canonical `B…` StrKeys only at the Stellar Expert link boundary. Transaction builders and ledger recovery keep their original IDs.
- First-time visitors choose Employer or Employee in a centered dialog and open the corresponding page. The choice is remembered. A centered wallet prompt follows, with connection and read-only exploration options. The optional tour remains available from Guide.
- Varial appears first in wallet choices with a recommendation label.
- Progress cards animate while work is pending and show elapsed time, the current operation and completed stages. Wallet approval, Stellar submission and receipt states advance on actual asynchronous results. Returning from a wallet app updates the approval message.
- Wallet restoration and connection approval have bounded waits. Cancellation and late responses cannot silently complete an abandoned connection.
- Narrow phone headers use the existing compact logo, keeping the wallet controls visible. Flutter activity feedback has a height limit for landscape screens.

## Validation

- React regression suites: 88 passing tests, including individual balance links, actual transaction progress sequencing, rejected approvals and late wallet responses.
- React TypeScript/Vite production build: passes. Existing chunk-size warning remains.
- React lint: no errors; existing React warnings remain.
- Flutter analyzer: clean.
- Flutter tests: 109 pass, including first-use dialogs, portrait/landscape shell fit, wallet timeout recovery, and transaction stages.
- Flutter JavaScript web build: passes; verified output is `/private/tmp/sweldo-flutter-web-20261121` (the existing ignored `build/web` folder has stale iCloud placeholders).
- Browser QA covers desktop role choice, both destinations, remembered role routing, connect/explore actions, Varial ordering and mobile dialog fit. Progress cards were visually inspected at 390px and 320px widths and checked for completed-stage transitions.

Verification uses mocks for wallet/ledger events; no new signed transaction was submitted. Physical-phone wallet approval has not been rerun. Dependency reads in the iCloud-backed workspace stalled, so the React production build and complete tests ran from a clean dependency installation in `/private/tmp/sweldo-onboarding-qa` using the current source.

## Deployment

Published to the existing Vercel project `stellar-hackathon` (`prj_gBTSVsFuqap6Vck5CtFCUVD3FIfL`) after authorizing its existing connection through the user's Opera session. Production deployment `dpl_CnZtZgjfy8JxH2LLyy4d22bMyMvk` reports `READY`, with `getsweldo.com` assigned and no alias error. The remote build passed. The API upload includes the required build declaration and committed public production configuration; local environment files are excluded.

Production URL: https://getsweldo.com

The live browser smoke check was stopped because the user was actively using Opera. The production deployment and domain assignment are verified through Vercel; the interaction checks above were completed against the local production preview. Flutter source and its web build are updated; native app-store distribution was not performed.

# Sweldo Week 4 Verification Package

Status: **Week 4 source release; final deployment and receipt verification pending**. The web/Flutter implementation, tests and guides are collected on `heinric/week-4-wallets-kit` in [PR #8](https://github.com/mrHeinrichh/sweldo/pull/8). The PR remains a draft while release verification is completed. Publishing source is not a claim that all SOW acceptance evidence is complete.

Demo: [Week4.mov](https://drive.google.com/file/d/1b8a5aGYPnLdT1uSq54mbWJX-d-z0HCRu/view?usp=sharing). The supplied recording is 5:21 and shows the local wallet menu and a locked test-USDC payroll. It predates the final funding-prompt visibility fix. Its full wallet/hash coverage has not been independently verified; trim or replace it for the SOW's 3-5 minute final package.

## Required evidence

| Item | Local source / what to supply | Status |
| --- | --- | --- |
| How-it-works notes and exact steps | [Week 4 demo guide](week-4-wallets-demo.md) | Included in PR #8 |
| Wallet/data flow | [Week 4 flowchart](week-4-flowchart.svg) | Included in PR #8 |
| Automated wallet checks | `npm run week4:test` | Run locally; not live wallet evidence |
| Regression checks | `npm run week2:test` and `npm run week3:test` | Run locally |
| Existing Flutter parity | [Native/web demo](flutter-web-parity-demo.md), `flutter analyze` and `flutter test` | Local implementation; real phone approvals still needed |
| Wallet signing recordings | Freighter and xBull connections, selected public keys, Testnet approval dialogs | Demo supplied; verify both wallets against actual receipts |
| Testnet receipts | `.sweldo-local/week4-receipts.json` and the read-only verification report | Fill with actual Week 4 hashes |
| Fresh browser proof | Employer key only; matching schedule, IDs, statuses and receipt links | Record the actual result |
| 3-5 minute demo | Google Drive link above; reviewer access enabled | Supplied video is 5:21; final-length version pending |
| Weekly GitHub PR | [PR #8](https://github.com/mrHeinrichh/sweldo/pull/8), branch `heinric/week-4-wallets-kit` | Week 4 source and guides included; draft |
| Updated live dApp URL | Deployment of this exact revision | Not performed by the source push |

## Receipt list to complete

| Wallet used | Action | Public signer account | Transaction hash / Stellar Expert URL | Related video time |
| --- | --- | --- | --- | --- |
| Freighter | Funding or supported worker claim/conversion | Fill after signing | Fill after success | Fill after recording |
| xBull | Funding or supported worker claim/conversion | Fill after signing | Fill after success | Fill after recording |
| Selected employer wallet | Optional existing Soroban registry proof | Fill if recorded | Fill if successful | Fill if recorded |
| Selected employer wallet | Optional pre-deadline cancellation | Fill if tested | Fill if successful | Fill if recorded |

Include at least one supported claim-and-convert transaction across the two wallets. If a payout is prepared by a terminal fixture, its funding hash proves Testnet activity but not either wallet's signing capability. Preserve the expected payout file until that conversion is verified.

An employer claim before the worker deadline is a cancellation, not a worker payout. Historical Week 1/2/3 transactions are background evidence and must not be relabeled as newly shipped Week 4 wallet receipts. Automated fixtures and mocked wallet tests are engineering QA only.

## Submission readiness

Do not claim final delivery yet if any of these remain missing:

- Actual Freighter and xBull wallet-signing recordings and successful receipts.
- Supported PHPT conversion proof and fresh-session payroll reconstruction proof.
- An accessible 3-5 minute video and completed receipt list.
- Updated deployment of the same code and verification of its public accessibility.

The linked PR and supplied video are real evidence sources. No sample hash is presented as a real receipt, and no private credentials are included.

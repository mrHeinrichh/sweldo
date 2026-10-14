# Sweldo Website and Flutter Parity

Update to the existing Flutter app, requested separately from the SOW's exclusion of new mobile-app development. No new contract, asset pair, mainnet, billing or banking functionality. The parity implementation, wallet bridge and tests are collected on `heinric/week-4-wallets-kit` in [PR #8](https://github.com/mrHeinrichh/sweldo/pull/8). An updated deployment and physical-phone wallet-signing verification remain pending.

Parity requirement: user-facing updates must be implemented and tested in both React and Flutter before being described as complete. Wallet transport can differ by platform, but supported payroll outcomes, validation, receipts and error behavior must stay aligned.

## Matching Workflows

| Workflow | React website | Flutter web and phones |
| --- | --- | --- |
| Batch payroll, worker claims and optional registry proof | Existing flow | Existing flow |
| Payroll asset selection | XLM default; configured Test-USDC opt-in | Same dropdown, labels and funding requirements |
| Controlled USDC to PHPT | Quote, 1% minimum, atomic claim/path payment | Same rules and issuer pair |
| Employer payroll recovery | Horizon history, effects and live balances | Same ledger-backed fields |
| Cancellation | Verified future balances only | Verified future balances only |
| CSV or pasted roster | Preview then apply | Preview then apply |
| Freighter | Kit extension / configured WalletConnect | Kit extension on web / configured mobile WalletConnect |
| xBull | Stellar Wallets Kit | Shared Kit on web / isolated wallet approval window on phones |
| Signing guards | Testnet, account, unchanged hash, valid signature | Shared Kit plus Dart guards |
| Explorer receipts | Actual successful hashes | Actual successful hashes |

Native screens remain Flutter; only the wallet approval bridge uses JavaScript. xBull cannot report its selected network: each request targets Testnet and returned signatures are verified for Testnet. Names are optional session labels, not ledger data. Mainnet is unsupported everywhere.

## Start From the Beginning

In the repository root:

```bash
npm run flutter:wallet-kit
npm run flutter:configure
cd sweldo_flutter
flutter pub get
flutter run -d chrome --dart-define-from-file=config/testnet.local.json
```

The configure command copies only public Week 1 asset identities and preserves existing registry and WalletConnect settings. The generated Kit bundle and local configuration are ignored by Git. Rebuild the bundle after changing the shared wallet adapter.

For a phone, run `flutter devices`, then:

```bash
flutter run -d YOUR_DEVICE_ID --dart-define-from-file=config/testnet.local.json
```

Replace the placeholder with the device ID Flutter prints. Freighter mobile needs a valid `WALLETCONNECT_PROJECT_ID` in the local config and Freighter installed. Browser extensions are intentionally not offered on phones. Use dedicated Testnet wallets, never the grant-payment wallet. Never paste recovery phrases or passwords into Sweldo, a CSV, recordings or source control.

React: http://localhost:5174/. Built Flutter preview: http://localhost:5180/. Use `localhost` rather than `127.0.0.1` for the xBull extension: its HTTP content-script permissions cover only the localhost hostname. These are local hosts, not new deployments of getsweldo.com. Manual signed tests still communicate with public Stellar Testnet.

### Local Test-USDC Button

In a debug build configured with `SWELDO_TEST_FAUCET_URL=http://localhost:5174`, **Pay your team** offers the same **Get 25 test-USDC** button as the website after selecting **USDC** in the currency dropdown at the right edge of **Total pay**, once the employer has test XLM and the configured USDC trustline. This is the controlled Test-USDC asset. XLM is the default and needs no USDC faucet. **My pay** checks the actual payout asset for receiving trustlines and does not request extra USDC funding for a worker. Keep the local Week 4 Vite server running. The funding prompt is visible only at a known zero balance and hides for any positive USDC balance, including balances below 25. The transaction receipt remains visible after successful funding. Release builds and remote/mainnet faucet URLs are not supported. A phone must be able to reach the local server (for example Android USB port reversal or the emulator's `10.0.2.2` host alias); this is not a new public deployment. Issuer keys are never copied into app configuration or the wallet bridge.

## 1. Recover Payroll Without Connecting

1. Close the first-visit guide and open **Pay your team**.
2. In **Payroll history**, enter the employer public key and select **Load payroll**.
3. Repeat on React and in a fresh Flutter browser session or phone installation.
4. Compare totals, worker keys, funding hashes, balance IDs, deadlines and claim/cancellation receipts.

Read-only example from Week 2/3:

```text
GA63TYUUORN4FLT2QWWUVL37ERXZ5OTCEQWCIRO3PR3PYB6JUUYKGLH4
```

Expected: financial fields recover without copying local storage. On 13 October 2026 this account recovered one 25 controlled-USDC payout marked Claimable. Historical state can change or disappear after a Testnet reset. Missing balances without a successful claim receipt remain **Unverified**, not assumed claimed. No wallet approval or submission occurs in this test.

## 2. Import a Team

1. Select **USDC** in the currency dropdown inside **Total pay**, enter one worker public key in **Team**, then open **Schedule**. Leave XLM selected instead to test the original native-asset payroll. Changing any employee's currency selector updates the whole payroll.
2. Choose three payouts and return to **Team**.
3. Select **Import roster** and choose a CSV or paste:

```csv
wallet,name,amount,cadence
GB5OYIHNYJKUP6VFZHYCPLFHBF63SWIDZAPBXET4NKEFLEPWPMKIETPL,Ana Santos,6,minute
GCSRX5WXQJ6PGNNSQ4VIVQAIRFL2MK4SFINU6VO55QASSRWW46HMQYNR,Marco Reyes,9,minute
```

4. Select **Preview roster**, inspect the two workers, then **Use roster**.
5. Check **Schedule** and **Lock** without approving a transaction yet.

Expected: two workers, minute cadence, three payouts each, totals 6 and 9 USDC, and six claimable-balance operations. Sample public keys are formatting examples; replace them with tester-controlled wallets for a signed demo. Duplicates, invalid keys, mixed cadence, oversized files, indivisible amounts and batches exceeding 100 operations are rejected.

Switching the dropdown changes the new draft's units without converting the numeric amounts. Both clients return to Team for a fresh review and keep historical schedules/receipts in their original asset. The dropdown is disabled during payroll submission or funding/trustline approval. A fresh app session defaults to XLM. Worker XLM and USDC totals remain separate; only supported USDC payouts can convert to PHPT.

## 3. Connect, Fund and Claim

1. Choose **Connect wallet**, then Freighter or xBull.
2. Use the employer/worker roles and funded Testnet prerequisites in the [Week 4 website demo](week-4-wallets-demo.md). The employer cannot be its own employee.
3. Confirm the public key and Testnet, review a small payroll and approve in the wallet.
4. Record the successful funding receipt, not only an approval dialog.
5. Disconnect, connect the intended worker, and open **My pay**.
6. Once unlocked, choose **Claim as PHPT**, review the quote/minimum and approve.
7. Inspect the successful claim plus strict-send path payment on Stellar Expert.

Expected: controlled USDC converts atomically into PHPT at least equal to the quoted minimum, with an actual hash. Missing liquidity, insufficient test reserves, account changes, rejection or expired quotes must not produce a success receipt.

On native xBull, the isolated page opens at `wallet.xbull.app`. If no wallet is configured, the **Open xBull wallet** globe control opens its setup page in that same wallet context. Set up a dedicated Testnet wallet yourself, cancel the pending request and reconnect. Native WebView wallet storage is separate from Safari/Chrome, not an automatic connection to an installed xBull wallet. Sweldo registers no result handler or key-reading script in that remote wallet page. The close control cancels the request. This path still needs owner-approved signing before claiming full native wallet verification.

The native xBull adapter is a Testnet integration with third-party wallet code in an embedded context, not a hardened production wallet container. Never use a production wallet or real funds in it. Freighter's external mobile app remains the existing native WalletConnect option.

## 4. Negative Checks

Reject a signature, select Mainnet, switch accounts after connecting, cancel before approval, or disconnect while signing. Expected: no submission or success receipt. Cancellation requires the wallet that funded the schedule, and only verified balances before their deadlines are eligible. Fresh clients recover financial fields; optional names can become Team member.

## QA and Remaining Evidence

```bash
npm run week2:test
npm run week3:test
npm run week4:test
cd sweldo_flutter
flutter analyze
flutter test
flutter build web --dart-define-from-file=config/testnet.local.json
flutter build apk --debug --dart-define-from-file=config/testnet.local.json
```

96 Flutter tests pass, including asset selection, asset-specific payroll submission/proof, mixed-asset totals, stale balance reads, responsive dropdown checks, and zero-balance-only funding prompts. React has 75 automated tests across Weeks 2-4, including rendering the actual funding view with explicit test account states and no live wallet. React and Flutter web builds compile; Android/iOS simulator compilation was verified before the asset selector update, not rerun for this UI change. Earlier browser QA exercised the bundled Freighter/xBull Kit modules and Flutter's Freighter JS interop against mocked wallet bridges, including Testnet signature checks and mainnet rejection. Android emulator QA opened xBull's real connection page and cancelled without entering keys or submitting transactions. A [web demo recording](https://drive.google.com/file/d/1b8a5aGYPnLdT1uSq54mbWJX-d-z0HCRu/view?usp=sharing) is available; final wallet-by-wallet receipt verification and physical-phone testing remain pending.

The default iOS simulator build on this Mac fails because the iCloud-backed Documents folder re-adds Finder metadata to generated framework bundles. Compilation succeeded with Xcode build products outside that folder:

```bash
cd sweldo_flutter
flutter build ios --simulator --config-only --dart-define-from-file=config/testnet.local.json
cd ios
xcrun xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  SYMROOT=/private/tmp/sweldo-week4-ios-build \
  CONFIGURATION_BUILD_DIR=/private/tmp/sweldo-week4-ios-build/Debug-iphonesimulator \
  CODE_SIGNING_ALLOWED=NO
```

This verifies simulator compilation, not physical-device signing or an iPhone wallet demo. No global Flutter configuration or user source was changed to work around the host metadata issue.

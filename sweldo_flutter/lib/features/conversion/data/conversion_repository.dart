import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/stellar/horizon_client.dart';
import '../../../core/utils/amount.dart';
import '../../../core/utils/parallel.dart';
import '../../payouts/domain/payout.dart';
import '../../wallet/data/wallet_repository.dart';
import '../domain/conversion_pair.dart';
import '../domain/conversion_quote.dart';

/// Claim a payout and convert it to PHPT through Stellar's DEX in one
/// atomic transaction (port of `claim-convert.ts` and
/// `claim-convert-wallet.ts`).
class ConversionRepository {
  ConversionRepository(
    this._horizon,
    this._wallet, {
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final HorizonClient _horizon;
  final WalletRepository _wallet;
  final DateTime Function() _now;

  Future<ConversionQuote> quote({
    required String address,
    required String balanceId,
    required ConversionPair pair,
  }) async {
    final (payout, account, ledger) = await all3(
      _currentPayout(balanceId),
      _horizon.loadAccount(address),
      _horizon.latestLedger(),
    );
    if (payout.asset != pair.sourceCanonical) {
      throw const UserFacingException(
        'Only the configured test-USDC issuer is supported for PHPT conversion.',
      );
    }
    final ledgerTime = DateTime.tryParse(ledger.closedAt);
    if (ledgerTime == null) {
      throw const UserFacingException(
        'Could not verify the latest Stellar ledger. Please refresh.',
      );
    }
    checkPayout(payout, address, ledgerTime);

    final source = pair.sourceCredit;
    final destination = pair.destinationCredit;
    final sendUnits = Amount.units(payout.amount);
    final routes = await _horizon.strictSendPaths(
      source: pair.source,
      amount: payout.amount,
      destination: pair.destination,
    );
    final choices =
        routes
            .where(
              (route) =>
                  route.destinationAssetCode == destination.code &&
                  route.destinationAssetIssuer == destination.issuerId &&
                  route.sourceAssetCode == source.code &&
                  route.sourceAssetIssuer == source.issuerId &&
                  Amount.units(route.sourceAmount) == sendUnits &&
                  Amount.units(route.destinationAmount) > BigInt.zero,
            )
            .toList()
          ..sort(
            (a, b) => Amount.units(
              b.destinationAmount,
            ).compareTo(Amount.units(a.destinationAmount)),
          );
    final best = choices.firstOrNull;
    if (best == null) {
      throw const UserFacingException(
        'No USDC to PHPT liquidity is available for this payout. Nothing was '
        'claimed. Refresh the quote after liquidity is restored.',
      );
    }
    return ConversionQuote(
      address: address,
      balanceId: balanceId,
      source: source,
      destination: destination,
      sendAmount: payout.amount,
      expectedAmount: best.destinationAmount,
      minimumAmount: Amount.minimumReceived(best.destinationAmount),
      path: best.path,
      missingTrustlines: checkTrustlines(
        account,
        source,
        destination,
        payout.amount,
        best.destinationAmount,
      ),
      expiresAt: _now().add(quoteLifetime),
    );
  }

  /// Re-reads the ledger and builds the exact transaction to sign.
  Future<Transaction> prepare(ConversionQuote quote) async {
    final (account, payout, ledger) = await all3(
      _horizon.loadAccount(quote.address),
      _currentPayout(quote.balanceId),
      _horizon.latestLedger(),
    );
    return buildClaimConversion(
      account: account,
      payout: payout,
      quote: quote,
      baseFee: ledger.baseFeeInStroops,
      now: _now(),
    );
  }

  Future<ConversionReceipt> claimAndConvert(ConversionQuote quote) async {
    await _wallet.ensureActiveAccount(quote.address);
    final transaction = await prepare(quote);
    final hash = transactionHashHex(transaction);

    final signed = await _wallet.signTransaction(
      transaction.toEnvelopeXdrBase64(),
      address: quote.address,
    );
    final signedTransaction = AbstractTransaction.fromEnvelopeXdrString(signed);
    if (transactionHashHex(signedTransaction) != hash) {
      throw const UserFacingException(
        'The signed transaction did not match the reviewed payout. Nothing '
        'was submitted.',
      );
    }

    try {
      await _horizon.submit(signed);
    } on StellarRejectedException {
      rethrow;
    } catch (_) {
      throw SubmissionUncertainException(hash);
    }

    // A delayed Horizon receipt must not turn a successful submission into a
    // retry: the hash stays the authoritative receipt.
    String? received;
    try {
      final operations = await _horizon.operationsForTransaction(hash);
      received = operations
          .whereType<PathPaymentStrictSendOperationResponse>()
          .firstOrNull
          ?.amount;
    } catch (_) {}

    return ConversionReceipt(
      hash: hash,
      balanceId: quote.balanceId,
      sentAmount: quote.sendAmount,
      receivedAmount: received,
      minimumAmount: quote.minimumAmount,
    );
  }

  Future<Payout> _currentPayout(String balanceId) async {
    try {
      return Payout.fromResponse(await _horizon.claimableBalance(balanceId));
    } on NotFoundException {
      throw const UserFacingException(
        'This payout is no longer available. Refresh your pay list.',
      );
    }
  }
}

/// Builds the atomic transaction: missing trustlines, claim, path payment.
/// Every operation rolls back together if the claim or conversion fails.
Transaction buildClaimConversion({
  required AccountResponse account,
  required Payout payout,
  required ConversionQuote quote,
  required int baseFee,
  required DateTime now,
}) {
  if (quote.isExpired(now)) {
    throw const UserFacingException(
      'Your quote expired. Refresh it before signing.',
    );
  }
  if (account.accountId != quote.address ||
      payout.balanceId != quote.balanceId ||
      payout.asset != '${quote.source.code}:${quote.source.issuerId}' ||
      Amount.units(payout.amount) != Amount.units(quote.sendAmount)) {
    throw const UserFacingException(
      'The wallet or payout changed. Refresh the quote.',
    );
  }
  checkPayout(payout, quote.address, now);
  final missing = checkTrustlines(
    account,
    quote.source,
    quote.destination,
    quote.sendAmount,
    quote.expectedAmount,
  );

  final secondsLeft = quote.expiresAt.difference(now).inSeconds;
  final builder = newTransaction(
    account,
    baseFee: baseFee,
    timeout: Duration(seconds: secondsLeft < 1 ? 1 : secondsLeft),
    now: now,
  );
  for (final asset in missing) {
    builder.addOperation(
      ChangeTrustOperationBuilder(
        asset,
        ChangeTrustOperationBuilder.MAX_LIMIT,
      ).build(),
    );
  }
  builder
    ..addOperation(
      ClaimClaimableBalanceOperationBuilder(quote.balanceId).build(),
    )
    ..addOperation(
      PathPaymentStrictSendOperationBuilder(
        quote.source,
        quote.sendAmount,
        quote.address,
        quote.destination,
        quote.minimumAmount,
      ).setPath(quote.path).build(),
    );
  return builder.build();
}

void checkPayout(Payout payout, String address, DateTime ledgerTime) {
  final claimant = payout.claimantFor(address);
  if (claimant == null) {
    throw const UserFacingException(
      'This wallet is not a claimant for this payout.',
    );
  }
  if (!claimant.predicate.allows(ledgerTime)) {
    throw const UserFacingException(
      'This payout is still locked on the Stellar ledger. Wait for payday '
      'and refresh.',
    );
  }
  if (Amount.units(payout.amount) <= BigInt.zero) {
    throw const UserFacingException('The payout amount must be positive.');
  }
}

/// Trustlines the worker still needs. Throws when one exists but can't
/// receive the incoming amount.
List<AssetTypeCreditAlphaNum> checkTrustlines(
  AccountResponse account,
  AssetTypeCreditAlphaNum source,
  AssetTypeCreditAlphaNum destination,
  String send,
  String receive,
) {
  final missing = <AssetTypeCreditAlphaNum>[];
  for (final (asset, incoming) in [(source, send), (destination, receive)]) {
    if (account.accountId == asset.issuerId) {
      throw const UserFacingException(
        'Use a worker wallet, not an asset issuer, for this demo.',
      );
    }
    final line = account.balances
        .where(
          (b) =>
              b.assetType != Asset.TYPE_NATIVE &&
              b.assetCode == asset.code &&
              b.assetIssuer == asset.issuerId,
        )
        .firstOrNull;
    if (line == null) {
      missing.add(asset);
      continue;
    }
    if (line.isAuthorized != true) {
      throw UserFacingException(
        '${asset.code} trustline is not authorized by its issuer.',
      );
    }
    final capacity =
        Amount.units(line.limit ?? '0') -
        Amount.units(line.balance) -
        Amount.units(line.buyingLiabilities ?? '0');
    if (capacity < Amount.units(incoming)) {
      throw UserFacingException(
        '${asset.code} trustline limit is too low. Increase its limit in '
        'your wallet.',
      );
    }
  }
  return missing;
}

/// Exposed for symmetry with the web app's `supportsConversion`.
bool supportsConversion(Payout payout, ConversionPair? pair) =>
    pair != null && payout.asset == pair.sourceCanonical;

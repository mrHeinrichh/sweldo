import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../error/app_exception.dart';
import 'stellar_network.dart';

/// Thin, testable wrapper over Horizon (Testnet) used by every repository.
class HorizonClient {
  HorizonClient({StellarSDK? sdk, http.Client? httpClient})
    : sdk = sdk ?? StellarSDK(StellarNetwork.horizonUrl),
      _http = httpClient ?? http.Client();

  final StellarSDK sdk;
  final http.Client _http;

  Future<AccountResponse> loadAccount(String address) =>
      _guard(() => sdk.accounts.account(address));

  Future<bool> isFunded(String address) async {
    try {
      await loadAccount(address);
      return true;
    } on NotFoundException {
      return false;
    }
  }

  Future<String> xlmBalance(String address) async {
    final account = await loadAccount(address);
    return account.balances
            .where((b) => b.assetType == Asset.TYPE_NATIVE)
            .firstOrNull
            ?.balance ??
        '0';
  }

  Future<bool> hasTrustline(String address, Asset asset) async {
    if (asset is! AssetTypeCreditAlphaNum) return true;
    try {
      final account = await loadAccount(address);
      return account.balances.any(
        (b) => b.assetCode == asset.code && b.assetIssuer == asset.issuerId,
      );
    } on NotFoundException {
      return false;
    }
  }

  /// Friendbot is Stellar's public Testnet faucet; it sends valueless XLM.
  Future<void> fundWithFriendbot(String address) async {
    final uri = Uri.parse(
      StellarNetwork.friendbotUrl,
    ).replace(queryParameters: {'addr': address});
    final response = await _http.get(uri);
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = response.body;
    if (body.contains('op_already_exists') || body.contains('already funded')) {
      return;
    }
    throw const UserFacingException(
      'The free test-money service is busy. Wait a moment and try again.',
    );
  }

  Future<List<ClaimableBalanceResponse>> claimableBalancesFor(
    String claimant,
  ) async {
    final page = await _guard(
      () => sdk.claimableBalances
          .forClaimant(claimant)
          .limit(100)
          .order(RequestBuilderOrder.DESC)
          .execute(),
    );
    return page.records;
  }

  Future<ClaimableBalanceResponse> claimableBalance(String balanceId) =>
      _guard(() => sdk.claimableBalances.forBalanceId(balanceId));

  Future<List<OperationResponse>> operationsForAccount(
    String address, {
    int limit = 50,
  }) async {
    final page = await _guard(
      () => sdk.operations
          .forAccount(address)
          .limit(limit)
          .order(RequestBuilderOrder.DESC)
          .execute(),
    );
    return page.records;
  }

  Future<List<OperationResponse>> operationsForTransaction(String hash) async {
    final page = await _guard(
      () => sdk.operations.forTransaction(hash).execute(),
    );
    return page.records;
  }

  Future<LedgerResponse> latestLedger() async {
    final page = await _guard(
      () => sdk.ledgers.order(RequestBuilderOrder.DESC).limit(1).execute(),
    );
    final ledger = page.records.firstOrNull;
    if (ledger == null) {
      throw const UserFacingException(
        'Could not verify the latest Stellar ledger. Please refresh.',
      );
    }
    return ledger;
  }

  Future<List<PathResponse>> strictSendPaths({
    required Asset source,
    required String amount,
    required Asset destination,
  }) async {
    final page = await _guard(
      () => sdk.strictSendPaths
          .sourceAsset(source)
          .sourceAmount(amount)
          .destinationAssets([destination])
          .execute(),
    );
    return page.records;
  }

  /// Submits a signed envelope and throws [StellarRejectedException] when
  /// Horizon answers with result codes.
  Future<SubmitTransactionResponse> submit(String signedEnvelopeXdr) async {
    final response = await sdk.submitTransactionEnvelopeXdrBase64(
      signedEnvelopeXdr,
      skipMemoRequiredCheck: true,
    );
    if (!response.success) {
      final codes = response.extras?.resultCodes;
      throw StellarRejectedException(
        transactionCode: codes?.transactionResultCode,
        operationCodes:
            codes?.operationsResultCodes?.whereType<String>().toList() ??
            const [],
      );
    }
    return response;
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ErrorResponse catch (error) {
      if (error.code == 404) throw const NotFoundException();
      rethrow;
    }
  }
}

/// Builds a transaction with the same fee and 180-second timeout as the web app.
TransactionBuilder newTransaction(
  TransactionBuilderAccount account, {
  int baseFee = 100,
  Duration timeout = StellarNetwork.transactionTimeout,
  DateTime? now,
}) {
  final issuedAt = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  final preconditions = TransactionPreconditions()
    ..timeBounds = TimeBounds(0, issuedAt + timeout.inSeconds);
  return TransactionBuilder(account)
    ..setMaxOperationFee(baseFee)
    ..addPreconditions(preconditions);
}

String transactionHashHex(AbstractTransaction transaction) =>
    Util.bytesToHex(transaction.hash(StellarNetwork.network));

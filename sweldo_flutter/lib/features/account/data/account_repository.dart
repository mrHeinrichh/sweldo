import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/stellar/horizon_client.dart';
import '../../../core/stellar/transaction_signer.dart';

class WalletBalances {
  const WalletBalances({
    required this.xlm,
    required this.asset,
    required this.reservedXlm,
  });

  final String xlm;
  final String asset;

  /// XLM the account must keep as its own minimum balance.
  final double reservedXlm;
}

/// Funding a practice wallet and opening trustlines.
class AccountRepository {
  AccountRepository(this._horizon, this._submitter);

  final HorizonClient _horizon;
  final TransactionSubmitter _submitter;

  Future<bool> isFunded(String address) => _horizon.isFunded(address);

  Future<void> fundWithFriendbot(String address) =>
      _horizon.fundWithFriendbot(address);

  Future<bool> hasTrustline(String address, Asset asset) =>
      _horizon.hasTrustline(address, asset);

  /// XLM and payroll-asset balances, or null for an unfunded wallet.
  Future<WalletBalances?> balances(String address, Asset asset) async {
    try {
      final account = await _horizon.loadAccount(address);
      String find(bool Function(Balance b) match) =>
          account.balances.where(match).firstOrNull?.balance ?? '0';
      final xlm = find((b) => b.assetType == Asset.TYPE_NATIVE);
      final assetBalance = asset is AssetTypeCreditAlphaNum
          ? find(
              (b) =>
                  b.assetCode == asset.code && b.assetIssuer == asset.issuerId,
            )
          : xlm;
      return WalletBalances(
        xlm: xlm,
        asset: assetBalance,
        // Base reserve for the account and each entry it already holds.
        reservedXlm: (2 + account.subentryCount) * 0.5,
      );
    } on NotFoundException {
      return null;
    }
  }

  Future<String> addTrustline(String address, Asset asset) async {
    if (asset is AssetTypeNative) {
      throw const UserFacingException('XLM does not need a trustline.');
    }
    final transaction = newTransaction(await _horizon.loadAccount(address))
        .addOperation(
          ChangeTrustOperationBuilder(
            asset,
            ChangeTrustOperationBuilder.MAX_LIMIT,
          ).build(),
        )
        .build();
    final response = await _submitter.signAndSubmit(
      transaction,
      address: address,
    );
    return response.hash ?? transactionHashHex(transaction);
  }
}

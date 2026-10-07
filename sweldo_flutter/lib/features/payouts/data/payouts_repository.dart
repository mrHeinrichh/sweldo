import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/stellar/horizon_client.dart';
import '../../../core/stellar/transaction_signer.dart';
import '../domain/claim_record.dart';
import '../domain/payout.dart';

class PayoutsRepository {
  PayoutsRepository(this._horizon, this._submitter);

  final HorizonClient _horizon;
  final TransactionSubmitter _submitter;

  /// Every claimable balance addressed to [address], newest first.
  Future<List<Payout>> payoutsFor(String address) async {
    final records = await _horizon.claimableBalancesFor(address);
    return records.map(Payout.fromResponse).toList();
  }

  /// Claims recorded on the ledger for [address].
  Future<List<ClaimRecord>> claimHistory(String address) async {
    final List<OperationResponse> operations;
    try {
      operations = await _horizon.operationsForAccount(address);
    } on NotFoundException {
      // Horizon answers 404 for a never-funded account: no history yet.
      return const [];
    }
    return operations
        .whereType<ClaimClaimableBalanceOperationResponse>()
        .map(
          (op) => ClaimRecord(
            id: op.id,
            balanceId: op.balanceId,
            transactionHash: op.transactionHash,
            claimedAt: DateTime.tryParse(op.createdAt) ?? DateTime.now(),
            source: ClaimSource.stellar,
          ),
        )
        .toList();
  }

  /// Claims one unlocked payout into [address]. Returns the transaction hash.
  Future<String> claim(String address, String balanceId) async {
    final transaction = newTransaction(await _horizon.loadAccount(address))
        .addOperation(ClaimClaimableBalanceOperationBuilder(balanceId).build())
        .build();
    final response = await _submitter.signAndSubmit(
      transaction,
      address: address,
    );
    return response.hash ?? transactionHashHex(transaction);
  }
}

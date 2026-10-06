import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/stellar/horizon_client.dart';
import '../../../core/stellar/stellar_network.dart';
import '../../../core/stellar/transaction_signer.dart';

class ScheduleRecipient {
  const ScheduleRecipient({
    required this.employee,
    required this.amountPerPayout,
  });

  final String employee;
  final String amountPerPayout;
}

class BatchScheduleResult {
  const BatchScheduleResult({required this.hash, required this.balanceIds});

  final String hash;

  /// In operation order: employee 0's payouts, then employee 1's, …
  final List<String> balanceIds;
}

/// Builds and submits payroll transactions. All money logic lives on Stellar:
/// this only describes operations and asks the wallet to sign them.
class PayrollRepository {
  PayrollRepository(this._horizon, this._submitter);

  final HorizonClient _horizon;
  final TransactionSubmitter _submitter;

  /// One transaction, one `createClaimableBalance` per payout per employee.
  ///
  /// Each payout has two mutually exclusive claimants:
  /// * the employee, only at or after payday — `not(before(payday))`;
  /// * the employer, only before payday — `before(payday)`, which is how
  ///   future payouts can be cancelled while unlocked pay stays protected.
  Future<BatchScheduleResult> createBatchSchedule({
    required String employer,
    required List<ScheduleRecipient> recipients,
    required int payouts,
    required DateTime firstUnlock,
    required int intervalSeconds,
    required Asset asset,
  }) async {
    final operationCount = recipients.length * payouts;
    if (operationCount < 1) {
      throw const UserFacingException(
        'Add at least one employee before locking payroll.',
      );
    }
    if (operationCount > StellarNetwork.maxOperationsPerTransaction) {
      throw const UserFacingException(
        'A Stellar transaction can include up to 100 payroll payouts. '
        'Reduce employees or payouts.',
      );
    }

    final transaction = buildBatchTransaction(
      account: await _horizon.loadAccount(employer),
      employer: employer,
      recipients: recipients,
      payouts: payouts,
      firstUnlock: firstUnlock,
      intervalSeconds: intervalSeconds,
      asset: asset,
    );
    final response = await _submitter.signAndSubmit(
      transaction,
      address: employer,
    );
    return BatchScheduleResult(
      hash: response.hash ?? transactionHashHex(transaction),
      balanceIds: [
        for (var i = 0; i < operationCount; i++)
          ?_horizonBalanceId(response.getClaimableBalanceIdIdFromResult(i)),
      ],
    );
  }

  /// Returns future payouts to the employer. Valid only before each payday,
  /// enforced by the ledger itself.
  Future<String> cancelBalances(String address, List<String> balanceIds) async {
    if (balanceIds.isEmpty) {
      throw const UserFacingException(
        'There are no future payouts available to cancel.',
      );
    }
    if (balanceIds.length > StellarNetwork.maxOperationsPerTransaction) {
      throw const UserFacingException(
        'A Stellar transaction can cancel up to 100 payouts at once.',
      );
    }
    final builder = newTransaction(await _horizon.loadAccount(address));
    for (final id in balanceIds) {
      builder.addOperation(ClaimClaimableBalanceOperationBuilder(id).build());
    }
    final transaction = builder.build();
    final response = await _submitter.signAndSubmit(
      transaction,
      address: address,
    );
    return response.hash ?? transactionHashHex(transaction);
  }

  /// Balance IDs still on the ledger with [address] as a claimant.
  Future<List<String>> activeBalanceIds(String address) async {
    final records = await _horizon.claimableBalancesFor(address);
    return records.map((r) => r.balanceId).toList();
  }

  /// The SDK returns the bare 32-byte hash; Horizon prefixes the 4-byte
  /// `ClaimableBalanceIdType` discriminant (V0 = 00000000).
  static String? _horizonBalanceId(String? hash) {
    if (hash == null) return null;
    return hash.length == 64 ? '00000000$hash' : hash;
  }
}

/// Pure transaction construction, separated for tests.
Transaction buildBatchTransaction({
  required TransactionBuilderAccount account,
  required String employer,
  required List<ScheduleRecipient> recipients,
  required int payouts,
  required DateTime firstUnlock,
  required int intervalSeconds,
  required Asset asset,
  DateTime? now,
}) {
  final builder = newTransaction(account, now: now);
  final firstUnix = firstUnlock.millisecondsSinceEpoch ~/ 1000;
  for (final recipient in recipients) {
    for (var index = 0; index < payouts; index++) {
      final unlockUnix = firstUnix + index * intervalSeconds;
      final employeeClaimant = Claimant(
        recipient.employee,
        Claimant.predicateNot(Claimant.predicateBeforeAbsoluteTime(unlockUnix)),
      );
      final employerClaimant = Claimant(
        employer,
        Claimant.predicateBeforeAbsoluteTime(unlockUnix),
      );
      builder.addOperation(
        CreateClaimableBalanceOperationBuilder(
          [employeeClaimant, employerClaimant],
          asset,
          recipient.amountPerPayout,
        ).build(),
      );
    }
  }
  return builder.build();
}

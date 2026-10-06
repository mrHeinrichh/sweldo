import 'dart:math';
import 'dart:typed_data';

import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/stellar/horizon_client.dart';
import '../../../core/stellar/stellar_network.dart';
import '../../../core/stellar/transaction_signer.dart';
import '../../../core/utils/amount.dart';

class RegistryProof {
  const RegistryProof({
    required this.hash,
    required this.contractId,
    required this.scheduleId,
  });

  final String hash;
  final String contractId;
  final String scheduleId;
}

/// Records schedule proof metadata in the Soroban Payroll Registry
/// (`record_schedule`). The registry never holds funds; claimable balances
/// still execute every payout.
class RegistryRepository {
  RegistryRepository({
    required this.contractId,
    required HorizonClient horizon,
    required TransactionSubmitter submitter,
    SorobanServer? soroban,
    Random? random,
  }) : _horizon = horizon,
       _submitter = submitter,
       _soroban = soroban ?? SorobanServer(StellarNetwork.sorobanRpcUrl),
       _random = random ?? Random.secure();

  final String contractId;
  final HorizonClient _horizon;
  final TransactionSubmitter _submitter;
  final SorobanServer _soroban;
  final Random _random;

  bool get isConfigured => contractId.isNotEmpty;

  /// Returns null when no registry is configured for this build.
  Future<RegistryProof?> recordScheduleProof({
    required String employer,
    required String employee,
    required String total,
    required String asset,
    required int cadenceSeconds,
    required String claimableBalanceId,
    required String payoutTxHash,
  }) async {
    if (!isConfigured) return null;

    final scheduleId = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    final amount = Amount.tryUnits(total);
    if (amount == null || amount <= BigInt.zero) {
      throw const UserFacingException('The registry needs a positive amount.');
    }

    final function = InvokeContractHostFunction(
      contractId,
      'record_schedule',
      arguments: [
        XdrSCVal.forBytes(scheduleId),
        XdrSCVal.forAccountAddress(employer),
        XdrSCVal.forAccountAddress(employee),
        XdrSCVal.forI128BigInt(amount),
        XdrSCVal.forString(asset),
        XdrSCVal.forU64(BigInt.from(cadenceSeconds)),
        XdrSCVal.forString(claimableBalanceId),
        XdrSCVal.forBytes(Util.hexToBytes(payoutTxHash)),
      ],
    );
    final transaction = newTransaction(
      await _horizon.loadAccount(employer),
    ).addOperation(InvokeHostFuncOpBuilder(function).build()).build();

    // Simulate to learn the footprint and resource fee. The employer is the
    // transaction source, so its authorization rides on the envelope
    // signature (legacy credential arm works on every protocol version).
    final simulation = await _soroban.simulateTransaction(
      SimulateTransactionRequest(transaction, useUpgradedAuth: false),
    );
    final transactionData = simulation.transactionData;
    if (simulation.resultError != null || transactionData == null) {
      throw UserFacingException(
        'Soroban registry simulation failed: ${simulation.resultError ?? 'no resource data'}',
      );
    }
    transaction
      ..sorobanTransactionData = transactionData
      ..addResourceFee(simulation.minResourceFee ?? 0)
      ..setSorobanAuth(simulation.sorobanAuth);

    final signed = await _submitter.sign(transaction, address: employer);
    final signedTransaction = AbstractTransaction.fromEnvelopeXdrString(signed);
    if (signedTransaction is! Transaction) {
      throw const UserFacingException('Unexpected signed registry envelope.');
    }
    final sent = await _soroban.sendTransaction(signedTransaction);
    final hash = sent.hash ?? transactionHashHex(transaction);
    if (sent.status == SendTransactionResponse.STATUS_ERROR) {
      throw UserFacingException(
        'Soroban registry proof failed: ${sent.errorResultXdr ?? 'rejected'}',
      );
    }

    final proof = RegistryProof(
      hash: hash,
      contractId: contractId,
      scheduleId: Util.bytesToHex(scheduleId),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      final result = await _soroban.getTransaction(hash);
      if (result.status == GetTransactionResponse.STATUS_SUCCESS) return proof;
      if (result.status == GetTransactionResponse.STATUS_FAILED) {
        throw const UserFacingException(
          'Soroban registry proof failed on-chain.',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return proof;
  }
}

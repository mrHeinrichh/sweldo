import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'horizon_client.dart';
import 'transaction_activity.dart';

/// Anything that can put a user's signature on a transaction envelope.
///
/// Implemented by the wallet feature (Varial extension or Varial Mobile).
/// Keys never enter Sweldo: the wallet receives unsigned XDR and returns it
/// signed.
abstract interface class TransactionSigner {
  Future<String> signTransaction(String envelopeXdr, {required String address});
}

/// Signs with the connected wallet, then submits through Horizon.
class TransactionSubmitter {
  TransactionSubmitter(this._horizon, this._signer);

  final HorizonClient _horizon;
  final TransactionSigner _signer;

  Future<SubmitTransactionResponse> signAndSubmit(
    Transaction transaction, {
    required String address,
  }) async {
    final token = beginTransactionActivity();
    try {
      updateTransactionActivity(token, TransactionStage.approval);
      final signed = await _signer.signTransaction(
        transaction.toEnvelopeXdrBase64(),
        address: address,
      );
      updateTransactionActivity(token, TransactionStage.submitting);
      final response = await _horizon.submit(signed);
      updateTransactionActivity(token, TransactionStage.confirming);
      return response;
    } finally {
      endTransactionActivity(token);
    }
  }

  Future<String> sign(Transaction transaction, {required String address}) =>
      _signer.signTransaction(
        transaction.toEnvelopeXdrBase64(),
        address: address,
      );
}

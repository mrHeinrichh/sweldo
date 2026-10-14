import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/stellar/stellar_network.dart';

Transaction reviewedTransaction(String xdr, String address) {
  try {
    final transaction = AbstractTransaction.fromEnvelopeXdrString(xdr);
    if (transaction is Transaction &&
        transaction.sourceAccount.accountId == address &&
        StrKey.isValidStellarAccountId(address)) {
      return transaction;
    }
  } catch (_) {
    // Malformed envelopes must not reach a wallet or Horizon.
  }
  throw const WalletException(
    'The transaction source does not match the connected wallet. Nothing was submitted.',
  );
}

String verifiedSignature(String original, String signed, String address) {
  final reviewed = reviewedTransaction(original, address);
  final returned = reviewedTransaction(signed, address);
  final hash = returned.hash(StellarNetwork.network);
  if (!listEquals(reviewed.hash(StellarNetwork.network), hash)) {
    throw const WalletException(
      'The signed transaction differs from the reviewed transaction. Nothing was submitted.',
    );
  }
  final key = KeyPair.fromAccountId(address);
  final verified = returned.signatures.any((signature) {
    try {
      return key.verify(hash, signature.signature.signature);
    } catch (_) {
      return false;
    }
  });
  if (!verified) {
    throw const WalletException(
      'No valid Testnet signature from the selected wallet was returned. Nothing was submitted.',
    );
  }
  return signed;
}

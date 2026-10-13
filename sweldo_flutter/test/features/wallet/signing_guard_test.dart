import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/error/app_exception.dart';
import 'package:sweldo/features/wallet/data/signing_guard.dart';

void main() {
  final key = KeyPair.random();
  final recipient = KeyPair.random();
  Transaction transaction({String amount = '1'}) =>
      TransactionBuilder(Account(key.accountId, BigInt.one))
          .addOperation(
            PaymentOperationBuilder(
              recipient.accountId,
              Asset.NATIVE,
              amount,
            ).build(),
          )
          .addPreconditions(
            TransactionPreconditions()..timeBounds = TimeBounds(0, 2000000000),
          )
          .build();
  String signed(Transaction tx, [Network? network, KeyPair? signer]) {
    tx.sign(signer ?? key, network ?? Network.TESTNET);
    return tx.toEnvelopeXdrBase64();
  }

  test(
    'accepts the reviewed transaction with the selected Testnet signature',
    () {
      final tx = transaction();
      final original = tx.toEnvelopeXdrBase64();
      expect(
        verifiedSignature(original, signed(tx), key.accountId),
        isNotEmpty,
      );
    },
  );
  test(
    'rejects mainnet, another signer, altered transaction and unsigned XDR',
    () {
      final original = transaction().toEnvelopeXdrBase64();
      for (final xdr in [
        signed(transaction(), Network.PUBLIC),
        signed(transaction(), null, recipient),
        signed(transaction(amount: '2')),
        original,
        'bad',
      ]) {
        expect(
          () => verifiedSignature(original, xdr, key.accountId),
          throwsA(isA<WalletException>()),
        );
      }
      expect(
        () => reviewedTransaction(original, recipient.accountId),
        throwsA(isA<WalletException>()),
      );
    },
  );
}

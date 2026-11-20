import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/stellar/horizon_client.dart';
import 'package:sweldo/core/stellar/transaction_activity.dart';
import 'package:sweldo/core/stellar/transaction_signer.dart';
import 'package:sweldo/core/widgets/operation_progress.dart';

class _Horizon extends Mock implements HorizonClient {}

class _Signer extends Mock implements TransactionSigner {}

class _Response extends Mock implements SubmitTransactionResponse {}

void main() {
  tearDown(() => transactionActivity.value = null);

  test(
    'progress waits for the signature and confirmation before completing',
    () async {
      final key = KeyPair.random().accountId;
      final transaction = TransactionBuilder(Account(key, BigInt.one))
          .addOperation(
            PaymentOperationBuilder(
              KeyPair.random().accountId,
              Asset.NATIVE,
              '1',
            ).build(),
          )
          .build();
      final signer = _Signer();
      final horizon = _Horizon();
      final signature = Completer<String>();
      final confirmation = Completer<SubmitTransactionResponse>();
      when(
        () => signer.signTransaction(
          transaction.toEnvelopeXdrBase64(),
          address: key,
        ),
      ).thenAnswer((_) => signature.future);
      when(() => horizon.submit('signed'))
          .thenAnswer((_) => confirmation.future);
      final pending = TransactionSubmitter(
        horizon,
        signer,
      ).signAndSubmit(transaction, address: key);
      expect(transactionActivity.value!.stage, TransactionStage.approval);
      markTransactionWalletReturn();
      expect(transactionActivity.value!.returnedFromWallet, isTrue);
      signature.complete('signed');
      await Future<void>.delayed(Duration.zero);
      expect(transactionActivity.value!.stage, TransactionStage.submitting);
      confirmation.complete(_Response());
      await pending;
      expect(transactionActivity.value, isNull);
    },
  );

  test('an old completion cannot clear a newer operation', () {
    final first = beginTransactionActivity();
    transactionActivity.value = TransactionActivity(
      startedAt: first.add(const Duration(seconds: 1)),
      stage: TransactionStage.approval,
    );
    endTransactionActivity(first);
    expect(transactionActivity.value, isNotNull);
  });

  testWidgets('progress shows elapsed time and truthful completed stages', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OperationProgress(
            title: 'Connecting your wallet',
            message: 'Approve in Varial.',
            steps: ['Request', 'Approval', 'Connected'],
            currentStep: 1,
            slowMessage: 'Check the pending wallet request.',
          ),
        ),
      ),
    );
    expect(find.text('0s elapsed · 1 of 3 steps complete'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationProgress(
            title: 'Connecting your wallet',
            message: 'Approve in Varial.',
            steps: const ['Request', 'Approval', 'Connected'],
            currentStep: 1,
            startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
            slowMessage: 'Check the pending wallet request.',
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Check the pending wallet request.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

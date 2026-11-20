import 'package:flutter/foundation.dart';

enum TransactionStage { preparing, approval, submitting, confirming }

@immutable
class TransactionActivity {
  const TransactionActivity({
    required this.startedAt,
    required this.stage,
    this.returnedFromWallet = false,
  });

  final DateTime startedAt;
  final TransactionStage stage;
  final bool returnedFromWallet;
}

/// Transient feedback shared by wallet signing and the submission service.
/// Stages only advance when the corresponding operation actually completes.
final transactionActivity = ValueNotifier<TransactionActivity?>(null);

DateTime beginTransactionActivity() {
  final token = DateTime.now();
  transactionActivity.value = TransactionActivity(
    startedAt: token,
    stage: TransactionStage.preparing,
  );
  return token;
}

void updateTransactionActivity(DateTime token, TransactionStage stage) {
  if (transactionActivity.value?.startedAt != token) return;
  transactionActivity.value = TransactionActivity(
    startedAt: token,
    stage: stage,
  );
}

void endTransactionActivity(DateTime token) {
  if (transactionActivity.value?.startedAt == token) {
    transactionActivity.value = null;
  }
}

void markTransactionWalletReturn() {
  final current = transactionActivity.value;
  if (current == null || current.stage != TransactionStage.approval) return;
  transactionActivity.value = TransactionActivity(
    startedAt: current.startedAt,
    stage: current.stage,
    returnedFromWallet: true,
  );
}

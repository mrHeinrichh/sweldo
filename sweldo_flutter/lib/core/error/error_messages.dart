import 'package:http/http.dart' as http;
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'app_exception.dart';

/// Translates any failure into copy that says what happened and what to do.
String friendlyError(Object error) {
  if (isNotFound(error)) {
    return "This wallet isn't on Stellar Testnet yet. Use “Get free test XLM”, "
        'then try again.';
  }
  return switch (error) {
    StellarRejectedException(:final allCodes) =>
      _rejectedMessage(allCodes) ??
          'Stellar rejected the transaction (${allCodes.join(', ')}).',
    AppException(:final message) => message,
    TooManyRequestsException() =>
      'Stellar Testnet is rate-limiting requests. Wait a few seconds and retry.',
    http.ClientException() =>
      "Couldn't reach Stellar Testnet. Check your connection and retry.",
    FormatException(:final message) => message,
    StateError(:final message) => message,
    _ => error.toString(),
  };
}

/// Mapping used by the claim-and-convert flow (`conversionError` in React).
String conversionError(Object error) {
  if (error is StellarRejectedException) {
    final ops = error.operationCodes;
    final tx = error.transactionCode;
    if (ops.contains('op_under_dest_min')) {
      return 'The PHPT rate moved beyond the 1% limit. Nothing was claimed or '
          'converted. Refresh the quote.';
    }
    if (ops.contains('op_too_few_offers')) {
      return 'There is no longer enough liquidity. Nothing was claimed or '
          'converted. Refresh the quote.';
    }
    if (ops.contains('op_low_reserve') || tx == 'tx_insufficient_balance') {
      return 'Not enough test XLM for trustline reserves and fees. Fund the '
          'worker wallet and retry.';
    }
    const trustCodes = {
      'op_no_trust',
      'op_src_no_trust',
      'op_line_full',
      'op_not_authorized',
      'op_src_not_authorized',
    };
    if (ops.any(trustCodes.contains)) {
      return 'Check the test-USDC and PHPT trustline authorization and limits. '
          'Nothing was claimed or converted.';
    }
    if (ops.contains('op_cannot_claim')) {
      return 'The payout is locked or this wallet cannot claim it. Refresh your '
          'pay list.';
    }
    if (ops.contains('op_does_not_exist')) {
      return 'The payout was already claimed or cancelled. Refresh your pay '
          'list.';
    }
    if (tx == 'tx_too_late') {
      return 'Your quote expired while signing. Nothing was claimed. Refresh '
          'the quote.';
    }
    if (tx == 'tx_bad_seq') {
      return 'Your wallet changed while signing. Refresh the quote and try '
          'again.';
    }
    return 'Stellar rejected the transaction (${error.allCodes.join(', ')}). '
        'No payout operations were applied.';
  }
  return friendlyError(error);
}

String? _rejectedMessage(List<String> codes) {
  if (codes.contains('op_underfunded') ||
      codes.contains('tx_insufficient_balance')) {
    return "This wallet doesn't hold enough to lock that payroll, including "
        'a 1 XLM reserve per payout. Lower the amount or fund the wallet.';
  }
  if (codes.contains('op_no_trust') || codes.contains('op_src_no_trust')) {
    return 'A wallet in this payroll has no trustline for the asset. Enable '
        'the asset first.';
  }
  if (codes.contains('op_cannot_claim')) {
    return 'This payout is still locked, or this wallet cannot claim it.';
  }
  if (codes.contains('op_does_not_exist')) {
    return 'That payout was already claimed or cancelled. Refresh the list.';
  }
  if (codes.contains('tx_bad_seq')) {
    return 'Your wallet sent another transaction meanwhile. Try again.';
  }
  if (codes.contains('tx_too_late')) {
    return 'The transaction expired before it was signed. Try again.';
  }
  return null;
}

bool isNotFound(Object error) =>
    error is NotFoundException || (error is ErrorResponse && error.code == 404);

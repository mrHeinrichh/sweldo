import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/core/error/app_exception.dart';
import 'package:sweldo/core/error/error_messages.dart';

void main() {
  test(
    'missing payroll assets are not described as an XLM reserve problem',
    () {
      final message = friendlyError(
        const StellarRejectedException(
          transactionCode: 'tx_failed',
          operationCodes: ['op_success', 'op_underfunded'],
        ),
      );
      expect(message, contains('selected payroll asset'));
      expect(message, contains('trustline; it does not add funds'));
      expect(message, isNot(contains('XLM')));
      expect(message, isNot(contains('reserve')));
    },
  );

  for (final error in const [
    StellarRejectedException(transactionCode: 'tx_insufficient_balance'),
    StellarRejectedException(
      transactionCode: 'tx_failed',
      operationCodes: ['op_low_reserve'],
    ),
  ]) {
    test('XLM funding errors explain fees and reserves: ${error.allCodes}', () {
      expect(
        friendlyError(error),
        'Not enough available Testnet XLM for fees and reserves. Add test '
        'XLM or reduce the number of payouts.',
      );
    });
  }
}

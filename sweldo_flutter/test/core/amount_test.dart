import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/core/utils/amount.dart';

void main() {
  group('Amount', () {
    test('parses and prints stroop-exact amounts', () {
      expect(Amount.units('1'), BigInt.from(10000000));
      expect(Amount.units('0.0000001'), BigInt.one);
      expect(Amount.string(Amount.units('12.3400000')), '12.34');
      expect(Amount.string(BigInt.from(15000000)), '1.5');
    });

    test('rejects malformed or oversized amounts', () {
      expect(() => Amount.units('1.12345678'), throwsFormatException);
      expect(() => Amount.units('-1'), throwsFormatException);
      expect(() => Amount.units('922337203685.4775808'), throwsFormatException);
    });

    test('tryUnits accepts what people type', () {
      expect(Amount.tryUnits(' 1,200 '), Amount.units('1200'));
      expect(Amount.tryUnits('.5'), Amount.units('0.5'));
      expect(Amount.tryUnits(''), isNull);
      expect(Amount.tryUnits('abc'), isNull);
    });

    test('applies a 1% slippage limit like the web app', () {
      expect(Amount.minimumReceived('17040'), '16869.6');
      expect(Amount.minimumReceived('100'), '99');
      expect(() => Amount.minimumReceived('0.0000001'), throwsStateError);
    });

    test('splits a total across payouts without exceeding it', () {
      expect(Amount.perPayout('1200', 4), '300');
      expect(Amount.perPayout('1200', 7), '171.4285714');
      final split = Amount.units(Amount.perPayout('1200', 7)) * BigInt.from(7);
      expect(split <= Amount.units('1200'), isTrue);
      expect(Amount.perPayout('', 4), '0');
      expect(Amount.perPayout('100', 0), '0');
    });
  });
}

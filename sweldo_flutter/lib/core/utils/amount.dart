import 'package:intl/intl.dart';

/// Exact Stellar amount arithmetic in stroops (7 decimal places).
///
/// Ported from `claim-convert.ts` so quotes, slippage and payout splits match
/// the web app to the last stroop.
abstract final class Amount {
  static final BigInt scale = BigInt.from(10000000);
  static final BigInt _maxInt64 = BigInt.parse('9223372036854775807');
  static final RegExp _strict = RegExp(r'^\d+(\.\d{1,7})?$');

  static const slippageBps = 100;

  /// Parses a canonical Stellar amount string into stroops.
  static BigInt units(String value) {
    if (!_strict.hasMatch(value)) {
      throw const FormatException('Invalid Stellar amount.');
    }
    final parts = value.split('.');
    final fraction = parts.length > 1 ? parts[1] : '';
    final units =
        BigInt.parse(parts[0]) * scale +
        BigInt.parse(fraction.padRight(7, '0'));
    if (units > _maxInt64) {
      throw const FormatException('Stellar amount is too large.');
    }
    return units;
  }

  /// Like [units] but returns null instead of throwing; accepts surrounding
  /// whitespace and thousands separators typed into a form.
  static BigInt? tryUnits(String value) {
    final cleaned = value.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.startsWith('.') ? '0$cleaned' : cleaned;
    try {
      return units(normalized);
    } on FormatException {
      return null;
    }
  }

  /// Formats stroops back into a canonical amount string without trailing
  /// zeros.
  static String string(BigInt units) {
    final whole = units ~/ scale;
    final fraction = (units % scale)
        .toString()
        .padLeft(7, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? '$whole' : '$whole.$fraction';
  }

  /// The minimum a conversion may deliver with a 1% slippage limit.
  static String minimumReceived(String expected) {
    final minimum =
        units(expected) *
        BigInt.from(10000 - slippageBps) ~/
        BigInt.from(10000);
    if (minimum <= BigInt.zero) {
      throw StateError(
        'The payout is too small to convert with slippage protection.',
      );
    }
    return string(minimum);
  }

  /// Splits a total evenly across [payouts], rounding down to the stroop so
  /// the locked sum never exceeds what the employer entered.
  static String perPayout(String total, int payouts) {
    final totalUnits = tryUnits(total);
    if (totalUnits == null || payouts < 1) return '0';
    return string(totalUnits ~/ BigInt.from(payouts));
  }

  static final NumberFormat _display = NumberFormat('#,##0.#######', 'en_US');

  /// Human display with grouping and up to 7 decimals.
  static String format(Object? value) {
    final number = switch (value) {
      final num n => n,
      final String s => num.tryParse(s.replaceAll(',', '')) ?? 0,
      _ => 0,
    };
    return _display.format(number);
  }

  /// Display formatting for exact stroop totals.
  static String formatUnits(BigInt units) => format(string(units));
}

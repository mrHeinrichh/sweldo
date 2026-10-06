/// How often a payout unlocks.
enum PayCadence {
  minute(60, 'Every minute', 'minute', hint: 'For live demos'),
  day(86400, 'Daily', 'day'),
  week(604800, 'Weekly', 'week'),
  month(2592000, 'Monthly', 'month', hint: 'Every 30 days');

  const PayCadence(this.seconds, this.label, this.unit, {this.hint});

  final int seconds;
  final String label;

  /// Singular unit used in "first payday in 2 days".
  final String unit;
  final String? hint;

  Duration get interval => Duration(seconds: seconds);
}

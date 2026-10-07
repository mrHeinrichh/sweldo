import 'dart:math';

import '../../../core/stellar/stellar_network.dart';
import 'pay_cadence.dart';

/// Rolls realistic sample values for the payroll form: names, pay, cadence,
/// payout count and first payday. Amounts are whole multiples of the payout
/// so every split is clean, and totals stay within what a Friendbot-funded
/// Testnet wallet can lock.
class PayrollSampler {
  PayrollSampler([Random? random]) : _random = random ?? Random();

  final Random _random;

  static const names = [
    'Ana Santos',
    'Marco Reyes',
    'Bea Dela Cruz',
    'Paolo Garcia',
    'Liza Mendoza',
    'Jun Bautista',
    'Carla Villanueva',
    'Rico Ramos',
    'Joy Aquino',
    'Miguel Torres',
    'Grace Flores',
    'Nico Castillo',
  ];

  /// [count] distinct names.
  List<String> namesFor(int count) {
    final pool = [...names]..shuffle(_random);
    return [for (var i = 0; i < count; i++) pool[i % pool.length]];
  }

  PayCadence cadence() =>
      PayCadence.values[_random.nextInt(PayCadence.values.length)];

  /// 2–8 payouts, never more than one transaction can hold for [employees].
  int payouts(int employees) {
    final cap = min(
      StellarNetwork.maxPayoutsPerEmployee,
      StellarNetwork.maxOperationsPerTransaction ~/ max(1, employees),
    );
    return min(cap, 2 + _random.nextInt(7));
  }

  /// First payday 0–3 intervals away.
  int firstPaydayIn() => _random.nextInt(4);

  /// A total that splits evenly: 20–250 per payout, in steps of 10.
  String totalFor(int payouts) {
    final perPayout = 20 + _random.nextInt(24) * 10;
    return '${perPayout * payouts}';
  }
}

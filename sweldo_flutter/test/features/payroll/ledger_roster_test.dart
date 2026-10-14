import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/core/error/app_exception.dart';
import 'package:sweldo/features/payroll/data/payroll_ledger.dart';
import 'package:sweldo/features/payroll/data/roster_import.dart';
import 'package:sweldo/features/payroll/domain/pay_cadence.dart';
import 'package:sweldo/features/payroll/domain/payroll_schedule.dart';

// Public fixture identities and expected outcomes match week3-horizon.mjs.
const employer = 'GA63TYUUORN4FLT2QWWUVL37ERXZ5OTCEQWCIRO3PR3PYB6JUUYKGLH4';
const worker = 'GB5OYIHNYJKUP6VFZHYCPLFHBF63SWIDZAPBXET4NKEFLEPWPMKIETPL';
const other = 'GCSRX5WXQJ6PGNNSQ4VIVQAIRFL2MK4SFINU6VO55QASSRWW46HMQYNR';
final now = DateTime.utc(2026, 10, 7);
final ids = List.generate(
  4,
  (i) => '00000000${(i + 1).toRadixString(16).padLeft(64, '0')}',
);

Map<String, dynamic> create(int i, String unlock, [String employee = worker]) =>
    {
      'id': '${i + 1}',
      'type': 'create_claimable_balance',
      'source_account': employer,
      'transaction_hash': i == 3 ? 'd' * 64 : 'a' * 64,
      'transaction_successful': true,
      'created_at': '2026-10-06T00:00:00Z',
      'asset': 'native',
      'amount': '2.0000000',
      'claimants': [
        {
          'destination': employee,
          'predicate': {
            'not': {'abs_before': unlock},
          },
        },
        {
          'destination': employer,
          'predicate': {'abs_before': unlock},
        },
      ],
    };
List<Map<String, dynamic>> creates() => [
  create(0, '2000-01-01T00:00:00Z'),
  create(1, '2000-01-01T00:01:00Z'),
  create(2, '2099-01-01T00:00:00Z'),
  create(3, '2099-01-01T00:00:00Z', other),
];
Map<String, dynamic> page(List<Map<String, dynamic>> records, [String? next]) =>
    {
      '_embedded': {'records': records},
      '_links': {
        if (next != null) 'next': {'href': next},
      },
    };
Future<Map<String, dynamic>?> fixture(
  String path, {
  bool allowMissing = false,
}) async {
  final uri = Uri.parse(path);
  if (uri.path == '/accounts/$employer/operations') return page(creates());
  final effect = RegExp(r'^/operations/(\d+)/effects$').firstMatch(uri.path);
  if (effect != null) {
    return page([
      {
        'type': 'claimable_balance_created',
        'balance_id': ids[int.parse(effect[1]!) - 1],
      },
    ]);
  }
  final history = RegExp(
    r'^/claimable_balances/([a-f0-9]+)/operations$',
  ).firstMatch(uri.path);
  if (history != null) {
    final i = ids.indexOf(history[1]!);
    return page([
      if (i == 0 || i == 3)
        {
          'type': 'claim_claimable_balance',
          'balance_id': ids[i],
          'claimant': i == 0 ? worker : employer,
          'transaction_successful': true,
          'transaction_hash': (i == 0 ? 'b' : 'c') * 64,
          'created_at': '2026-10-06T12:00:00Z',
        },
      creates()[i],
    ]);
  }
  final balance = RegExp(
    r'^/claimable_balances/([a-f0-9]+)$',
  ).firstMatch(uri.path);
  if (balance != null) {
    final i = ids.indexOf(balance[1]!);
    return i == 1 || i == 2 ? {...creates()[i], 'id': ids[i]} : null;
  }
  throw StateError('Unexpected fixture read: $path');
}

void main() {
  test(
    'fresh reconstruction recovers status and IDs without device storage',
    () async {
      final result = await PayrollLedger.withReader(
        fixture,
      ).reconstruct(employer, now: now);
      final schedule = result.schedules.firstWhere((s) => s.employee == worker);
      expect(result.schedules, hasLength(2));
      expect(schedule.total, '6');
      expect(schedule.balanceIds, ids.take(3).toList());
      expect(schedule.payouts.map((p) => p.status), [
        PayrollPayoutStatus.claimed,
        PayrollPayoutStatus.claimable,
        PayrollPayoutStatus.scheduled,
      ]);
      expect(schedule.payouts.first.settlementHash, 'b' * 64);
      expect(
        result.schedules.firstWhere((s) => s.employee == other).cancelHash,
        'c' * 64,
      );
      expect(result.warnings, isEmpty);
      expect(cancellableBalanceIds(schedule, ids.toSet(), now), [ids[2]]);
      expect(
        cancellableBalanceIds(
          schedule,
          ids.toSet(),
          schedule.payouts.last.unlockAt,
        ),
        isEmpty,
      );
    },
  );
  test('missing balances are unverified, not assumed claimed', () async {
    final result = await PayrollLedger.withReader(
      (path, {allowMissing = false}) async =>
          path == '/claimable_balances/${ids[2]}' ? null : fixture(path),
    ).reconstruct(employer, now: now);
    final schedule = result.schedules.firstWhere((s) => s.employee == worker);
    expect(schedule.payouts.last.status, PayrollPayoutStatus.unverified);
    expect(cancellableBalanceIds(schedule, ids.toSet(), now), isEmpty);
    expect(result.warnings, hasLength(1));
  });
  test(
    'history pagination includes older payroll and rejects cycles',
    () async {
      final ledger = PayrollLedger.withReader((
        path, {
        allowMissing = false,
      }) async {
        if (path.startsWith('/accounts/')) {
          return page(List.generate(100, (i) => {'type': 'payment'}), '/older');
        }
        return path == '/older' ? page(creates()) : fixture(path);
      });
      expect(
        (await ledger.reconstruct(employer, now: now)).schedules,
        hasLength(2),
      );
      await expectLater(
        ledgerRecords(
          (path, {allowMissing = false}) async => page([
            {'id': '1'},
          ], '/same'),
          '/same',
        ),
        throwsA(isA<UserFacingException>()),
      );
    },
  );
  test(
    'missing effects, malformed address and unavailable history fail closed',
    () async {
      await expectLater(
        PayrollLedger.withReader(
          (path, {allowMissing = false}) async =>
              path.contains('/effects') ? page([]) : fixture(path),
        ).reconstruct(employer),
        throwsA(isA<UserFacingException>()),
      );
      await expectLater(
        PayrollLedger.withReader(
          (path, {allowMissing = false}) async => throw StateError('offline'),
        ).reconstruct(employer),
        throwsStateError,
      );
      await expectLater(
        PayrollLedger.withReader(
          (path, {allowMissing = false}) async => fail('No request expected'),
        ).reconstruct('invalid'),
        throwsA(isA<UserFacingException>()),
      );
    },
  );
  test('failed funding and unsupported predicates are excluded', () {
    expect(
      payrollTerms({
        ...creates().first,
        'transaction_successful': false,
      }, employer),
      isNull,
    );
    expect(payrollTerms(creates().first, worker), isNull);
    final modified = creates().first;
    modified['claimants'][0]['predicate'] = <String, dynamic>{
      ...modified['claimants'][0]['predicate'] as Map,
      'or': [],
    };
    expect(payrollTerms(modified, employer), isNull);
  });
  test('unfunded employers have no reconstructed schedules', () async {
    expect(
      (await PayrollLedger.withReader(
        (path, {allowMissing = false}) async => null,
      ).reconstruct(employer)).schedules,
      isEmpty,
    );
  });
  final csv =
      'wallet,name,amount,cadence\n$worker,"Ana, Santos",6,minute\n$other,Marco Reyes,9,minute';
  test('quoted CSV, BOM and tab-separated paste match web imports', () {
    expect(parseRoster('\uFEFF$csv', 3).rows.first.name, 'Ana, Santos');
    final tab = csv
        .replaceFirst('"Ana, Santos"', 'Ana Santos')
        .replaceAll(',', '\t');
    expect(parseRoster(tab, 3).rows.last, parseRoster(csv, 3).rows.last);
    expect(parseRoster(csv, 3).cadence, PayCadence.minute);
  });
  test(
    'CSV rejects duplicates, invalid wallets, mixed cadence and columns',
    () {
      for (final input in [
        csv.replaceFirst(worker, 'bad'),
        csv.replaceFirst(other, worker),
        csv.replaceFirst('9,minute', '9,week'),
        csv.replaceFirst('9,minute', '9'),
        csv.replaceFirst('9,minute', '9,hour'),
      ]) {
        expect(() => parseRoster(input, 3), throwsFormatException);
      }
    },
  );
  test(
    'CSV checks exact divisibility, size, precision and operation capacity',
    () {
      for (final input in [
        csv.replaceFirst('6,minute', '1,minute'),
        csv.replaceFirst('6,minute', '0,minute'),
        csv.replaceFirst('6,minute', '0.00000001,minute'),
        'x' * 100001,
        'wallet,name,amount,cadence',
      ]) {
        expect(() => parseRoster(input, 3), throwsFormatException);
      }
      expect(
        () => parseRoster('$csv\n$employer,Third,6,minute', 50),
        throwsFormatException,
      );
      expect(() => parseRoster(csv, 51), throwsFormatException);
    },
  );
}

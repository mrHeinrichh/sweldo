import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/features/payroll/data/payroll_repository.dart';
import 'package:sweldo/features/payroll/domain/payroll_schedule.dart';

void main() {
  final employer = KeyPair.random().accountId;
  final ana = KeyPair.random().accountId;
  final ben = KeyPair.random().accountId;
  final first = DateTime.utc(2026, 11, 3, 9);

  PayrollSchedule schedule({bool revocable = true}) => PayrollSchedule(
        id: 's1',
        employee: ana,
        name: 'Ana Santos',
        total: '1200',
        tranches: 4,
        asset: 'USDC',
        createdAt: DateTime.utc(2026, 10, 3),
        hash: 'tx',
        employer: employer,
        balanceIds: const ['b0', 'b1', 'b2', 'b3'],
        firstUnlock: first,
        intervalSeconds: 60,
        revocable: revocable,
      );

  group('cancellableBalanceIds', () {
    test('only future payouts still on the ledger', () {
      final now = first.add(const Duration(seconds: 61));
      expect(
        cancellableBalanceIds(schedule(), {'b0', 'b1', 'b2', 'b3'}, now),
        ['b2', 'b3'],
      );
      expect(cancellableBalanceIds(schedule(), {'b3'}, now), ['b3']);
    });

    test('payday itself is no longer cancellable', () {
      final atSecondPayday = first.add(const Duration(seconds: 60));
      expect(
        cancellableBalanceIds(schedule(), {'b1', 'b2'}, atSecondPayday),
        ['b2'],
      );
    });

    test('schedules created without cancellation stay irrevocable', () {
      expect(
        cancellableBalanceIds(
            schedule(revocable: false), {'b0', 'b1'}, DateTime.utc(2020)),
        isEmpty,
      );
    });
  });

  test('schedule JSON stays compatible with the React app', () {
    final original = schedule();
    final json = original.toJson();
    expect(json['tranches'], 4);
    expect(json['firstUnlock'], '2026-11-03T09:00:00.000Z');
    expect(PayrollSchedule.fromJson(json), original);
  });

  group('buildBatchTransaction', () {
    final transaction = buildBatchTransaction(
      account: Account(employer, BigInt.from(100)),
      employer: employer,
      recipients: [
        ScheduleRecipient(employee: ana, amountPerPayout: '300'),
        ScheduleRecipient(employee: ben, amountPerPayout: '150'),
      ],
      payouts: 3,
      firstUnlock: first,
      intervalSeconds: 86400,
      asset: Asset.NATIVE,
      now: DateTime.utc(2026, 10, 3),
    );

    test('one claimable balance per payout per employee', () {
      expect(transaction.operations, hasLength(6));
      final ops =
          transaction.operations.cast<CreateClaimableBalanceOperation>();
      expect(ops.take(3).map((o) => o.amount), everyElement('300'));
      expect(ops.skip(3).map((o) => o.amount), everyElement('150'));
    });

    test('employee and employer predicates are mutually exclusive', () {
      final op =
          transaction.operations[1] as CreateClaimableBalanceOperation;
      final unlock = first.millisecondsSinceEpoch ~/ 1000 + 86400;
      final employee = op.claimants.firstWhere((c) => c.destination == ana);
      final boss = op.claimants.firstWhere((c) => c.destination == employer);
      expect(employee.predicate.discriminant,
          XdrClaimPredicateType.CLAIM_PREDICATE_NOT);
      expect(employee.predicate.notPredicate!.absBefore!.int64.toInt(), unlock);
      expect(boss.predicate.discriminant,
          XdrClaimPredicateType.CLAIM_PREDICATE_BEFORE_ABSOLUTE_TIME);
      expect(boss.predicate.absBefore!.int64.toInt(), unlock);
    });

    test('expires three minutes after it is built', () {
      final bounds = transaction.preconditions!.timeBounds!;
      expect(bounds.maxTime,
          DateTime.utc(2026, 10, 3).millisecondsSinceEpoch ~/ 1000 + 180);
    });
  });
}

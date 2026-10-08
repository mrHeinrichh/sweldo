import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/widgets/notice.dart';
import 'package:sweldo/features/payroll/bloc/payroll_form/payroll_form_bloc.dart';
import 'package:sweldo/features/payroll/data/payroll_repository.dart';
import 'package:sweldo/features/payroll/data/registry_repository.dart';
import 'package:sweldo/features/payroll/data/schedule_store.dart';
import 'package:sweldo/features/payroll/domain/pay_cadence.dart';
import 'package:sweldo/features/payroll/domain/payroll_sample.dart';
import 'package:sweldo/features/payroll/domain/payroll_schedule.dart';
import 'package:sweldo/features/wallet/domain/wallet_session.dart';

class _MockPayroll extends Mock implements PayrollRepository {}

class _MockRegistry extends Mock implements RegistryRepository {}

class _MockStore extends Mock implements ScheduleStore {}

void main() {
  final employer = KeyPair.random().accountId;
  final ana = KeyPair.random().accountId;
  final now = DateTime.utc(2026, 10, 3, 9);
  final session = WalletSession(
    address: employer,
    network: 'TESTNET',
    kind: WalletKind.freighterExtension,
  );

  late _MockPayroll payroll;
  late _MockRegistry registry;
  late _MockStore store;
  var ids = 0;

  setUpAll(() {
    registerFallbackValue(Asset.NATIVE);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<PayrollSchedule>[]);
  });

  setUp(() {
    ids = 0;
    payroll = _MockPayroll();
    registry = _MockRegistry();
    store = _MockStore();
    when(() => registry.isConfigured).thenReturn(false);
    when(() => store.prepend(any(), balanceIds: any(named: 'balanceIds')))
        .thenAnswer((_) async {});
  });

  PayrollFormBloc build() => PayrollFormBloc(
        payroll: payroll,
        registry: registry,
        store: store,
        asset: Asset.NATIVE,
        assetLabel: 'XLM',
        clock: () => now,
        newId: () => 'id${ids++}',
        random: Random(7),
      );

  test('starts from a random, internally consistent sample', () {
    final state = build().state;
    expect(state.recipients, hasLength(1));
    expect(PayrollSampler.names, contains(state.recipients.single.name));
    expect(state.payouts, inInclusiveRange(2, 8));
    expect(state.firstPaydayIn, inInclusiveRange(0, 3));
    final perPayout = int.parse(state.amountPerPayout(state.recipients.single.total));
    expect(perPayout, inInclusiveRange(20, 250));
    expect(perPayout % 10, 0);
    expect(state.step, 0);
  });

  blocTest<PayrollFormBloc, PayrollFormState>(
    'a new draft rolls names, pay and schedule, keeps wallet addresses, '
    'and returns to the first step',
    build: build,
    act: (bloc) => bloc
      ..add(const RecipientAdded())
      ..add(RecipientChanged('id0', employee: ana))
      ..add(const PayrollStepChanged(2))
      ..add(const PayrollDraftStarted()),
    verify: (bloc) {
      final state = bloc.state;
      expect(state.step, 0);
      expect(state.lastProof, isNull);
      expect(state.recipients.first.employee, ana);
      expect(state.recipients.map((r) => r.name).toSet(), hasLength(2));
      for (final r in state.recipients) {
        expect(int.parse(r.total) % state.payouts, 0);
      }
      expect(state.balanceCount <= 100, isTrue);
    },
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'the wizard stays within its three steps',
    build: build,
    act: (bloc) => bloc
      ..add(const PayrollStepChanged(5))
      ..add(const PayrollStepChanged(-1)),
    expect: () => [
      isA<PayrollFormState>().having((s) => s.step, 'step', 2),
      isA<PayrollFormState>().having((s) => s.step, 'step', 0),
    ],
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'won’t leave the team step until every wallet address is in',
    build: build,
    act: (bloc) => bloc.add(const PayrollStepRequested(1)),
    expect: () => [
      isA<PayrollFormState>()
          .having((s) => s.step, 'step', 0)
          .having((s) => s.teamChecks, 'teamChecks', 1),
    ],
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'moves on once every employee has a wallet address',
    build: build,
    act: (bloc) => bloc
      ..add(RecipientChanged('id0', employee: ana))
      ..add(const PayrollStepRequested(1)),
    skip: 1,
    expect: () => [
      isA<PayrollFormState>().having((s) => s.step, 'step', 1),
    ],
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'won’t accept the connected wallet as an employee',
    build: build,
    act: (bloc) => bloc
      ..add(RecipientChanged('id0', employee: employer))
      ..add(PayrollStepRequested(1, employer: employer)),
    skip: 1,
    expect: () => [
      isA<PayrollFormState>()
          .having((s) => s.step, 'step', 0)
          .having((s) => s.teamChecks, 'teamChecks', 1),
    ],
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'refuses to lock pay into the employer’s own wallet',
    build: build,
    act: (bloc) => bloc
      ..add(RecipientChanged('id0', employee: employer))
      ..add(PayrollSubmitted(session)),
    skip: 1,
    expect: () => [
      isA<PayrollFormState>().having(
        (s) => s.notice?.text,
        'notice',
        contains('your own wallet'),
      ),
    ],
  );

  test('lists what blocks locking', () {
    final state = build().state;
    expect(state.missingAddresses, 1);
    expect(state.invalidAmounts, 0);
    expect(state.blocked, isTrue);
  });

  test('the sampler never exceeds one transaction', () {
    final sampler = PayrollSampler(Random(1));
    for (var employees = 1; employees <= 40; employees++) {
      expect(sampler.payouts(employees) * employees <= 100, isTrue);
    }
  });

  blocTest<PayrollFormBloc, PayrollFormState>(
    'refuses an invalid wallet address without signing anything',
    build: build,
    act: (bloc) => bloc
      ..add(const RecipientChanged('id0', employee: 'GNOTAKEY'))
      ..add(PayrollSubmitted(session)),
    skip: 1,
    expect: () => [
      isA<PayrollFormState>().having(
        (s) => s.notice?.tone,
        'notice',
        NoticeTone.error,
      ),
    ],
    verify: (_) => verifyNever(() => payroll.createBatchSchedule(
          employer: any(named: 'employer'),
          recipients: any(named: 'recipients'),
          payouts: any(named: 'payouts'),
          firstUnlock: any(named: 'firstUnlock'),
          intervalSeconds: any(named: 'intervalSeconds'),
          asset: any(named: 'asset'),
        )),
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'asks for Testnet before signing',
    build: build,
    act: (bloc) => bloc.add(PayrollSubmitted(WalletSession(
      address: employer,
      network: 'PUBLIC',
      kind: WalletKind.freighterExtension,
    ))),
    expect: () => [
      isA<PayrollFormState>().having((s) => s.notice?.text, 'notice',
          contains('Testnet')),
    ],
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'locks payroll, saves schedules with their balance ids, and shows proof',
    setUp: () {
      when(() => payroll.createBatchSchedule(
            employer: any(named: 'employer'),
            recipients: any(named: 'recipients'),
            payouts: any(named: 'payouts'),
            firstUnlock: any(named: 'firstUnlock'),
            intervalSeconds: any(named: 'intervalSeconds'),
            asset: any(named: 'asset'),
          )).thenAnswer((_) async => const BatchScheduleResult(
            hash: 'abc123',
            balanceIds: ['b0', 'b1', 'b2', 'b3'],
          ));
    },
    build: build,
    act: (bloc) => bloc
      ..add(RecipientChanged('id0', name: 'Ana Santos', employee: ana, total: '1200'))
      ..add(const PayoutCountChanged(4))
      ..add(const CadenceChanged(PayCadence.minute))
      ..add(const FirstPaydayChanged(1))
      ..add(PayrollSubmitted(session)),
    // Earlier field edits may or may not emit, depending on the rolled
    // sample, so match the submission states in order.
    expect: () => containsAllInOrder([
      isA<PayrollFormState>().having((s) => s.submitting, 'submitting', true),
      isA<PayrollFormState>()
          .having((s) => s.submitting, 'submitting', false)
          .having((s) => s.lastProof?.hash, 'proof hash', 'abc123')
          .having((s) => s.lastProof?.balanceCount, 'balances', 4)
          .having((s) => s.notice?.tone, 'notice', NoticeTone.success),
    ]),
    verify: (_) {
      final captured = verify(() => store.prepend(captureAny(),
          balanceIds: captureAny(named: 'balanceIds'))).captured;
      final schedules = captured[0] as List<PayrollSchedule>;
      expect(schedules.single.name, 'Ana Santos');
      expect(schedules.single.balanceIds, ['b0', 'b1', 'b2', 'b3']);
      expect(schedules.single.firstUnlock, now.add(const Duration(minutes: 1)));
      expect(schedules.single.revocable, isTrue);
      verify(() => payroll.createBatchSchedule(
            employer: employer,
            recipients: any(named: 'recipients'),
            payouts: 4,
            firstUnlock: now.add(const Duration(minutes: 1)),
            intervalSeconds: 60,
            asset: any(named: 'asset'),
          )).called(1);
    },
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'keeps at least one employee row',
    build: build,
    act: (bloc) => bloc
      ..add(const RecipientAdded())
      ..add(const RecipientRemoved('id0'))
      ..add(const RecipientRemoved('id1')),
    verify: (bloc) => expect(bloc.state.recipients.single.id, 'id1'),
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'a preset sets cadence, count and start in one change',
    build: build,
    act: (bloc) => bloc.add(const ScheduleChanged(
      cadence: PayCadence.week,
      payouts: 13,
      firstPaydayIn: 1,
    )),
    verify: (bloc) {
      final state = bloc.state;
      expect(state.cadence, PayCadence.week);
      expect(state.payouts, 13);
      final paydays = state.paydays(now);
      expect(paydays.first, now.add(const Duration(days: 7)));
      expect(paydays.last, now.add(const Duration(days: 7 * 13)));
    },
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'a picked first payday wins until a relative start is chosen again',
    build: build,
    act: (bloc) => bloc
      ..add(ScheduleChanged(firstPaydayAt: () => DateTime.utc(2026, 11, 3, 9)))
      ..add(const ScheduleChanged(cadence: PayCadence.day)),
    verify: (bloc) =>
        expect(bloc.state.firstPayday(now), DateTime.utc(2026, 11, 3, 9)),
  );

  blocTest<PayrollFormBloc, PayrollFormState>(
    'choosing a relative start clears a picked date',
    build: build,
    act: (bloc) => bloc
      ..add(ScheduleChanged(firstPaydayAt: () => DateTime.utc(2026, 11, 3, 9)))
      ..add(const ScheduleChanged(firstPaydayIn: 2)),
    verify: (bloc) {
      expect(bloc.state.firstPaydayAt, isNull);
      expect(bloc.state.firstPayday(now), now.add(bloc.state.cadence.interval * 2));
    },
  );

  test('capacity keeps the whole team in one transaction', () {
    final bloc = build();
    for (var i = 0; i < 4; i++) {
      bloc.add(const RecipientAdded());
    }
    return Future<void>.delayed(Duration.zero, () {
      expect(bloc.state.recipients, hasLength(5));
      expect(bloc.state.capacity, 20);
      bloc.close();
    });
  });

  test('a past picked date means the first payout unlocks right away', () {
    final state = build().state.copyWith(
      firstPaydayAt: () => now.subtract(const Duration(days: 1)),
    );
    expect(state.firstPayday(now), now);
  });
}

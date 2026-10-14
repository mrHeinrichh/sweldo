import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/config/app_config.dart';
import 'package:sweldo/core/stellar/payroll_asset.dart';
import 'package:sweldo/core/theme/app_theme.dart';
import 'package:sweldo/features/account/bloc/account_setup_cubit.dart';
import 'package:sweldo/features/account/data/account_repository.dart';
import 'package:sweldo/features/payouts/bloc/payouts_bloc.dart';
import 'package:sweldo/features/payouts/domain/payout.dart';
import 'package:sweldo/features/payroll/bloc/payroll_form/payroll_form_bloc.dart';
import 'package:sweldo/features/payroll/data/payroll_repository.dart';
import 'package:sweldo/features/payroll/data/registry_repository.dart';
import 'package:sweldo/features/payroll/data/schedule_store.dart';
import 'package:sweldo/features/payroll/domain/payroll_schedule.dart';
import 'package:sweldo/features/payroll/view/widgets/payroll_asset_selector.dart';
import 'package:sweldo/features/wallet/data/wallet_repository.dart';
import 'package:sweldo/features/wallet/domain/wallet_session.dart';

class _Payroll extends Mock implements PayrollRepository {}

class _Registry extends Mock implements RegistryRepository {}

class _Store extends Mock implements ScheduleStore {}

class _Account extends Mock implements AccountRepository {}

class _Wallet extends Mock implements WalletRepository {}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  final issuer = KeyPair.random().accountId;
  final employer = KeyPair.random().accountId;
  final worker = KeyPair.random().accountId;
  final options = payrollAssetOptions('USDC', issuer);
  final usdc = options.last;
  final session = WalletSession(
    address: employer,
    network: 'TESTNET',
    kind: WalletKind.xbull,
  );

  setUpAll(() {
    registerFallbackValue(Asset.NATIVE);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(<PayrollSchedule>[]);
  });

  test('configuration enables Test-USDC without changing the XLM default', () {
    final config = AppConfig(
      assetCode: 'USDC',
      assetIssuer: issuer,
      phptIssuer: worker,
    );
    expect(config.payrollAsset, isA<AssetTypeNative>());
    expect(config.assetLabel, 'XLM');
    expect(config.payrollAssets.map((option) => option.label), [
      'XLM (Testnet)',
      'Test-USDC',
    ]);
    expect(config.conversionPair, isNotNull);
    expect(payrollAssetOptions('PHPT', issuer), hasLength(1));
    expect(payrollAssetOptions('USDC', 'invalid'), hasLength(1));
  });

  for (final option in options) {
    test(
      '${option.label} reaches payroll creation and historical proof unchanged',
      () async {
        final payroll = _Payroll();
        final registry = _Registry();
        final store = _Store();
        final pending = Completer<BatchScheduleResult>();
        when(() => registry.isConfigured).thenReturn(false);
        when(
          () => store.prepend(any(), balanceIds: any(named: 'balanceIds')),
        ).thenAnswer((_) async {});
        when(
          () => payroll.createBatchSchedule(
            employer: any(named: 'employer'),
            recipients: any(named: 'recipients'),
            payouts: any(named: 'payouts'),
            firstUnlock: any(named: 'firstUnlock'),
            intervalSeconds: any(named: 'intervalSeconds'),
            asset: any(named: 'asset'),
          ),
        ).thenAnswer((_) => pending.future);
        final bloc = PayrollFormBloc(
          payroll: payroll,
          registry: registry,
          store: store,
          asset: Asset.NATIVE,
          assetLabel: 'XLM',
          assetOptions: options,
          newId: () => 'worker',
        );
        addTearDown(bloc.close);
        bloc.add(PayrollAssetSelected(option.id));
        bloc.add(RecipientChanged('worker', employee: worker, total: '2'));
        bloc.add(const PayoutCountChanged(1));
        await flush();
        bloc.add(PayrollSubmitted(session));
        await flush();
        expect(bloc.state.submitting, isTrue);
        bloc.add(
          PayrollAssetSelected(option.id == 'native' ? usdc.id : 'native'),
        );
        await flush();
        expect(
          bloc.state.assetId,
          option.id,
          reason: 'Cannot change an asset during wallet approval',
        );
        pending.complete(
          const BatchScheduleResult(
            hash: 'test-hash',
            balanceIds: ['balance-id'],
          ),
        );
        await flush();
        final proof = bloc.state.lastProof!;
        expect(proof.asset, option.code);
        final used =
            verify(
                  () => payroll.createBatchSchedule(
                    employer: employer,
                    recipients: any(named: 'recipients'),
                    payouts: 1,
                    firstUnlock: any(named: 'firstUnlock'),
                    intervalSeconds: any(named: 'intervalSeconds'),
                    asset: captureAny(named: 'asset'),
                  ),
                ).captured.single
                as Asset;
        expect(Asset.canonicalForm(used), option.id);
        final saved =
            verify(
                  () => store.prepend(captureAny(), balanceIds: ['balance-id']),
                ).captured.single
                as List<PayrollSchedule>;
        expect(saved.single.asset, option.code);
        bloc.add(
          PayrollAssetSelected(option.id == 'native' ? usdc.id : 'native'),
        );
        await flush();
        expect(bloc.state.lastProof, isNull);
        expect(bloc.state.step, 0);
        expect(saved.single.asset, option.code);
        expect(proof.asset, option.code);
      },
    );
  }

  test(
    'unconfigured choices and a busy account cannot change a draft asset',
    () async {
      final bloc = PayrollFormBloc(
        payroll: _Payroll(),
        registry: _Registry(),
        store: _Store(),
        asset: Asset.NATIVE,
        assetLabel: 'XLM',
        assetOptions: options,
        selectAsset: (_) => false,
      );
      addTearDown(bloc.close);
      bloc.add(PayrollAssetSelected(usdc.id));
      bloc.add(const PayrollAssetSelected('PHPT:invalid'));
      await flush();
      expect(bloc.state.assetId, 'native');
      expect(bloc.state.assetLabel, 'XLM');
    },
  );

  test(
    'switching assets discards late balance reads and native mode never enables a trustline',
    () async {
      final account = _Account();
      final wallet = _Wallet();
      final stale = Completer<WalletBalances?>();
      final funding = Completer<void>();
      when(() => wallet.session).thenReturn(session);
      when(() => wallet.sessions).thenAnswer((_) => const Stream.empty());
      when(() => account.isFunded(employer)).thenAnswer((_) async => true);
      when(() => account.testFaucet).thenReturn(null);
      when(
        () => account.hasTrustline(employer, any()),
      ).thenAnswer((_) async => false);
      when(() => account.balances(employer, any())).thenAnswer((invocation) {
        final asset = invocation.positionalArguments[1] as Asset;
        return asset is AssetTypeNative
            ? Future.value(
                const WalletBalances(xlm: '100', asset: '100', reservedXlm: 1),
              )
            : stale.future;
      });
      when(
        () => account.fundWithFriendbot(employer),
      ).thenAnswer((_) => funding.future);
      final cubit = AccountSetupCubit(
        repository: account,
        wallet: wallet,
        payrollAsset: Asset.NATIVE,
      );
      addTearDown(cubit.close);
      await flush();
      expect(cubit.state.balances?.asset, '100');
      expect(cubit.selectAsset(usdc.asset), isTrue);
      await flush();
      expect(cubit.state.balances, isNull);
      expect(cubit.selectAsset(Asset.NATIVE), isTrue);
      await flush();
      stale.complete(
        const WalletBalances(xlm: '100', asset: '0', reservedXlm: 1),
      );
      await flush();
      expect(cubit.state.balances?.asset, '100');
      expect(cubit.state.needsTrustline, isFalse);
      expect(cubit.state.faucetAvailable, isFalse);
      await cubit.enableAsset();
      verifyNever(() => account.addTrustline(any(), any()));
      final work = cubit.fund();
      expect(cubit.selectAsset(usdc.asset), isFalse);
      funding.complete();
      await work;
      expect(cubit.selectAsset(usdc.asset), isTrue);
    },
  );

  test(
    'payout totals separate native, issued and same-code assets from different issuers',
    () {
      final state = PayoutsState(
        payouts: [
          const Payout(
            balanceId: '1',
            amount: '2',
            asset: 'native',
            claimants: [],
          ),
          Payout(
            balanceId: '2',
            amount: '3',
            asset: usdc.id,
            claimants: const [],
          ),
          Payout(
            balanceId: '3',
            amount: '7',
            asset: 'USDC:$worker',
            claimants: const [],
          ),
          const Payout(
            balanceId: '4',
            amount: '10',
            asset: 'native',
            claimants: [],
          ),
        ],
        claimedHashes: const {'4': 'claimed'},
      );
      expect(state.totalsByAsset.map((total) => total.asset), [
        'native',
        usdc.id,
        'USDC:$worker',
      ]);
      expect(state.totalsByAsset.map((total) => total.units), [
        BigInt.from(20000000),
        BigInt.from(30000000),
        BigInt.from(70000000),
      ]);
    },
  );

  for (final size in [const Size(375, 812), const Size(1440, 900)]) {
    testWidgets(
      'inline asset dropdown updates every amount field and fits $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var selected = 'native';
        final amounts = [
          TextEditingController(text: '900'),
          TextEditingController(text: '450'),
        ];
        addTearDown(() {
          for (final amount in amounts) {
            amount.dispose();
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: SwTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      for (var index = 0; index < amounts.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextField(
                            controller: amounts[index],
                            decoration: InputDecoration(
                              suffixIcon: PayrollAssetSelector(
                                options: options,
                                value: selected,
                                semanticLabel:
                                    'Payroll asset for all employees, row ${index + 1}',
                                onChanged: (value) =>
                                    setState(() => selected = value),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('Payroll asset'), findsNothing);
        expect(find.text('XLM'), findsNWidgets(2));
        await tester.tap(find.text('XLM').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('USDC').last);
        await tester.pumpAndSettle();
        expect(selected, usdc.id);
        expect(find.text('USDC'), findsNWidgets(2));
        expect(amounts.map((amount) => amount.text), ['900', '450']);
        for (var index = 0; index < amounts.length; index++) {
          final field = tester.getRect(find.byType(TextField).at(index));
          final selector = tester.getRect(
            find.byType(PayrollAssetSelector).at(index),
          );
          expect(selector.right, closeTo(field.right, 1));
          expect(selector.left, greaterThan(field.left));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

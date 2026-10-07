import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/config/app_config.dart';
import 'package:sweldo/features/account/bloc/account_setup_cubit.dart';
import 'package:sweldo/features/account/data/account_repository.dart';
import 'package:sweldo/features/payroll/bloc/payroll_form/payroll_form_bloc.dart';
import 'package:sweldo/features/payroll/data/payroll_repository.dart';
import 'package:sweldo/features/payroll/data/registry_repository.dart';
import 'package:sweldo/features/payroll/data/schedule_store.dart';
import 'package:sweldo/features/payroll/domain/pay_cadence.dart';
import 'package:sweldo/features/payroll/view/widgets/pay_schedule_builder.dart';
import 'package:sweldo/features/wallet/bloc/wallet_bloc.dart';
import 'package:sweldo/features/wallet/domain/wallet_session.dart';

import '../../helpers/fonts.dart';

class _MockPayroll extends Mock implements PayrollRepository {}

class _MockRegistry extends Mock implements RegistryRepository {}

class _MockStore extends Mock implements ScheduleStore {}

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

class _MockAccountCubit extends MockCubit<AccountSetupState>
    implements AccountSetupCubit {}

void main() {
  setUpAll(loadAppFonts);

  late PayrollFormBloc form;
  late _MockWalletBloc wallet;
  late _MockAccountCubit account;

  // Built inside each test so its streams run in the test's fake-async zone.
  PayrollFormBloc makeForm() {
    final registry = _MockRegistry();
    when(() => registry.isConfigured).thenReturn(false);
    return PayrollFormBloc(
      payroll: _MockPayroll(),
      registry: registry,
      store: _MockStore(),
      asset: Asset.NATIVE,
      assetLabel: 'XLM',
      random: Random(3),
    );
  }

  setUp(() {
    wallet = _MockWalletBloc();
    account = _MockAccountCubit();
  });

  Future<void> pump(
    WidgetTester tester, {
    WalletBalances? balances,
    bool fresh = true,
  }) async {
    if (fresh) {
      form = makeForm();
      addTearDown(form.close);
    }
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final connected = balances != null;
    when(() => wallet.state).thenReturn(WalletState(
      session: connected
          ? const WalletSession(
              address: 'GABC',
              network: 'TESTNET',
              kind: WalletKind.freighterExtension,
            )
          : null,
    ));
    when(() => account.state).thenReturn(AccountSetupState(balances: balances));
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: const AppConfig(),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<PayrollFormBloc>.value(value: form),
            BlocProvider<WalletBloc>.value(value: wallet),
            BlocProvider<AccountSetupCubit>.value(value: account),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(40),
                child: SingleChildScrollView(child: PayScheduleBuilder()),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('dragging the track sets the payout count', (tester) async {
    await pump(tester);
    final track = find.byKey(PayScheduleBuilder.trackKey);
    final box = tester.getRect(track);
    // Tap the 10th of 50 slots.
    await tester.tapAt(Offset(box.left + box.width * 9.5 / 50, box.top + 69));
    await tester.pump();
    expect(form.state.payouts, 10);

    // Drag out to the 30th.
    await tester.dragFrom(
      Offset(box.left + box.width * 9.5 / 50, box.top + 69),
      Offset(box.width * 20 / 50, 0),
    );
    await tester.pump();
    expect(form.state.payouts, inInclusiveRange(29, 31));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a preset fills cadence, count and start', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Weekly for a quarter'));
    await tester.pump();
    expect(form.state.cadence, PayCadence.week);
    expect(form.state.payouts, 13);
    expect(form.state.firstPaydayIn, 1);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('12 weeks after the first'), findsOneWidget);
  });

  testWidgets('the sentence tokens open menus that change the schedule',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('every minute').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();
    expect(form.state.cadence, PayCadence.month);
    expect(find.textContaining('paydays drift'), findsOneWidget);
  });

  testWidgets('it warns when the wallet is short', (tester) async {
    await pump(
      tester,
      balances: const WalletBalances(xlm: '10.0', asset: '10.0', reservedXlm: 1),
    );
    expect(find.textContaining('Short by'), findsOneWidget);
  });

  testWidgets('it confirms when the wallet covers the payroll', (tester) async {
    await pump(
      tester,
      balances: const WalletBalances(xlm: '100000', asset: '100000', reservedXlm: 1),
    );
    expect(find.textContaining('Your wallet covers it'), findsOneWidget);
  });
}

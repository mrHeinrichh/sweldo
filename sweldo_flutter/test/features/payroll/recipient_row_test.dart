import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/features/payroll/bloc/payroll_form/payroll_form_bloc.dart';
import 'package:sweldo/features/payroll/data/payroll_repository.dart';
import 'package:sweldo/features/payroll/data/registry_repository.dart';
import 'package:sweldo/features/payroll/data/schedule_store.dart';
import 'package:sweldo/features/payroll/view/widgets/recipient_row.dart';
import 'package:sweldo/features/wallet/bloc/wallet_bloc.dart';
import 'package:sweldo/features/wallet/domain/wallet_session.dart';

import '../../helpers/fonts.dart';

class _MockPayroll extends Mock implements PayrollRepository {}

class _MockRegistry extends Mock implements RegistryRepository {}

class _MockStore extends Mock implements ScheduleStore {}

class _MockWalletBloc extends MockBloc<WalletEvent, WalletState>
    implements WalletBloc {}

void main() {
  setUpAll(loadAppFonts);

  final employer = KeyPair.random().accountId;
  final worker = KeyPair.random().accountId;

  testWidgets('flags the connected wallet typed in as an employee', (
    tester,
  ) async {
    final registry = _MockRegistry();
    when(() => registry.isConfigured).thenReturn(false);
    final form = PayrollFormBloc(
      payroll: _MockPayroll(),
      registry: registry,
      store: _MockStore(),
      asset: Asset.NATIVE,
      assetLabel: 'XLM',
      random: Random(5),
    );
    addTearDown(form.close);
    final wallet = _MockWalletBloc();
    when(() => wallet.state).thenReturn(
      WalletState(
        session: WalletSession(
          address: employer,
          network: 'TESTNET',
          kind: WalletKind.freighterExtension,
        ),
      ),
    );
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> show() async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<PayrollFormBloc>.value(value: form),
            BlocProvider<WalletBloc>.value(value: wallet),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BlocBuilder<PayrollFormBloc, PayrollFormState>(
                  builder: (context, state) => RecipientRow(
                    recipient: state.recipients.single,
                    index: 0,
                    payouts: state.payouts,
                    assetLabel: 'XLM',
                    removable: false,
                    animateIn: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    await show();
    final id = form.state.recipients.single.id;
    form.add(RecipientChanged(id, employee: employer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(ownWalletMessage), findsOneWidget);

    form.add(RecipientChanged(id, employee: worker));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(ownWalletMessage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

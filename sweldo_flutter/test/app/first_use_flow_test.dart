import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweldo/app/dependencies.dart';
import 'package:sweldo/app/shell/first_use_flow.dart';
import 'package:sweldo/app/shell/app_shell.dart';
import 'package:sweldo/app/shell/wallet_activity_banner.dart';
import 'package:sweldo/app/router/app_router.dart';
import 'package:sweldo/core/stellar/transaction_activity.dart';
import 'package:sweldo/core/config/app_config.dart';
import 'package:sweldo/core/storage/local_store.dart';
import 'package:sweldo/core/theme/app_theme.dart';
import 'package:sweldo/features/wallet/bloc/wallet_bloc.dart';

import '../helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final entry in [
    ('employer', const Size(1280, 900)),
    ('employee', const Size(390, 844)),
  ]) {
    testWidgets(
      'first visit chooses ${entry.$1}, routes there and prompts for a wallet',
      (tester) async {
        tester.view.physicalSize = entry.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final store = await LocalStore.open();
        final deps = AppDependencies.create(const AppConfig(), store);
        final bloc = WalletBloc(repository: deps.wallet, horizon: deps.horizon);
        addTearDown(bloc.close);
        addTearDown(deps.wallet.dispose);
        final router = GoRouter(
          routes: [
            ShellRoute(
              builder: (context, state, child) =>
                  Stack(children: [child, const FirstUseFlow()]),
              routes: [
                for (final path in ['/', '/employer', '/pay'])
                  GoRoute(
                    path: path,
                    builder: (context, state) =>
                        Scaffold(body: Text('Page $path')),
                  ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          RepositoryProvider.value(
            value: deps,
            child: BlocProvider.value(
              value: bloc,
              child: MaterialApp.router(
                theme: SwTheme.light(),
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Are you an employer or an employee?'),
          findsOneWidget,
        );
        await tester.tap(
          find.text(
            entry.$1 == 'employer' ? 'I’m an employer' : 'I’m an employee',
          ),
        );
        await tester.pumpAndSettle();
        expect(store.readString('sweldo-role-v1'), entry.$1);
        expect(
          router.routeInformationProvider.value.uri.path,
          entry.$1 == 'employer' ? '/employer' : '/pay',
        );
        expect(find.text('Wallet not connected'), findsOneWidget);
        expect(find.text('Connect wallet now'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Explore this page first'));
        await tester.pumpAndSettle();
        expect(find.text('Wallet not connected'), findsNothing);
      },
    );
  }

  for (final size in [const Size(375, 667), const Size(844, 390)]) {
    testWidgets('transaction progress fits the app shell at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'sweldo-role-v1': 'employer'});
      final store = await LocalStore.open();
      final deps = AppDependencies.create(const AppConfig(), store);
      final bloc = WalletBloc(repository: deps.wallet, horizon: deps.horizon);
      addTearDown(bloc.close);
      addTearDown(deps.wallet.dispose);
      addTearDown(() => transactionActivity.value = null);
      transactionActivity.value = TransactionActivity(
        startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
        stage: TransactionStage.submitting,
      );
      await tester.pumpWidget(
        RepositoryProvider.value(
          value: deps,
          child: BlocProvider.value(
            value: bloc,
            child: MaterialApp(
              theme: SwTheme.light(),
              home: const AppShell(
                current: AppRoute.employer,
                child: Center(child: Text('Payroll page')),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Your transaction is in progress'), findsOneWidget);
      expect(
        tester.getSize(find.byType(WalletActivityBanner)).height,
        lessThanOrEqualTo(size.height * 0.36),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

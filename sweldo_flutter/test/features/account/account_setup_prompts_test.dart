import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/core/theme/app_theme.dart';
import 'package:sweldo/features/account/bloc/account_setup_cubit.dart';
import 'package:sweldo/features/account/data/account_repository.dart';
import 'package:sweldo/features/account/data/local_test_faucet.dart';
import 'package:sweldo/features/account/view/account_setup_prompts.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

class _Setup extends Cubit<AccountSetupState> implements AccountSetupCubit {
  _Setup(super.initialState);
  @override
  String get assetCode => 'USDC';
  @override
  bool selectAsset(Asset asset) => false;
  @override
  Future<void> fund() async {}
  @override
  Future<void> enableAsset() async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> fundAsset() async {
    emit(state.copyWith(fundingAsset: true));
    await Future<void>.delayed(Duration.zero);
    emit(
      state.copyWith(
        fundingAsset: false,
        balances: () =>
            const WalletBalances(xlm: '10000', asset: '25', reservedXlm: 1.5),
        fundingReceipt: TestFundingReceipt('funded', 'a' * 64),
      ),
    );
  }
}

void main() {
  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('local funding control and receipt fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = _Setup(
        const AccountSetupState(
          address: 'test-public-address',
          faucetAvailable: true,
          balances: WalletBalances(xlm: '10000', asset: '0', reservedXlm: 1.5),
        ),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: SwTheme.light(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: BlocProvider<AccountSetupCubit>.value(
                value: cubit,
                child: const AccountSetupPrompts(
                  trustlineMessage: 'Add a trustline.',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('0 test-USDC available'), findsOneWidget);
      await tester.tap(find.text('Get 25 test-USDC'));
      await tester.pumpAndSettle();
      expect(find.text('Get 25 test-USDC'), findsNothing);
      expect(find.text('25 test-USDC available'), findsNothing);
      expect(find.text('View funding transaction'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final amount in ['0.0000001', '1', '24.99', '25', '100']) {
    testWidgets('USDC funding prompt is hidden with $amount already held', (
      tester,
    ) async {
      final cubit = _Setup(
        AccountSetupState(
          address: 'test-public-address',
          faucetAvailable: true,
          balances: WalletBalances(
            xlm: '10000',
            asset: amount,
            reservedXlm: 1.5,
          ),
        ),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: SwTheme.light(),
          home: Scaffold(
            body: BlocProvider<AccountSetupCubit>.value(
              value: cubit,
              child: const AccountSetupPrompts(
                trustlineMessage: 'Add a trustline.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Get 25 test-USDC'), findsNothing);
      expect(find.textContaining('test-USDC available'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('funding prompt reappears only when the balance reaches zero', (
    tester,
  ) async {
    final cubit = _Setup(
      const AccountSetupState(
        address: 'test-public-address',
        faucetAvailable: true,
        balances: WalletBalances(xlm: '10000', asset: '1', reservedXlm: 1.5),
      ),
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: SwTheme.light(),
        home: Scaffold(
          body: BlocProvider<AccountSetupCubit>.value(
            value: cubit,
            child: const AccountSetupPrompts(
              trustlineMessage: 'Add a trustline.',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Get 25 test-USDC'), findsNothing);
    cubit.emit(
      cubit.state.copyWith(
        balances: () =>
            const WalletBalances(xlm: '10000', asset: '0', reservedXlm: 1.5),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get 25 test-USDC'), findsOneWidget);
  });
}

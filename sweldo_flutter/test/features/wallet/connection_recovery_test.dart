import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweldo/core/error/app_exception.dart';
import 'package:sweldo/core/storage/local_store.dart';
import 'package:sweldo/features/wallet/data/wallet_connector.dart';
import 'package:sweldo/features/wallet/data/wallet_repository.dart';
import 'package:sweldo/features/wallet/domain/wallet_session.dart';

class _Connector extends Mock implements WalletConnector {}

void main() {
  testWidgets('a stalled restore times out and ignores its late session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sweldo-last-wallet-v1': 'freighterExtension',
    });
    final store = await LocalStore.open();
    final connector = _Connector();
    final response = Completer<WalletSession?>();
    when(() => connector.kind).thenReturn(WalletKind.freighterExtension);
    when(() => connector.isAvailable).thenReturn(true);
    when(() => connector.disconnects).thenAnswer((_) => const Stream.empty());
    when(() => connector.restore()).thenAnswer((_) => response.future);
    final repository = WalletRepository(connectors: [connector], store: store);
    addTearDown(repository.dispose);
    final pending = repository.restore();
    await tester.pump(const Duration(seconds: 16));
    expect(await pending, isNull);
    response.complete(
      const WalletSession(
        address: 'late',
        network: 'TESTNET',
        kind: WalletKind.freighterExtension,
      ),
    );
    await tester.pump();
    expect(repository.session, isNull);
  });

  testWidgets(
    'a stalled connection is cancelled and a late approval cannot connect',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final connector = _Connector();
      final response = Completer<WalletSession>();
      when(() => connector.kind).thenReturn(WalletKind.freighterMobile);
      when(() => connector.isAvailable).thenReturn(true);
      when(() => connector.disconnects).thenAnswer((_) => const Stream.empty());
      when(() => connector.connect(onPairingUri: any(named: 'onPairingUri')))
          .thenAnswer((_) => response.future);
      when(() => connector.disconnect()).thenAnswer((_) async {});
      final repository = WalletRepository(
        connectors: [connector],
        store: store,
      );
      addTearDown(repository.dispose);
      final pending = repository.connect(WalletKind.freighterMobile);
      final expectation = expectLater(pending, throwsA(isA<WalletException>()));
      await tester.pump(const Duration(minutes: 2, seconds: 1));
      await expectation;
      verify(() => connector.disconnect()).called(1);
      response.complete(
        const WalletSession(
          address: 'late',
          network: 'TESTNET',
          kind: WalletKind.freighterMobile,
        ),
      );
      await tester.pump();
      expect(repository.session, isNull);
      expect(store.readString('sweldo-last-wallet-v1'), isNull);
    },
  );
}

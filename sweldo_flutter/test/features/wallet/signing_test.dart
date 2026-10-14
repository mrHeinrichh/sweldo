import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/error/app_exception.dart';
import 'package:sweldo/core/storage/local_store.dart';
import 'package:sweldo/features/wallet/data/wallet_connector.dart';
import 'package:sweldo/features/wallet/data/wallet_repository.dart';
import 'package:sweldo/features/wallet/domain/wallet_session.dart';

class _Wallet extends WalletConnector {
  _Wallet(this.account);
  WalletSession account;
  Completer<WalletSession>? approval;
  Completer<String>? signature;
  @override
  WalletKind get kind => WalletKind.xbull;
  @override
  bool get isAvailable => true;
  @override
  String? get unavailableReason => null;
  @override
  Future<WalletSession?> restore() async => null;
  @override
  Future<WalletSession> connect({void Function(Uri uri)? onPairingUri}) async =>
      approval == null ? account : approval!.future;
  @override
  Future<WalletSession> currentSession() async => account;
  @override
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
    required String networkPassphrase,
  }) async => signature!.future;
  @override
  Future<void> disconnect() async {}
}

void main() {
  final key = KeyPair.random();
  final recipient = KeyPair.random();
  Transaction transaction({String amount = '1'}) =>
      TransactionBuilder(Account(key.accountId, BigInt.one))
          .addOperation(
            PaymentOperationBuilder(
              recipient.accountId,
              Asset.NATIVE,
              amount,
            ).build(),
          )
          .addPreconditions(
            TransactionPreconditions()..timeBounds = TimeBounds(0, 2000000000),
          )
          .build();
  WalletSession session([String network = 'TESTNET', String? address]) =>
      WalletSession(
        address: address ?? key.accountId,
        network: network,
        kind: WalletKind.xbull,
      );
  String signed(Transaction tx, [Network? network, KeyPair? signer]) {
    tx.sign(signer ?? key, network ?? Network.TESTNET);
    return tx.toEnvelopeXdrBase64();
  }

  late _Wallet connector;
  late WalletRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    connector = _Wallet(session());
    repository = WalletRepository(
      connectors: [connector],
      store: await LocalStore.open(),
    );
  });
  tearDown(() => repository.dispose());
  test('cancelled connection cannot be restored by a late approval', () async {
    connector.approval = Completer();
    final connecting = repository.connect(WalletKind.xbull);
    final rejected = expectLater(connecting, throwsA(isA<WalletException>()));
    repository.cancelPendingConnection();
    connector.approval!.complete(session());
    await rejected;
    expect(repository.session, isNull);
  });
  test('disconnect while signing rejects late approved signatures', () async {
    await repository.connect(WalletKind.xbull);
    connector.signature = Completer();
    final tx = transaction();
    final signing = repository.signTransaction(
      tx.toEnvelopeXdrBase64(),
      address: key.accountId,
    );
    final rejected = expectLater(signing, throwsA(isA<WalletException>()));
    await Future<void>.delayed(Duration.zero);
    await repository.disconnect();
    connector.signature!.complete(signed(tx));
    await rejected;
    expect(repository.session, isNull);
  });
  test('changed account or mainnet blocks wallet signing', () async {
    await repository.connect(WalletKind.xbull);
    final original = transaction().toEnvelopeXdrBase64();
    connector.account = session('PUBLIC');
    await expectLater(
      repository.signTransaction(original, address: key.accountId),
      throwsA(isA<WalletException>()),
    );
    connector.account = session('TESTNET', recipient.accountId);
    await expectLater(
      repository.signTransaction(original, address: key.accountId),
      throwsA(isA<WalletException>()),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/error/app_exception.dart';
import 'package:sweldo/core/stellar/stellar_network.dart';
import 'package:sweldo/features/wallet/data/kit/kit_bridge.dart';
import 'package:sweldo/features/wallet/data/kit/kit_wallet_connector.dart';
import 'package:sweldo/features/wallet/domain/wallet_session.dart';

class _Bridge extends KitBridge {
  Map<String, dynamic> result = {
    'ok': true,
    'address': KeyPair.random().accountId,
    'networkPassphrase': StellarNetwork.passphrase,
  };
  Map<String, dynamic>? request;
  bool cancelled = false;
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request) async {
    this.request = request;
    return result;
  }

  @override
  void cancel() {
    cancelled = true;
  }
}

void main() {
  test(
    'Kit sessions map explicit Testnet and report mainnet accurately',
    () async {
      final bridge = _Bridge();
      final connector = KitWalletConnector(WalletKind.xbull, bridge: bridge);
      expect((await connector.connect()).onTestnet, isTrue);
      expect(bridge.request, {'action': 'connect', 'kind': 'xbull'});
      bridge.result['networkPassphrase'] = Network.PUBLIC.networkPassphrase;
      bridge.result['network'] = 'TESTNET';
      expect((await connector.currentSession()).onTestnet, isFalse);
    },
  );
  test('a network name is used only when no passphrase was supplied', () async {
    final bridge = _Bridge()..result.remove('networkPassphrase');
    bridge.result['network'] = 'TESTNET';
    final connector = KitWalletConnector(WalletKind.xbull, bridge: bridge);
    expect((await connector.currentSession()).onTestnet, isTrue);
    bridge.result.remove('network');
    expect((await connector.currentSession()).onTestnet, isFalse);
  });
  test(
    'Kit errors and invalid public keys do not become wallet sessions',
    () async {
      final bridge = _Bridge();
      final connector = KitWalletConnector(WalletKind.xbull, bridge: bridge);
      bridge.result['address'] = 'invalid';
      await expectLater(connector.connect(), throwsA(isA<WalletException>()));
      bridge.result = {'ok': false, 'error': 'User cancelled'};
      await expectLater(connector.connect(), throwsA(isA<WalletException>()));
    },
  );
  test(
    'xBull never restores by prompting; disconnect cancels the bridge',
    () async {
      final bridge = _Bridge();
      final connector = KitWalletConnector(WalletKind.xbull, bridge: bridge);
      expect(await connector.restore(), isNull);
      expect(bridge.request, isNull);
      await connector.disconnect();
      expect(bridge.cancelled, isTrue);
    },
  );
}

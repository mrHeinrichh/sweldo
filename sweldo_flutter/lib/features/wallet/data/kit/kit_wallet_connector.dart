import 'package:flutter/foundation.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../domain/wallet_session.dart';
import '../wallet_connector.dart';
import 'kit_bridge.dart';

class KitWalletConnector extends WalletConnector {
  KitWalletConnector(this.kind, {KitBridge? bridge})
    : _bridge = bridge ?? createKitBridge();

  @override
  final WalletKind kind;
  final KitBridge _bridge;
  bool get _phone =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  String get _kitKind =>
      kind == WalletKind.xbull ? 'xbull' : 'freighter-extension';
  @override
  bool get isAvailable =>
      _bridge.available && (kind == WalletKind.xbull || (kIsWeb && !_phone));
  @override
  String? get unavailableReason => isAvailable
      ? null
      : 'Use Flutter web for browser extensions, or a supported Android/iOS wallet.';

  Future<Map<String, dynamic>> _request(
    String action, [
    Map<String, dynamic> values = const {},
  ]) async {
    final result = await _bridge.call({
      'action': action,
      'kind': _kitKind,
      ...values,
    });
    if (result['ok'] != true) {
      throw WalletException(
        result['error'] as String? ?? 'Wallet request failed.',
      );
    }
    return result;
  }

  WalletSession _session(Map<String, dynamic> result) {
    final address = result['address'];
    if (address is! String ||
        address.length != 56 ||
        !StrKey.isValidStellarAccountId(address)) {
      throw const WalletException(
        'The wallet did not return a valid Stellar public key.',
      );
    }
    final passphrase = result['networkPassphrase'];
    final testnet = passphrase == null
        ? result['network'] == 'TESTNET'
        : passphrase == StellarNetwork.passphrase;
    return WalletSession(
      address: address,
      network: testnet ? StellarNetwork.walletNetworkName : 'PUBLIC',
      kind: kind,
    );
  }

  @override
  Future<WalletSession> connect({void Function(Uri uri)? onPairingUri}) async =>
      _session(await _request('connect'));
  // xBull requires an explicit approval, never a startup popup.
  @override
  Future<WalletSession?> restore() async {
    if (kind != WalletKind.freighterExtension || !isAvailable) return null;
    try {
      return await currentSession();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<WalletSession> currentSession() async =>
      _session(await _request('current'));
  @override
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
    required String networkPassphrase,
  }) async =>
      (await _request('sign', {
            'xdr': envelopeXdr,
            'address': address,
            'networkPassphrase': networkPassphrase,
          }))['xdr']
          as String;
  @override
  Future<void> disconnect() async {
    _bridge.cancel();
  }
}

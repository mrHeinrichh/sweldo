import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:reown_core/reown_core.dart'
    show JsonRpcError, PairingMetadata, Redirect;
import 'package:reown_sign/reown_sign.dart'
    show
        ReownSignClient,
        ReownSignError,
        RequiredNamespace,
        SessionData,
        SessionRequestParams;

import '../../../../core/error/app_exception.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../domain/wallet_session.dart';
import '../wallet_connector.dart';
import 'freighter_links.dart';

/// Freighter Mobile (iOS/Android) over WalletConnect v2.
///
/// Freighter Mobile implements the `stellar` namespace with
/// `stellar_signXDR` (params `{xdr}`, result `{signedXDR}`) on the
/// `stellar:testnet` chain. Pairing opens the app through its registered
/// native link, `freighterwallet://wc-redirect` ([FreighterLinks]).
class FreighterMobileConnector extends WalletConnector {
  FreighterMobileConnector({
    required this.projectId,
    this.appUrl = 'https://sweldo.app',
  });

  final String projectId;
  final String appUrl;

  static const _namespace = 'stellar';
  static const _signMethod = 'stellar_signXDR';

  ReownSignClient? _client;
  SessionData? _session;
  final _disconnects = StreamController<void>.broadcast();

  @override
  WalletKind get kind => WalletKind.freighterMobile;

  @override
  bool get isAvailable => projectId.isNotEmpty;

  @override
  String? get unavailableReason => isAvailable
      ? null
      : 'Pairing with the Freighter app isn’t switched on for this version '
            'of Sweldo yet.';

  @override
  Stream<void> get disconnects => _disconnects.stream;

  /// A phone, whether the native app or a mobile browser (Flutter web reports
  /// the device's platform there too).
  bool get _onPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<ReownSignClient> _ensureClient() async {
    if (_client != null) return _client!;
    if (!isAvailable) throw WalletException(unavailableReason!);
    final client = await ReownSignClient.createInstance(
      projectId: projectId,
      metadata: PairingMetadata(
        name: 'Sweldo',
        description: 'Payroll locked on Stellar. Claim pay on payday.',
        url: appUrl,
        icons: const [],
        redirect: const Redirect(native: 'sweldo://'),
      ),
    );
    client.onSessionDelete.subscribe((_) {
      _session = null;
      _disconnects.add(null);
    });
    client.onSessionExpire.subscribe((_) {
      _session = null;
      _disconnects.add(null);
    });
    return _client = client;
  }

  WalletSession _toSession(SessionData session) {
    final accounts = session.namespaces[_namespace]?.accounts ?? const [];
    // CAIP-10: stellar:<network>:<address>
    final parsed = accounts
        .map((account) => account.split(':'))
        .where((parts) => parts.length == 3)
        .toList();
    if (parsed.isEmpty) {
      throw const WalletException(
        'Freighter did not share a Stellar account. Try pairing again.',
      );
    }
    final testnet = parsed.firstWhere(
      (parts) => '${parts[0]}:${parts[1]}' == StellarNetwork.walletConnectChain,
      orElse: () => parsed.first,
    );
    final onTestnet =
        '${testnet[0]}:${testnet[1]}' == StellarNetwork.walletConnectChain;
    return WalletSession(
      address: testnet[2],
      network: onTestnet ? StellarNetwork.walletNetworkName : 'PUBLIC',
      kind: kind,
    );
  }

  @override
  Future<WalletSession?> restore() async {
    if (!isAvailable) return null;
    try {
      final client = await _ensureClient();
      final sessions = client.getActiveSessions().values.where(
        (s) => s.namespaces.containsKey(_namespace),
      );
      if (sessions.isEmpty) return null;
      _session = sessions.first;
      return _toSession(_session!);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<WalletSession> connect({void Function(Uri uri)? onPairingUri}) async {
    final client = await _ensureClient();
    final response = await client.connect(
      optionalNamespaces: {
        _namespace: const RequiredNamespace(
          chains: [StellarNetwork.walletConnectChain],
          methods: [_signMethod, 'stellar_signAndSubmitXDR'],
          events: ['accountsChanged'],
        ),
      },
    );
    final uri = response.uri;
    if (uri != null) {
      onPairingUri?.call(uri);
      // Freighter, or its store page if it isn't installed.
      if (_onPhone) unawaited(FreighterLinks.open(FreighterLinks.pair(uri)));
    }
    try {
      _session = await response.session.future.timeout(
        const Duration(minutes: 5),
      );
    } on TimeoutException {
      throw const WalletException(
        'Freighter did not approve the connection in time. Try again.',
      );
    } on JsonRpcError catch (error) {
      throw WalletException(
        _rpcMessage(error, 'Freighter declined to connect'),
      );
    }
    return _toSession(_session!);
  }

  @override
  Future<WalletSession> currentSession() async {
    final session = _session;
    if (session == null) {
      throw const WalletException(
        'The Freighter app is not connected. Pair it again.',
      );
    }
    return _toSession(session);
  }

  @override
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
    required String networkPassphrase,
  }) async {
    final client = await _ensureClient();
    final session = _session;
    if (session == null) {
      throw const WalletException(
        'The Freighter app is not connected. Pair it again.',
      );
    }
    final pending = client.request(
      topic: session.topic,
      chainId: StellarNetwork.walletConnectChain,
      request: SessionRequestParams(
        method: _signMethod,
        params: {'xdr': envelopeXdr},
      ),
    );
    // Bring Freighter forward so the request is in front of the person.
    if (_onPhone) {
      unawaited(FreighterLinks.open(FreighterLinks.app, storeFallback: false));
    }

    final dynamic result;
    try {
      result = await pending.timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw const WalletException(
        'Freighter did not answer in time. Nothing was submitted.',
      );
    } on JsonRpcError catch (error) {
      throw WalletException(
        _rpcMessage(error, 'Freighter could not sign the transaction'),
      );
    }
    final signed = result is Map ? result['signedXDR'] : null;
    if (signed is! String || signed.isEmpty) {
      throw const WalletException(
        'Freighter returned no signature. Nothing was submitted.',
      );
    }
    return signed;
  }

  @override
  Future<void> disconnect() async {
    final client = _client;
    final session = _session;
    _session = null;
    if (client == null || session == null) return;
    try {
      await client.disconnect(
        topic: session.topic,
        reason: const ReownSignError(code: 6000, message: 'User disconnected'),
      );
    } catch (_) {
      // The relay may already have dropped the session.
    }
  }

  String _rpcMessage(JsonRpcError error, String label) {
    final message = error.message;
    if (message == null || message.isEmpty) return '$label.';
    if (message.toLowerCase().contains('reject')) {
      return 'You declined the request in Freighter. Nothing was submitted.';
    }
    return '$label: $message';
  }
}

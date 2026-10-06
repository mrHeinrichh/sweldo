import 'dart:async';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/stellar/stellar_network.dart';
import '../../../core/stellar/transaction_signer.dart';
import '../domain/wallet_session.dart';
import 'wallet_connector.dart';

/// Owns the connected wallet. Features read the session from [sessions] and
/// sign through this repository; none of them know which Freighter is in use.
class WalletRepository implements TransactionSigner {
  WalletRepository({
    required List<WalletConnector> connectors,
    required LocalStore store,
  }) : _connectors = {for (final c in connectors) c.kind: c},
       _store = store {
    for (final connector in connectors) {
      connector.disconnects.listen((_) {
        if (_active == connector) _setSession(null, null);
      });
    }
  }

  static const _lastWalletKey = 'sweldo-last-wallet-v1';

  final Map<WalletKind, WalletConnector> _connectors;
  final LocalStore _store;
  final _sessions = StreamController<WalletSession?>.broadcast();

  WalletConnector? _active;
  WalletSession? _session;

  WalletSession? get session => _session;
  Stream<WalletSession?> get sessions => _sessions.stream;

  List<WalletConnector> get connectors => _connectors.values.toList();

  void _setSession(WalletSession? session, WalletConnector? connector) {
    _session = session;
    _active = connector;
    _sessions.add(session);
  }

  /// Reconnects to the wallet used last time, without prompting.
  Future<WalletSession?> restore() async {
    final last = _store.readString(_lastWalletKey);
    final kind = WalletKind.values.where((k) => k.name == last).firstOrNull;
    final connector = kind == null ? null : _connectors[kind];
    if (connector == null || !connector.isAvailable) return null;
    final session = await connector.restore();
    if (session != null) _setSession(session, connector);
    return session;
  }

  Future<WalletSession> connect(
    WalletKind kind, {
    void Function(Uri uri)? onPairingUri,
  }) async {
    final connector = _connectors[kind];
    if (connector == null || !connector.isAvailable) {
      throw WalletException(
        connector?.unavailableReason ??
            '${kind.title} is not available in this build.',
      );
    }
    final session = await connector.connect(onPairingUri: onPairingUri);
    if (_active != null && _active != connector) {
      await _active!.disconnect();
    }
    _setSession(session, connector);
    await _store.writeString(_lastWalletKey, kind.name);
    return session;
  }

  Future<void> disconnect() async {
    await _active?.disconnect();
    await _store.remove(_lastWalletKey);
    _setSession(null, null);
  }

  /// Re-reads the wallet right before a sensitive signature and confirms it
  /// is still [expectedAddress] on Testnet.
  Future<void> ensureActiveAccount(String expectedAddress) async {
    final connector = _requireActive();
    final current = await connector.currentSession();
    if (!current.onTestnet) {
      throw const WalletException(
        'Switch Freighter to Testnet before signing.',
      );
    }
    if (current.address != expectedAddress) {
      throw const WalletException(
        'The selected Freighter account changed. Reconnect the worker wallet.',
      );
    }
  }

  @override
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
  }) {
    return _requireActive().signTransaction(
      envelopeXdr,
      address: address,
      networkPassphrase: StellarNetwork.passphrase,
    );
  }

  WalletConnector _requireActive() {
    final connector = _active;
    if (connector == null || _session == null) {
      throw const WalletException('Connect Freighter to continue.');
    }
    return connector;
  }

  Future<void> dispose() => _sessions.close();
}

import 'dart:async';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/stellar/stellar_network.dart';
import '../../../core/stellar/transaction_signer.dart';
import '../domain/wallet_session.dart';
import 'wallet_connector.dart';
import 'signing_guard.dart';

/// Owns the connected wallet. Features read the session from [sessions] and
/// sign through this repository without depending on a wallet brand.
class WalletRepository implements TransactionSigner {
  WalletRepository({
    required List<WalletConnector> connectors,
    required LocalStore store,
  }) : _connectors = {for (final c in connectors) c.kind: c},
       _store = store {
    for (final connector in connectors) {
      connector.disconnects.listen((_) {
        if (_active == connector) {
          _version++;
          _setSession(null, null);
        }
      });
    }
  }

  static const _lastWalletKey = 'sweldo-last-wallet-v1';

  final Map<WalletKind, WalletConnector> _connectors;
  final LocalStore _store;
  final _sessions = StreamController<WalletSession?>.broadcast();

  WalletConnector? _active;
  WalletSession? _session;
  int _version = 0;
  WalletConnector? _pending;

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
    final version = ++_version;
    final last = _store.readString(_lastWalletKey);
    final kind = WalletKind.values.where((k) => k.name == last).firstOrNull;
    final connector = kind == null ? null : _connectors[kind];
    if (connector == null || !connector.isAvailable) return null;
    final session = await connector.restore();
    if (version != _version) return null;
    if (session != null) _setSession(session, connector);
    return session;
  }

  Future<WalletSession> connect(
    WalletKind kind, {
    void Function(Uri uri)? onPairingUri,
  }) async {
    final version = ++_version;
    final connector = _connectors[kind];
    if (connector == null || !connector.isAvailable) {
      throw WalletException(
        connector?.unavailableReason ??
            '${kind.title} is not available in this build.',
      );
    }
    _pending = connector;
    late final WalletSession session;
    try {
      session = await connector.connect(
        onPairingUri: (uri) {
          if (_version == version) onPairingUri?.call(uri);
        },
      );
    } finally {
      if (_version == version) _pending = null;
    }
    if (_version != version) {
      throw const WalletException('Wallet connection cancelled.');
    }
    if (_active != null && _active != connector) {
      await _active!.disconnect();
    }
    if (_version != version) {
      throw const WalletException('Wallet connection cancelled.');
    }
    _setSession(session, connector);
    await _store.writeString(_lastWalletKey, kind.name);
    return session;
  }

  Future<void> disconnect() async {
    cancelPendingConnection();
    _version++;
    final connector = _active;
    _setSession(null, null);
    await connector?.disconnect();
    await _store.remove(_lastWalletKey);
  }

  void cancelPendingConnection() {
    _version++;
    final pending = _pending;
    _pending = null;
    if (pending != null) unawaited(pending.disconnect());
  }

  /// Re-reads the wallet right before a sensitive signature and confirms it
  /// is still [expectedAddress] on Testnet.
  Future<void> ensureActiveAccount(String expectedAddress) async {
    final connector = _requireActive();
    final current = await connector.currentSession();
    if (!current.onTestnet) {
      throw const WalletException(
        'Switch your wallet to Testnet before signing.',
      );
    }
    if (current.address != expectedAddress) {
      throw const WalletException(
        'The selected wallet account changed. Reconnect the intended wallet.',
      );
    }
  }

  @override
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
  }) async {
    final connector = _requireActive();
    final version = _version;
    reviewedTransaction(envelopeXdr, address);
    await ensureActiveAccount(address);
    if (version != _version || _active != connector) {
      throw const WalletException(
        'Wallet session changed. Nothing was submitted.',
      );
    }
    final signed = await connector.signTransaction(
      envelopeXdr,
      address: address,
      networkPassphrase: StellarNetwork.passphrase,
    );
    if (version != _version || _active != connector) {
      throw const WalletException(
        'Wallet session changed during signing. Nothing was submitted.',
      );
    }
    await ensureActiveAccount(address);
    if (version != _version || _active != connector) {
      throw const WalletException(
        'Wallet session changed. Nothing was submitted.',
      );
    }
    return verifiedSignature(envelopeXdr, signed, address);
  }

  WalletConnector _requireActive() {
    final connector = _active;
    if (connector == null || _session == null) {
      throw const WalletException('Connect a supported wallet to continue.');
    }
    return connector;
  }

  Future<void> dispose() => _sessions.close();
}

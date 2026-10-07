import '../domain/wallet_session.dart';

/// One way of talking to a Freighter wallet.
abstract class WalletConnector {
  WalletKind get kind;

  /// Whether this connector can work on the current platform and build.
  bool get isAvailable;

  /// Why [isAvailable] is false, phrased as what to do about it.
  String? get unavailableReason;

  /// Reconnects silently to a wallet the person already approved.
  Future<WalletSession?> restore();

  /// Asks the wallet for access. [onPairingUri] receives a WalletConnect URI
  /// to show as a QR code or open as a deep link.
  Future<WalletSession> connect({void Function(Uri uri)? onPairingUri});

  /// Reads the wallet's current account and network without prompting.
  Future<WalletSession> currentSession();

  /// Returns the envelope signed by [address].
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
    required String networkPassphrase,
  });

  Future<void> disconnect();

  /// Emits when the wallet ends the session from its side.
  Stream<void> get disconnects => const Stream.empty();
}

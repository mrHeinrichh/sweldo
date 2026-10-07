import '../../../../core/error/app_exception.dart';
import '../../domain/wallet_session.dart';
import '../wallet_connector.dart';

/// Native builds can't reach a browser extension.
class FreighterExtensionConnector extends WalletConnector {
  @override
  WalletKind get kind => WalletKind.freighterExtension;

  @override
  bool get isAvailable => false;

  @override
  String? get unavailableReason =>
      'The extension works in the web version of Sweldo. On this device, use '
      'the Freighter app.';

  Never _unsupported() => throw WalletException(unavailableReason!);

  @override
  Future<WalletSession?> restore() async => null;

  @override
  Future<WalletSession> connect({void Function(Uri uri)? onPairingUri}) async =>
      _unsupported();

  @override
  Future<WalletSession> currentSession() async => _unsupported();

  @override
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
    required String networkPassphrase,
  }) async => _unsupported();

  @override
  Future<void> disconnect() async {}
}

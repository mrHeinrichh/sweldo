part of 'wallet_bloc.dart';

sealed class WalletEvent {
  const WalletEvent();
}

/// App start: reconnect silently to the wallet used last time.
final class WalletStarted extends WalletEvent {
  const WalletStarted();
}

final class WalletConnectRequested extends WalletEvent {
  const WalletConnectRequested(this.kind);
  final WalletKind kind;
}

final class WalletDisconnectRequested extends WalletEvent {
  const WalletDisconnectRequested();
}

/// The pairing sheet was closed before Freighter approved.
final class WalletPairingDismissed extends WalletEvent {
  const WalletPairingDismissed();
}

final class _WalletSessionChanged extends WalletEvent {
  const _WalletSessionChanged(this.session);
  final WalletSession? session;
}

final class _WalletPairingUriReceived extends WalletEvent {
  const _WalletPairingUriReceived(this.uri);
  final Uri uri;
}

part of 'wallet_bloc.dart';

enum WalletStatus { initial, restoring, disconnected, connecting, connected }

/// A one-shot message for the snackbar. [id] changes on every message so the
/// same text can be shown twice.
class WalletMessage extends Equatable {
  const WalletMessage(
    this.id,
    this.text, {
    this.isError = false,
    this.walletMissing = false,
  });

  final int id;
  final String text;
  final bool isError;
  final bool walletMissing;

  @override
  List<Object?> get props => [id, text, isError, walletMissing];
}

class WalletState extends Equatable {
  const WalletState({
    this.status = WalletStatus.initial,
    this.session,
    this.connectingKind,
    this.pairingUri,
    this.xlmBalance,
    this.message,
  });

  final WalletStatus status;
  final WalletSession? session;
  final WalletKind? connectingKind;

  /// WalletConnect URI to show while pairing with the Freighter app.
  final Uri? pairingUri;
  final String? xlmBalance;
  final WalletMessage? message;

  bool get isConnected => session != null;
  bool get isBusy =>
      status == WalletStatus.connecting || status == WalletStatus.restoring;
  bool get wrongNetwork => session != null && !session!.onTestnet;

  WalletState copyWith({
    WalletStatus? status,
    WalletSession? Function()? session,
    WalletKind? Function()? connectingKind,
    Uri? Function()? pairingUri,
    String? Function()? xlmBalance,
    WalletMessage? message,
  }) {
    return WalletState(
      status: status ?? this.status,
      session: session != null ? session() : this.session,
      connectingKind: connectingKind != null
          ? connectingKind()
          : this.connectingKind,
      pairingUri: pairingUri != null ? pairingUri() : this.pairingUri,
      xlmBalance: xlmBalance != null ? xlmBalance() : this.xlmBalance,
      message: message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
    status,
    session,
    connectingKind,
    pairingUri,
    xlmBalance,
    message,
  ];
}

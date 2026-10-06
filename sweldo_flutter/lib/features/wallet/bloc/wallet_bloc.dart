import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/error/error_messages.dart';
import '../../../core/stellar/horizon_client.dart';
import '../../../core/utils/amount.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet_session.dart';

part 'wallet_event.dart';
part 'wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required WalletRepository repository,
    required HorizonClient horizon,
  }) : _repository = repository,
       _horizon = horizon,
       super(const WalletState()) {
    on<WalletStarted>(_onStarted);
    on<WalletConnectRequested>(_onConnectRequested);
    on<WalletDisconnectRequested>(_onDisconnectRequested);
    on<WalletPairingDismissed>(_onPairingDismissed);
    on<_WalletSessionChanged>(_onSessionChanged);
    on<_WalletPairingUriReceived>(
      (event, emit) => emit(state.copyWith(pairingUri: () => event.uri)),
    );
    _subscription = _repository.sessions.listen(
      (s) => add(_WalletSessionChanged(s)),
    );
  }

  final WalletRepository _repository;
  final HorizonClient _horizon;
  late final StreamSubscription<WalletSession?> _subscription;
  int _messageId = 0;

  WalletMessage _message(
    String text, {
    bool isError = false,
    bool walletMissing = false,
  }) => WalletMessage(
    ++_messageId,
    text,
    isError: isError,
    walletMissing: walletMissing,
  );

  Future<void> _onStarted(
    WalletStarted event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(status: WalletStatus.restoring));
    try {
      final session = await _repository.restore();
      if (session == null) {
        emit(state.copyWith(status: WalletStatus.disconnected));
      }
    } catch (_) {
      emit(state.copyWith(status: WalletStatus.disconnected));
    }
  }

  Future<void> _onConnectRequested(
    WalletConnectRequested event,
    Emitter<WalletState> emit,
  ) async {
    if (state.status == WalletStatus.connecting) return;
    emit(
      state.copyWith(
        status: WalletStatus.connecting,
        connectingKind: () => event.kind,
        pairingUri: () => null,
      ),
    );
    try {
      final session = await _repository.connect(
        event.kind,
        onPairingUri: (uri) => add(_WalletPairingUriReceived(uri)),
      );
      String? balance;
      String text;
      try {
        balance = await _horizon.xlmBalance(session.address);
        text = 'Connected. ${Amount.format(balance)} XLM available.';
      } catch (error) {
        text = isNotFound(error)
            ? "Connected. This wallet isn't funded on Testnet yet."
            : 'Connected.';
      }
      emit(
        state.copyWith(
          status: WalletStatus.connected,
          session: () => session,
          connectingKind: () => null,
          pairingUri: () => null,
          xlmBalance: () => balance,
          message: _message(text),
        ),
      );
    } catch (error) {
      if (state.status != WalletStatus.connecting) return;
      emit(
        state.copyWith(
          status: state.session == null
              ? WalletStatus.disconnected
              : WalletStatus.connected,
          connectingKind: () => null,
          pairingUri: () => null,
          message: _message(
            friendlyError(error),
            isError: true,
            walletMissing: error is WalletException && error.walletMissing,
          ),
        ),
      );
    }
  }

  void _onPairingDismissed(
    WalletPairingDismissed event,
    Emitter<WalletState> emit,
  ) {
    if (state.status != WalletStatus.connecting) return;
    emit(
      state.copyWith(
        status: state.session == null
            ? WalletStatus.disconnected
            : WalletStatus.connected,
        connectingKind: () => null,
        pairingUri: () => null,
      ),
    );
  }

  Future<void> _onDisconnectRequested(
    WalletDisconnectRequested event,
    Emitter<WalletState> emit,
  ) async {
    await _repository.disconnect();
    emit(state.copyWith(message: _message('Wallet disconnected.')));
  }

  Future<void> _onSessionChanged(
    _WalletSessionChanged event,
    Emitter<WalletState> emit,
  ) async {
    final session = event.session;
    if (session == null) {
      emit(
        state.copyWith(
          status: WalletStatus.disconnected,
          session: () => null,
          xlmBalance: () => null,
        ),
      );
      return;
    }
    // Connect emits its own state with the balance; restores land here.
    if (state.status == WalletStatus.connecting) return;
    emit(
      state.copyWith(status: WalletStatus.connected, session: () => session),
    );
    try {
      final balance = await _horizon.xlmBalance(session.address);
      emit(state.copyWith(xlmBalance: () => balance));
    } catch (_) {
      // Unfunded wallets are handled by the funding prompt.
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

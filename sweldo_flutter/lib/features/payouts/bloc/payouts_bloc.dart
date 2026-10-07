import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/error/error_messages.dart';
import '../../../core/stellar/stellar_network.dart';
import '../../../core/utils/amount.dart';
import '../../../core/utils/parallel.dart';
import '../../../core/widgets/notice.dart';
import '../../conversion/domain/conversion_quote.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_session.dart';
import '../data/claim_history_store.dart';
import '../data/payouts_repository.dart';
import '../domain/claim_record.dart';
import '../domain/payout.dart';

part 'payouts_event.dart';
part 'payouts_state.dart';

/// The employee's vesting timeline and claims.
class PayoutsBloc extends Bloc<PayoutsEvent, PayoutsState> {
  PayoutsBloc({
    required PayoutsRepository repository,
    required ClaimHistoryStore historyStore,
    required WalletRepository wallet,
    DateTime Function()? clock,
  }) : _repository = repository,
       _historyStore = historyStore,
       _now = clock ?? DateTime.now,
       super(const PayoutsState()) {
    on<PayoutsWalletChanged>(_onWalletChanged);
    on<PayoutsRefreshRequested>(_onRefreshRequested);
    on<PayoutClaimRequested>(_onClaimRequested);
    on<PayoutConversionCompleted>(_onConversionCompleted);
    on<PayoutsNoticeDismissed>(
      (event, emit) => emit(state.copyWith(notice: () => null)),
    );

    _walletSubscription = wallet.sessions.listen(
      (s) => add(PayoutsWalletChanged(s)),
    );
    add(PayoutsWalletChanged(wallet.session));
  }

  final PayoutsRepository _repository;
  final ClaimHistoryStore _historyStore;
  final DateTime Function() _now;
  late final StreamSubscription<WalletSession?> _walletSubscription;

  Future<void> _onWalletChanged(
    PayoutsWalletChanged event,
    Emitter<PayoutsState> emit,
  ) async {
    final address = event.session?.address;
    if (address == state.address) return;
    emit(PayoutsState(address: address));
    if (address != null) await _load(address, emit, clearNotice: true);
  }

  Future<void> _onRefreshRequested(
    PayoutsRefreshRequested event,
    Emitter<PayoutsState> emit,
  ) async {
    final address = state.address;
    if (address == null || state.loading) return;
    await _load(address, emit, clearNotice: true);
  }

  Future<void> _load(
    String address,
    Emitter<PayoutsState> emit, {
    bool clearNotice = false,
  }) async {
    emit(state.copyWith(loading: true));
    try {
      final (payouts, onChain) = await both(
        _repository.payoutsFor(address),
        _repository.claimHistory(address),
      );
      if (state.address != address) return;
      final live = payouts.map((p) => p.balanceId).toSet();
      emit(
        state.copyWith(
          loading: false,
          loaded: true,
          payouts: payouts,
          history: mergeClaimHistory(_historyStore.read(address), onChain),
          // Stamped rows stay visible until the ledger stops listing them.
          claimedHashes: Map.of(state.claimedHashes)
            ..removeWhere((id, _) => !live.contains(id)),
          notice: clearNotice ? () => null : null,
        ),
      );
    } catch (error) {
      if (state.address != address) return;
      emit(
        state.copyWith(
          loading: false,
          loaded: true,
          notice: () => NoticeData.error(friendlyError(error)),
        ),
      );
    }
  }

  Future<void> _onClaimRequested(
    PayoutClaimRequested event,
    Emitter<PayoutsState> emit,
  ) async {
    final address = state.address;
    final payout = event.payout;
    if (address == null || state.claimingId != null) return;
    emit(
      state.copyWith(claimingId: () => payout.balanceId, notice: () => null),
    );
    try {
      final hash = await _repository.claim(address, payout.balanceId);
      final record = ClaimRecord(
        id: payout.balanceId,
        balanceId: payout.balanceId,
        transactionHash: hash,
        claimedAt: _now(),
        amount: payout.amount,
        asset: payout.assetCode,
        source: ClaimSource.local,
      );
      await _saveQuietly(address, record);
      emit(
        state.copyWith(
          claimingId: () => null,
          claimedHashes: {...state.claimedHashes, payout.balanceId: hash},
          history: mergeClaimHistory([record], state.history),
          freshClaimKey: () => record.proofKey,
          notice: () => NoticeData.success(
            '${Amount.format(payout.amount)} ${payout.assetCode} claimed. It is '
            'in your wallet now.',
            link: Explorer.transaction(hash),
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          claimingId: () => null,
          notice: () => NoticeData.error(friendlyError(error)),
        ),
      );
    }
  }

  Future<void> _onConversionCompleted(
    PayoutConversionCompleted event,
    Emitter<PayoutsState> emit,
  ) async {
    final address = state.address;
    if (address == null) return;
    final receipt = event.receipt;
    final record = ClaimRecord(
      id: receipt.balanceId,
      balanceId: receipt.balanceId,
      transactionHash: receipt.hash,
      claimedAt: _now(),
      amount: receipt.receivedAmount,
      asset: 'PHPT',
      source: ClaimSource.local,
    );
    // A full storage quota must not hide a confirmed receipt.
    await _saveQuietly(address, record);
    emit(
      state.copyWith(
        receipt: () => receipt,
        claimedHashes: {
          ...state.claimedHashes,
          receipt.balanceId: receipt.hash,
        },
        history: mergeClaimHistory([record], state.history),
        freshClaimKey: () => record.proofKey,
      ),
    );
    await _load(address, emit);
  }

  Future<void> _saveQuietly(String address, ClaimRecord record) async {
    try {
      await _historyStore.save(address, record);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await _walletSubscription.cancel();
    return super.close();
  }
}

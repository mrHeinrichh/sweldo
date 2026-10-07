import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/notice.dart';
import '../../../wallet/data/wallet_repository.dart';
import '../../../wallet/domain/wallet_session.dart';
import '../../data/payroll_repository.dart';
import '../../data/schedule_store.dart';
import '../../domain/payroll_schedule.dart';

part 'schedules_event.dart';
part 'schedules_state.dart';

/// Recent schedules and cancelling their future payouts.
class SchedulesBloc extends Bloc<SchedulesEvent, SchedulesState> {
  SchedulesBloc({
    required ScheduleStore store,
    required PayrollRepository payroll,
    required WalletRepository wallet,
    DateTime Function()? clock,
  }) : _store = store,
       _payroll = payroll,
       _now = clock ?? DateTime.now,
       super(SchedulesState(schedules: store.read())) {
    on<SchedulesWalletChanged>(_onWalletChanged);
    on<SchedulesRefreshRequested>(_onRefreshRequested);
    on<ScheduleCancelRequested>(_onCancelRequested);
    on<SchedulesNoticeDismissed>(
      (event, emit) => emit(state.copyWith(notice: () => null)),
    );
    on<_SchedulesStoreChanged>(_onStoreChanged);

    _storeSubscription = store.changes.listen(
      (change) => add(_SchedulesStoreChanged(change)),
    );
    _walletSubscription = wallet.sessions.listen(
      (session) => add(SchedulesWalletChanged(session)),
    );
    add(SchedulesWalletChanged(wallet.session));
  }

  final ScheduleStore _store;
  final PayrollRepository _payroll;
  final DateTime Function() _now;
  late final StreamSubscription<ScheduleStoreChange> _storeSubscription;
  late final StreamSubscription<WalletSession?> _walletSubscription;

  Future<void> _onWalletChanged(
    SchedulesWalletChanged event,
    Emitter<SchedulesState> emit,
  ) async {
    final address = event.session?.address;
    emit(
      state.copyWith(
        address: () => address,
        activeBalanceIds: const {},
        balancesLoaded: false,
      ),
    );
    if (address != null) await _loadBalances(address, emit);
  }

  Future<void> _onRefreshRequested(
    SchedulesRefreshRequested event,
    Emitter<SchedulesState> emit,
  ) async {
    final address = state.address;
    if (address == null) return;
    emit(state.copyWith(balancesLoaded: false));
    await _loadBalances(address, emit);
  }

  Future<void> _loadBalances(
    String address,
    Emitter<SchedulesState> emit,
  ) async {
    try {
      final ids = await _payroll.activeBalanceIds(address);
      if (state.address != address) return;
      emit(state.copyWith(activeBalanceIds: ids.toSet(), balancesLoaded: true));
    } catch (_) {
      if (state.address != address) return;
      emit(state.copyWith(activeBalanceIds: const {}, balancesLoaded: true));
    }
  }

  void _onStoreChanged(
    _SchedulesStoreChanged event,
    Emitter<SchedulesState> emit,
  ) {
    final change = event.change;
    emit(
      state.copyWith(
        schedules: change.schedules,
        activeBalanceIds: {...state.activeBalanceIds, ...change.addedBalanceIds}
          ..removeAll(change.removedBalanceIds),
        balancesLoaded:
            state.balancesLoaded || change.addedBalanceIds.isNotEmpty,
      ),
    );
  }

  Future<void> _onCancelRequested(
    ScheduleCancelRequested event,
    Emitter<SchedulesState> emit,
  ) async {
    final session = event.session;
    final schedule = event.schedule;
    if (state.cancellingId != null) return;
    if (!session.onTestnet) {
      emit(
        state.copyWith(
          notice: () => const NoticeData.error(
            'Switch Freighter to Testnet, then reconnect.',
          ),
        ),
      );
      return;
    }
    if (schedule.employer != session.address) {
      emit(
        state.copyWith(
          notice: () => const NoticeData.error(
            'Connect the employer wallet that originally funded this payroll.',
          ),
        ),
      );
      return;
    }

    emit(state.copyWith(cancellingId: () => schedule.id, notice: () => null));
    try {
      // Re-check the ledger: a payout may have reached payday since the
      // confirmation was shown.
      final latest = (await _payroll.activeBalanceIds(session.address)).toSet();
      emit(state.copyWith(activeBalanceIds: latest, balancesLoaded: true));
      final ids = cancellableBalanceIds(schedule, latest, _now());
      if (ids.isEmpty) {
        throw StateError(
          'No future payouts remain. Payouts at or past payday '
          'cannot be cancelled.',
        );
      }
      final hash = await _payroll.cancelBalances(session.address, ids);
      await _store.update(
        schedule.id,
        (saved) => saved.copyWith(
          cancelledAt: _now(),
          cancelHash: hash,
          cancelledPayouts: (saved.cancelledPayouts ?? 0) + ids.length,
        ),
        removedBalanceIds: ids,
      );
      emit(
        state.copyWith(
          cancellingId: () => null,
          notice: () => NoticeData.success(
            '${ids.length} future ${plural(ids.length, 'payout was', 'payouts were')} '
            'cancelled and returned to your wallet.',
            link: Explorer.transaction(hash),
            linkLabel: 'View cancellation',
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          cancellingId: () => null,
          notice: () => NoticeData.error(friendlyError(error)),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _storeSubscription.cancel();
    await _walletSubscription.cancel();
    return super.close();
  }
}

import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/widgets/notice.dart';
import '../../../wallet/data/wallet_repository.dart';
import '../../../wallet/domain/wallet_session.dart';
import '../../data/payroll_repository.dart';
import '../../data/schedule_store.dart';
import '../../domain/payroll_schedule.dart';

part 'schedules_event.dart';
part 'schedules_state.dart';

class SchedulesBloc extends Bloc<SchedulesEvent, SchedulesState> {
  SchedulesBloc({
    required ScheduleStore store,
    required PayrollRepository payroll,
    required WalletRepository wallet,
    DateTime Function()? clock,
  }) : _store = store,
       _payroll = payroll,
       _now = clock ?? DateTime.now,
       super(const SchedulesState(schedules: [])) {
    on<SchedulesWalletChanged>((event, emit) async {
      if (event.session != null) await _load(event.session!.address, emit);
    });
    on<SchedulesInspectRequested>(
      (event, emit) => _load(event.address.trim(), emit),
    );
    on<SchedulesRefreshRequested>((event, emit) async {
      if (state.address != null) await _load(state.address!, emit);
    });
    on<ScheduleCancelRequested>(_cancel);
    on<SchedulesNoticeDismissed>(
      (event, emit) => emit(state.copyWith(notice: () => null)),
    );
    on<_SchedulesStoreChanged>((event, emit) async {
      if (state.address != null) await _load(state.address!, emit);
    });
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
  int _readVersion = 0;

  Future<void> _load(String address, Emitter<SchedulesState> emit) async {
    final version = ++_readVersion;
    emit(
      state.copyWith(
        address: () => address,
        loading: true,
        balancesLoaded: false,
        schedules: [],
        activeBalanceIds: {},
        checkedAt: () => null,
        notice: () => null,
      ),
    );
    try {
      final result = await _payroll.ledger.reconstruct(address, now: _now());
      if (version != _readVersion || emit.isDone) return;
      final labels = _store.read();
      final schedules = result.schedules.map((schedule) {
        final label = labels
            .where(
              (s) => s.hash == schedule.hash && s.employee == schedule.employee,
            )
            .firstOrNull;
        return label == null
            ? schedule
            : schedule.copyWith(
                name: label.name,
                registryHash: label.registryHash,
                registryContractId: label.registryContractId,
              );
      }).toList();
      emit(
        state.copyWith(
          schedules: schedules,
          loading: false,
          balancesLoaded: true,
          checkedAt: () => result.checkedAt,
          activeBalanceIds: schedules
              .expand((s) => s.payouts)
              .where((p) => p.active)
              .map((p) => p.balanceId)
              .toSet(),
          notice: () => result.warnings.isEmpty
              ? null
              : NoticeData.error(result.warnings.first),
        ),
      );
    } catch (error) {
      if (version != _readVersion || emit.isDone) return;
      emit(
        state.copyWith(
          loading: false,
          balancesLoaded: false,
          checkedAt: () => null,
          activeBalanceIds: {},
          notice: () => NoticeData.error(friendlyError(error)),
        ),
      );
    }
  }

  Future<void> _cancel(
    ScheduleCancelRequested event,
    Emitter<SchedulesState> emit,
  ) async {
    if (state.cancellingId != null) return;
    final session = event.session;
    final schedule = event.schedule;
    if (!session.onTestnet || schedule.employer != session.address) {
      emit(
        state.copyWith(
          notice: () => const NoticeData.error(
            'Connect the employer wallet on Testnet before cancelling.',
          ),
        ),
      );
      return;
    }
    emit(state.copyWith(cancellingId: () => schedule.id, notice: () => null));
    try {
      final fresh = await _payroll.ledger.reconstruct(
        session.address,
        now: _now(),
      );
      final current = fresh.schedules
          .where((s) => s.id == schedule.id)
          .firstOrNull;
      if (current == null) {
        throw StateError('Refresh before cancelling this payroll.');
      }
      final active = current.payouts
          .where((p) => p.active)
          .map((p) => p.balanceId)
          .toSet();
      final ids = cancellableBalanceIds(current, active, _now());
      if (ids.isEmpty) {
        throw StateError(
          'No verified future payouts remain. Payouts at or past payday cannot be cancelled.',
        );
      }
      final hash = await _payroll.cancelBalances(session.address, ids);
      await _load(session.address, emit);
      emit(
        state.copyWith(
          cancellingId: () => null,
          notice: () => NoticeData.success(
            '${ids.length} future payouts returned to your wallet.',
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
    _readVersion++;
    await _storeSubscription.cancel();
    await _walletSubscription.cancel();
    return super.close();
  }
}

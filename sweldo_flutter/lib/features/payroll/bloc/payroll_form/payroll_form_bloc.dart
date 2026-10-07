import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/notice.dart';
import '../../../wallet/domain/wallet_session.dart';
import '../../data/payroll_repository.dart';
import '../../data/registry_repository.dart';
import '../../data/schedule_store.dart';
import '../../domain/pay_cadence.dart';
import '../../domain/payroll_sample.dart';
import '../../domain/payroll_recipient.dart';
import '../../domain/payroll_schedule.dart';

part 'payroll_form_event.dart';
part 'payroll_form_state.dart';

/// The "New payroll" form and its one-signature submission.
class PayrollFormBloc extends Bloc<PayrollFormEvent, PayrollFormState> {
  PayrollFormBloc({
    required PayrollRepository payroll,
    required RegistryRepository registry,
    required ScheduleStore store,
    required Asset asset,
    required String assetLabel,
    DateTime Function()? clock,
    String Function()? newId,
    Random? random,
  }) : this._(
         payroll: payroll,
         registry: registry,
         store: store,
         asset: asset,
         assetLabel: assetLabel,
         clock: clock ?? DateTime.now,
         newId: newId ?? const Uuid().v4,
         sampler: PayrollSampler(random),
       );

  PayrollFormBloc._({
    required PayrollRepository payroll,
    required RegistryRepository registry,
    required ScheduleStore store,
    required Asset asset,
    required String assetLabel,
    required DateTime Function() clock,
    required String Function() newId,
    required PayrollSampler sampler,
  }) : _payroll = payroll,
       _registry = registry,
       _store = store,
       _asset = asset,
       _assetLabel = assetLabel,
       _now = clock,
       _newId = newId,
       _sampler = sampler,
       // Every visit starts from a fresh random sample.
       super(
         _rolled(
           sampler,
           PayrollFormState(recipients: [PayrollRecipient(id: newId())]),
         ),
       ) {
    on<RecipientAdded>(
      (event, emit) => emit(
        state.copyWith(
          recipients: [
            ...state.recipients,
            PayrollRecipient(id: _newId()),
          ],
        ),
      ),
    );
    on<RecipientRemoved>(_onRecipientRemoved);
    on<RecipientChanged>(_onRecipientChanged);
    on<PayoutCountChanged>(
      (event, emit) =>
          emit(state.copyWith(payouts: event.payouts.clamp(0, 999))),
    );
    on<CadenceChanged>(
      (event, emit) => emit(state.copyWith(cadence: event.cadence)),
    );
    on<ScheduleChanged>(
      (event, emit) => emit(
        state.copyWith(
          cadence: event.cadence,
          payouts: event.payouts?.clamp(1, 999),
          firstPaydayIn: event.firstPaydayIn?.clamp(0, 9999),
          // Choosing "in N intervals" replaces a picked date unless a new
          // date comes with it.
          firstPaydayAt:
              event.firstPaydayAt ??
              (event.firstPaydayIn != null ? () => null : null),
        ),
      ),
    );
    on<FirstPaydayChanged>(
      (event, emit) => emit(
        state.copyWith(
          firstPaydayIn: event.intervalsFromNow.clamp(0, 9999),
          firstPaydayAt: () => null,
        ),
      ),
    );
    on<PayrollSubmitted>(_onSubmitted);
    on<PayrollNoticeDismissed>(
      (event, emit) => emit(state.copyWith(notice: () => null)),
    );
    on<PayrollRandomized>((event, emit) => emit(_rolled(_sampler, state)));
  }

  final PayrollSampler _sampler;

  /// New sample values for every field except the wallet addresses people
  /// typed: locking pay to random keys would strand it after payday.
  static PayrollFormState _rolled(
    PayrollSampler sampler,
    PayrollFormState from,
  ) {
    final rows = from.recipients;
    final payouts = sampler.payouts(rows.length);
    final names = sampler.namesFor(rows.length);
    return from.copyWith(
      recipients: [
        for (var i = 0; i < rows.length; i++)
          rows[i].copyWith(name: names[i], total: sampler.totalFor(payouts)),
      ],
      payouts: payouts,
      cadence: sampler.cadence(),
      firstPaydayIn: sampler.firstPaydayIn(),
      firstPaydayAt: () => null,
      shuffles: from.shuffles + 1,
      notice: () => null,
    );
  }

  final PayrollRepository _payroll;
  final RegistryRepository _registry;
  final ScheduleStore _store;
  final Asset _asset;
  final String _assetLabel;
  final DateTime Function() _now;
  final String Function() _newId;

  void _onRecipientRemoved(
    RecipientRemoved event,
    Emitter<PayrollFormState> emit,
  ) {
    if (state.recipients.length == 1) return;
    emit(
      state.copyWith(
        recipients: state.recipients.where((r) => r.id != event.id).toList(),
      ),
    );
  }

  void _onRecipientChanged(
    RecipientChanged event,
    Emitter<PayrollFormState> emit,
  ) {
    emit(
      state.copyWith(
        recipients: [
          for (final r in state.recipients)
            if (r.id == event.id)
              r.copyWith(
                name: event.name,
                employee: event.employee?.trim(),
                total: event.total,
              )
            else
              r,
        ],
      ),
    );
  }

  /// Returns the first validation problem, worded as what to fix.
  String? validate(WalletSession session) {
    if (!session.onTestnet) {
      return 'Switch Freighter to Testnet, then reconnect.';
    }
    final rows = state.recipients;
    if (rows.any((r) => !r.hasValidAddress)) {
      return 'Every employee needs a valid 56-character Stellar public key '
          '(starts with G).';
    }
    if (rows.any(
          (r) => (Amount.tryUnits(r.total) ?? BigInt.zero) <= BigInt.zero,
        ) ||
        state.payouts < 1 ||
        state.payouts > StellarNetwork.maxPayoutsPerEmployee) {
      return 'Use positive payroll amounts and 1–50 payouts.';
    }
    if (rows.any(
      (r) => Amount.tryUnits(state.amountPerPayout(r.total))! <= BigInt.zero,
    )) {
      return 'An amount is too small to split into ${state.payouts} payouts.';
    }
    if (state.overOperationLimit) {
      return 'This batch is too large for one Stellar transaction. Keep '
          'employees × payouts at 100 or less.';
    }
    return null;
  }

  Future<void> _onSubmitted(
    PayrollSubmitted event,
    Emitter<PayrollFormState> emit,
  ) async {
    if (state.submitting) return;
    final session = event.session;
    final problem = validate(session);
    if (problem != null) {
      emit(state.copyWith(notice: () => NoticeData.error(problem)));
      return;
    }

    final rows = state.recipients;
    final payouts = state.payouts;
    final cadence = state.cadence;
    final firstUnlock = state.firstPayday(_now());

    emit(
      state.copyWith(
        submitting: true,
        progress: () => 'Confirm in Freighter…',
        notice: () => null,
      ),
    );
    try {
      final result = await _payroll.createBatchSchedule(
        employer: session.address,
        recipients: [
          for (final r in rows)
            ScheduleRecipient(
              employee: r.employee,
              amountPerPayout: state.amountPerPayout(r.total),
            ),
        ],
        payouts: payouts,
        firstUnlock: firstUnlock,
        intervalSeconds: cadence.seconds,
        asset: _asset,
      );

      final createdAt = _now();
      final schedules = [
        for (var i = 0; i < rows.length; i++)
          PayrollSchedule(
            id: _newId(),
            employee: rows[i].employee,
            name: rows[i].name.trim().isEmpty
                ? 'Team member'
                : rows[i].name.trim(),
            total: Amount.string(Amount.tryUnits(rows[i].total)!),
            tranches: payouts,
            asset: _assetLabel,
            createdAt: createdAt,
            hash: result.hash,
            employer: session.address,
            balanceIds: result.balanceIds
                .skip(i * payouts)
                .take(payouts)
                .toList(),
            firstUnlock: firstUnlock,
            intervalSeconds: cadence.seconds,
            revocable: true,
          ),
      ];

      // Record proof metadata for the first schedule in the Soroban registry.
      RegistryProof? registryProof;
      var registryWarning = '';
      final first = schedules.first;
      if (_registry.isConfigured && first.balanceIds.isNotEmpty) {
        emit(
          state.copyWith(progress: () => 'Recording proof in the registry…'),
        );
        try {
          registryProof = await _registry.recordScheduleProof(
            employer: session.address,
            employee: first.employee,
            total: first.total,
            asset: _assetLabel,
            cadenceSeconds: cadence.seconds,
            claimableBalanceId: first.balanceIds.first,
            payoutTxHash: result.hash,
          );
          if (registryProof != null) {
            schedules[0] = first.copyWith(
              registryHash: registryProof.hash,
              registryContractId: registryProof.contractId,
            );
          }
        } catch (error) {
          registryWarning =
              ' The Soroban registry proof was not recorded: ${friendlyError(error)}';
        }
      }

      await _store.prepend(schedules, balanceIds: result.balanceIds);

      final people = '${rows.length} ${plural(rows.length, 'employee')}';
      emit(
        state.copyWith(
          submitting: false,
          progress: () => null,
          lastProof: () => PayrollProof(
            hash: result.hash,
            total: Amount.string(state.totalLockedUnits),
            balanceCount: rows.length * payouts,
            employeeCount: rows.length,
            payouts: payouts,
            firstUnlock: firstUnlock,
            asset: _assetLabel,
            registryHash: registryProof?.hash,
            registryContractId: registryProof?.contractId,
          ),
          notice: () => NoticeData.success(
            'Payroll locked for $people'
            '${registryProof != null ? ' and recorded in the Soroban registry' : ''}. '
            'You can cancel future payouts until each payday.$registryWarning',
            link: Explorer.transaction(result.hash),
            linkLabel: 'View payroll transaction',
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          submitting: false,
          progress: () => null,
          notice: () => NoticeData.error(friendlyError(error)),
        ),
      );
    }
  }
}

part of 'schedules_bloc.dart';

sealed class SchedulesEvent {
  const SchedulesEvent();
}

final class SchedulesWalletChanged extends SchedulesEvent {
  const SchedulesWalletChanged(this.session);
  final WalletSession? session;
}

final class SchedulesRefreshRequested extends SchedulesEvent {
  const SchedulesRefreshRequested();
}

/// Cancel every remaining future payout of [schedule]. The UI confirms
/// first; the bloc re-checks the ledger before signing.
final class ScheduleCancelRequested extends SchedulesEvent {
  const ScheduleCancelRequested(this.schedule, this.session);
  final PayrollSchedule schedule;
  final WalletSession session;
}

final class SchedulesNoticeDismissed extends SchedulesEvent {
  const SchedulesNoticeDismissed();
}

final class _SchedulesStoreChanged extends SchedulesEvent {
  const _SchedulesStoreChanged(this.change);
  final ScheduleStoreChange change;
}

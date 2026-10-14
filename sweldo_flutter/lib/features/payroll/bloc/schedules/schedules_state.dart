part of 'schedules_bloc.dart';

class SchedulesState extends Equatable {
  const SchedulesState({
    required this.schedules,
    this.address,
    this.activeBalanceIds = const {},
    this.balancesLoaded = false,
    this.cancellingId,
    this.notice,
    this.loading = false,
    this.checkedAt,
  });

  final List<PayrollSchedule> schedules;

  /// The connected wallet, if any.
  final String? address;

  /// Balance IDs still on the ledger with the connected wallet as claimant.
  final Set<String> activeBalanceIds;
  final bool balancesLoaded;
  final String? cancellingId;
  final NoticeData? notice;
  final bool loading;
  final DateTime? checkedAt;

  List<String> cancellableFor(PayrollSchedule schedule, DateTime now) =>
      cancellableBalanceIds(schedule, activeBalanceIds, now);

  SchedulesState copyWith({
    List<PayrollSchedule>? schedules,
    String? Function()? address,
    Set<String>? activeBalanceIds,
    bool? balancesLoaded,
    String? Function()? cancellingId,
    NoticeData? Function()? notice,
    bool? loading,
    DateTime? Function()? checkedAt,
  }) => SchedulesState(
    schedules: schedules ?? this.schedules,
    address: address != null ? address() : this.address,
    activeBalanceIds: activeBalanceIds ?? this.activeBalanceIds,
    balancesLoaded: balancesLoaded ?? this.balancesLoaded,
    cancellingId: cancellingId != null ? cancellingId() : this.cancellingId,
    notice: notice != null ? notice() : this.notice,
    loading: loading ?? this.loading,
    checkedAt: checkedAt != null ? checkedAt() : this.checkedAt,
  );

  @override
  List<Object?> get props => [
    schedules,
    address,
    activeBalanceIds,
    balancesLoaded,
    cancellingId,
    notice,
    loading,
    checkedAt,
  ];
}

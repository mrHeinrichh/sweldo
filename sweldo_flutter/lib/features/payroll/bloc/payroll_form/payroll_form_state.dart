part of 'payroll_form_bloc.dart';

class PayrollFormState extends Equatable {
  const PayrollFormState({
    required this.recipients,
    this.payouts = 4,
    this.cadence = PayCadence.minute,
    this.firstPaydayIn = 1,
    this.submitting = false,
    this.progress,
    this.notice,
    this.lastProof,
    this.shuffles = 0,
    this.firstPaydayAt,
  });

  final List<PayrollRecipient> recipients;

  /// Payouts (tranches) per employee.
  final int payouts;
  final PayCadence cadence;

  /// First payday, counted in [cadence] intervals from now.
  final int firstPaydayIn;
  final bool submitting;

  /// What the submission is waiting on, for the button label.
  final String? progress;
  final NoticeData? notice;
  final PayrollProof? lastProof;

  /// Counts Shuffle presses, so fields can flash when their values roll.
  final int shuffles;

  /// A specific first payday picked on the calendar. Overrides
  /// [firstPaydayIn] when set.
  final DateTime? firstPaydayAt;

  /// Most payouts each employee can have while the whole team still fits
  /// in one transaction.
  int get capacity =>
      (StellarNetwork.maxOperationsPerTransaction ~/
              (recipients.isEmpty ? 1 : recipients.length))
          .clamp(1, StellarNetwork.maxPayoutsPerEmployee);

  /// When the first payout unlocks if the payroll is locked at [now].
  DateTime firstPayday(DateTime now) {
    final picked = firstPaydayAt;
    if (picked != null) return picked.isAfter(now) ? picked : now;
    return now.add(cadence.interval * firstPaydayIn);
  }

  /// Every payday of the schedule, for previews and insights.
  List<DateTime> paydays(DateTime now) {
    final first = firstPayday(now);
    return [for (var i = 0; i < payouts; i++) first.add(cadence.interval * i)];
  }

  int get balanceCount => recipients.length * payouts;

  bool get overOperationLimit =>
      balanceCount > StellarNetwork.maxOperationsPerTransaction;

  BigInt get totalLockedUnits => recipients.fold(
    BigInt.zero,
    (sum, r) => sum + (Amount.tryUnits(r.total) ?? BigInt.zero),
  );

  String amountPerPayout(String total) => Amount.perPayout(total, payouts);

  PayrollFormState copyWith({
    List<PayrollRecipient>? recipients,
    int? payouts,
    PayCadence? cadence,
    int? firstPaydayIn,
    bool? submitting,
    String? Function()? progress,
    NoticeData? Function()? notice,
    PayrollProof? Function()? lastProof,
    int? shuffles,
    DateTime? Function()? firstPaydayAt,
  }) => PayrollFormState(
    recipients: recipients ?? this.recipients,
    payouts: payouts ?? this.payouts,
    cadence: cadence ?? this.cadence,
    firstPaydayIn: firstPaydayIn ?? this.firstPaydayIn,
    submitting: submitting ?? this.submitting,
    progress: progress != null ? progress() : this.progress,
    notice: notice != null ? notice() : this.notice,
    lastProof: lastProof != null ? lastProof() : this.lastProof,
    shuffles: shuffles ?? this.shuffles,
    firstPaydayAt: firstPaydayAt != null ? firstPaydayAt() : this.firstPaydayAt,
  );

  @override
  List<Object?> get props => [
    recipients,
    payouts,
    cadence,
    firstPaydayIn,
    submitting,
    progress,
    notice,
    lastProof,
    shuffles,
    firstPaydayAt,
  ];
}

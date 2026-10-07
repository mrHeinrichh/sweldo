part of 'payroll_form_bloc.dart';

sealed class PayrollFormEvent {
  const PayrollFormEvent();
}

final class RecipientAdded extends PayrollFormEvent {
  const RecipientAdded();
}

final class RecipientRemoved extends PayrollFormEvent {
  const RecipientRemoved(this.id);
  final String id;
}

final class RecipientChanged extends PayrollFormEvent {
  const RecipientChanged(this.id, {this.name, this.employee, this.total});
  final String id;
  final String? name;
  final String? employee;
  final String? total;
}

final class PayoutCountChanged extends PayrollFormEvent {
  const PayoutCountChanged(this.payouts);
  final int payouts;
}

final class CadenceChanged extends PayrollFormEvent {
  const CadenceChanged(this.cadence);
  final PayCadence cadence;
}

final class FirstPaydayChanged extends PayrollFormEvent {
  const FirstPaydayChanged(this.intervalsFromNow);
  final int intervalsFromNow;
}

/// Several schedule settings at once (presets, the schedule sentence).
/// Pass [firstPaydayAt] as a function so it can be cleared with `() => null`.
final class ScheduleChanged extends PayrollFormEvent {
  const ScheduleChanged({
    this.cadence,
    this.payouts,
    this.firstPaydayIn,
    this.firstPaydayAt,
  });
  final PayCadence? cadence;
  final int? payouts;
  final int? firstPaydayIn;
  final DateTime? Function()? firstPaydayAt;
}

/// Lock the whole payroll on Stellar with the connected wallet.
final class PayrollSubmitted extends PayrollFormEvent {
  const PayrollSubmitted(this.session);
  final WalletSession session;
}

/// Every visit to the page starts a fresh draft: new sample values for
/// every field except wallet addresses, back on the first step.
final class PayrollDraftStarted extends PayrollFormEvent {
  const PayrollDraftStarted();
}

/// Moves the wizard to [step] (0 team, 1 schedule, 2 review and lock).
final class PayrollStepChanged extends PayrollFormEvent {
  const PayrollStepChanged(this.step);
  final int step;
}

final class PayrollNoticeDismissed extends PayrollFormEvent {
  const PayrollNoticeDismissed();
}

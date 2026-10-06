import 'dart:async';

import '../../../core/storage/local_store.dart';
import '../domain/payroll_schedule.dart';

/// What changed in the store, including balance IDs the ledger may not have
/// indexed yet, so the schedules list can update without waiting on Horizon.
class ScheduleStoreChange {
  const ScheduleStoreChange(
    this.schedules, {
    this.addedBalanceIds = const [],
    this.removedBalanceIds = const [],
  });

  final List<PayrollSchedule> schedules;
  final List<String> addedBalanceIds;
  final List<String> removedBalanceIds;
}

/// Schedule labels and balance IDs, kept on this device under the same key
/// the React app uses.
class ScheduleStore {
  ScheduleStore(this._store);

  static const key = 'sweldo-schedules-v1';

  final LocalStore _store;
  final _changes = StreamController<ScheduleStoreChange>.broadcast();

  Stream<ScheduleStoreChange> get changes => _changes.stream;

  List<PayrollSchedule> read() =>
      _store.readList(key).map(PayrollSchedule.fromJson).toList();

  /// Newest schedules go first.
  Future<void> prepend(
    List<PayrollSchedule> schedules, {
    List<String> balanceIds = const [],
  }) async {
    final next = [...schedules, ...read()];
    await _write(next);
    _changes.add(ScheduleStoreChange(next, addedBalanceIds: balanceIds));
  }

  Future<void> update(
    String id,
    PayrollSchedule Function(PayrollSchedule) change, {
    List<String> removedBalanceIds = const [],
  }) async {
    final next = [
      for (final schedule in read())
        if (schedule.id == id) change(schedule) else schedule,
    ];
    await _write(next);
    _changes.add(
      ScheduleStoreChange(next, removedBalanceIds: removedBalanceIds),
    );
  }

  Future<void> _write(List<PayrollSchedule> schedules) =>
      _store.writeList(key, schedules.map((s) => s.toJson()).toList());
}

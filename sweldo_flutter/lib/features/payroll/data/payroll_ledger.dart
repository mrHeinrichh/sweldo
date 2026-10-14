import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/stellar/horizon_client.dart';
import '../../../core/utils/amount.dart';
import '../domain/payroll_schedule.dart';

typedef LedgerRead =
    Future<Map<String, dynamic>?> Function(String path, {bool allowMissing});

class PayrollLedgerState {
  const PayrollLedgerState(this.schedules, this.checkedAt, this.warnings);
  final List<PayrollSchedule> schedules;
  final DateTime checkedAt;
  final List<String> warnings;
}

Future<List<Map<String, dynamic>>> ledgerRecords(
  LedgerRead read,
  String path, {
  bool allowMissing = false,
}) async {
  final records = <Map<String, dynamic>>[];
  final visited = <String>{};
  String? next = path;
  while (next != null) {
    if (!visited.add(next) || visited.length > 1000) {
      throw const UserFacingException(
        'Horizon history is incomplete. Refresh before using this payroll state.',
      );
    }
    final first = visited.length == 1;
    final page = await read(next, allowMissing: first && allowMissing);
    if (page == null) {
      if (first && allowMissing) break;
      throw const UserFacingException('Horizon history is incomplete.');
    }
    final rows = page['_embedded']?['records'];
    if (rows is! List) {
      throw const UserFacingException(
        'Horizon returned an invalid history page.',
      );
    }
    if (rows.isEmpty) break;
    records.addAll(rows.map((row) => Map<String, dynamic>.from(row as Map)));
    next = page['_links']?['next']?['href'] as String?;
  }
  return records;
}

DateTime? absoluteDeadline(Map predicate) {
  final value =
      predicate['abs_before_epoch'] ??
      predicate['abs_before'] ??
      predicate['before_absolute_time'];
  if (value is! String && value is! num) return null;
  final seconds = int.tryParse('$value');
  try {
    return seconds == null
        ? DateTime.tryParse('$value')?.toUtc()
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

({String employee, DateTime unlockAt, String asset, String amount})?
payrollTerms(Map<String, dynamic> operation, String employer) {
  final claimants = operation['claimants'];
  if (operation['type'] != 'create_claimable_balance' ||
      operation['transaction_successful'] == false ||
      operation['source_account'] != employer ||
      operation['asset'] is! String ||
      operation['amount'] is! String ||
      claimants is! List ||
      claimants.length != 2) {
    return null;
  }
  final owner = claimants
      .where((c) => c['destination'] == employer)
      .firstOrNull;
  final worker = claimants
      .where((c) => c['destination'] != employer)
      .firstOrNull;
  if (owner == null ||
      worker == null ||
      owner['predicate'] is! Map ||
      worker['predicate'] is! Map) {
    return null;
  }
  final before = owner['predicate'] as Map;
  final after = worker['predicate'] as Map;
  const allowed = ['abs_before', 'abs_before_epoch', 'before_absolute_time'];
  if (before.keys.any((key) => !allowed.contains(key)) ||
      after.length != 1 ||
      after['not'] is! Map) {
    return null;
  }
  final not = after['not'] as Map;
  if (not.keys.any((key) => !allowed.contains(key))) return null;
  final deadline = absoluteDeadline(before);
  if (deadline == null || deadline != absoluteDeadline(not)) return null;
  return (
    employee: worker['destination'] as String,
    unlockAt: deadline,
    asset: operation['asset'] as String,
    amount: operation['amount'] as String,
  );
}

class PayrollLedger {
  PayrollLedger(HorizonClient horizon) : read = horizon.readJson;
  PayrollLedger.withReader(this.read);
  final LedgerRead read;

  Future<PayrollLedgerState> reconstruct(
    String employer, {
    DateTime? now,
  }) async {
    if (employer.length != 56 || !StrKey.isValidStellarAccountId(employer)) {
      throw const UserFacingException(
        'Enter a valid Stellar employer public key starting with G.',
      );
    }
    final checked = now ?? DateTime.now().toUtc();
    final operations = await ledgerRecords(
      read,
      '/accounts/$employer/operations?limit=100&order=desc&include_failed=false',
      allowMissing: true,
    );
    final groups =
        <
          String,
          List<
            ({
              Map<String, dynamic> operation,
              PayrollPayout payout,
              String asset,
              String employee,
            })
          >
        >{};
    final warnings = <String>[];
    final creates = operations
        .where((op) => payrollTerms(op, employer) != null)
        .toList();
    // Bounded concurrency keeps large account histories from flooding Horizon.
    var index = 0;
    Future<void> load() async {
      while (index < creates.length) {
        final operation = creates[index++];
        final terms = payrollTerms(operation, employer)!;
        final effects = await ledgerRecords(
          read,
          '/operations/${operation['id']}/effects?limit=100',
        );
        final balanceId = effects
            .where((e) => e['type'] == 'claimable_balance_created')
            .firstOrNull?['balance_id'];
        if (balanceId is! String ||
            !RegExp(r'^[a-fA-F0-9]{72}$').hasMatch(balanceId)) {
          throw const UserFacingException(
            'Horizon is missing a payroll balance ID. Refresh to recover complete state.',
          );
        }
        final history = await ledgerRecords(
          read,
          '/claimable_balances/$balanceId/operations?limit=100&order=desc&include_failed=false',
        );
        final claim = history
            .where(
              (op) =>
                  op['type'] == 'claim_claimable_balance' &&
                  op['transaction_successful'] != false &&
                  op['balance_id'] == balanceId,
            )
            .firstOrNull;
        final claimant = claim?['claimant'] ?? claim?['source_account'];
        var status = claimant == employer
            ? PayrollPayoutStatus.cancelled
            : claimant == terms.employee
            ? PayrollPayoutStatus.claimed
            : PayrollPayoutStatus.unverified;
        var active = false;
        if (status == PayrollPayoutStatus.unverified) {
          final live = await read(
            '/claimable_balances/$balanceId',
            allowMissing: true,
          );
          final liveTerms = live == null
              ? null
              : payrollTerms({
                  ...operation,
                  'claimants': live['claimants'],
                }, employer);
          if (live?['id'] == balanceId &&
              live?['asset'] == terms.asset &&
              live?['amount'] == terms.amount &&
              liveTerms?.unlockAt == terms.unlockAt &&
              liveTerms?.employee == terms.employee) {
            active = true;
            status = terms.unlockAt.isAfter(checked)
                ? PayrollPayoutStatus.scheduled
                : PayrollPayoutStatus.claimable;
          } else {
            warnings.add(
              'Status could not be verified for $balanceId. A missing balance alone does not prove a claim.',
            );
          }
        }
        final settled =
            status == PayrollPayoutStatus.claimed ||
            status == PayrollPayoutStatus.cancelled;
        final payout = PayrollPayout(
          balanceId: balanceId,
          amount: terms.amount,
          unlockAt: terms.unlockAt,
          active: active,
          status: status,
          settlementHash: settled
              ? (claim?['transaction_hash'] as String?)
              : null,
          settledAt: settled
              ? DateTime.tryParse(claim?['created_at'] ?? '')
              : null,
        );
        final id =
            '${operation['transaction_hash']}:${terms.employee}:${terms.asset}';
        (groups[id] ??= []).add((
          operation: operation,
          payout: payout,
          asset: terms.asset,
          employee: terms.employee,
        ));
      }
    }

    await Future.wait(List.generate(creates.length.clamp(0, 4), (_) => load()));
    final schedules = groups.entries.map((entry) {
      final items = entry.value
        ..sort((a, b) => a.payout.unlockAt.compareTo(b.payout.unlockAt));
      final first = items.first;
      final gaps = [
        for (var i = 1; i < items.length; i++)
          items[i].payout.unlockAt
              .difference(items[i - 1].payout.unlockAt)
              .inSeconds,
      ];
      final interval = gaps.isNotEmpty && gaps.every((gap) => gap == gaps.first)
          ? gaps.first
          : null;
      final cancelled = items
          .where((i) => i.payout.status == PayrollPayoutStatus.cancelled)
          .toList();
      return PayrollSchedule(
        id: entry.key,
        employer: employer,
        employee: first.employee,
        name: 'Team member',
        total: Amount.string(
          items.fold(
            BigInt.zero,
            (sum, item) => sum + Amount.units(item.payout.amount),
          ),
        ),
        tranches: items.length,
        asset: first.asset == 'native' ? 'XLM' : first.asset.split(':').first,
        createdAt: DateTime.parse(first.operation['created_at']),
        hash: first.operation['transaction_hash'],
        firstUnlock: first.payout.unlockAt,
        intervalSeconds: interval,
        revocable: true,
        balanceIds: items.map((i) => i.payout.balanceId).toList(),
        payouts: items.map((i) => i.payout).toList(),
        cancelledPayouts: cancelled.length,
        cancelledAt: cancelled.lastOrNull?.payout.settledAt,
        cancelHash: cancelled.lastOrNull?.payout.settlementHash,
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PayrollLedgerState(schedules, checked, warnings);
  }
}

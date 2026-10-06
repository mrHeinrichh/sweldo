import 'package:equatable/equatable.dart';

/// A funded payroll for one employee, remembered on this device.
///
/// Field names match the React app's `ScheduleMeta` so the JSON stays
/// compatible with what it stored under `sweldo-schedules-v1`.
class PayrollSchedule extends Equatable {
  const PayrollSchedule({
    required this.id,
    required this.employee,
    required this.name,
    required this.total,
    required this.tranches,
    required this.asset,
    required this.createdAt,
    required this.hash,
    this.employer,
    this.balanceIds = const [],
    this.firstUnlock,
    this.intervalSeconds,
    this.revocable = false,
    this.cancelledAt,
    this.cancelHash,
    this.cancelledPayouts,
    this.registryHash,
    this.registryContractId,
  });

  factory PayrollSchedule.fromJson(Map<String, dynamic> json) =>
      PayrollSchedule(
        id: json['id'] as String? ?? '',
        employee: json['employee'] as String? ?? '',
        name: json['name'] as String? ?? 'Team member',
        total: '${json['total'] ?? '0'}',
        tranches: (json['tranches'] as num?)?.toInt() ?? 1,
        asset: json['asset'] as String? ?? 'XLM',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        hash: json['hash'] as String? ?? '',
        employer: json['employer'] as String?,
        balanceIds: (json['balanceIds'] as List?)?.cast<String>() ?? const [],
        firstUnlock: DateTime.tryParse(json['firstUnlock'] as String? ?? ''),
        intervalSeconds: (json['intervalSeconds'] as num?)?.toInt(),
        revocable: json['revocable'] as bool? ?? false,
        cancelledAt: DateTime.tryParse(json['cancelledAt'] as String? ?? ''),
        cancelHash: json['cancelHash'] as String?,
        cancelledPayouts: (json['cancelledPayouts'] as num?)?.toInt(),
        registryHash: json['registryHash'] as String?,
        registryContractId: json['registryContractId'] as String?,
      );

  final String id;
  final String employee;
  final String name;
  final String total;
  final int tranches;
  final String asset;
  final DateTime createdAt;
  final String hash;
  final String? employer;
  final List<String> balanceIds;
  final DateTime? firstUnlock;
  final int? intervalSeconds;
  final bool revocable;
  final DateTime? cancelledAt;
  final String? cancelHash;
  final int? cancelledPayouts;
  final String? registryHash;
  final String? registryContractId;

  bool get isCancelled => cancelledAt != null;

  String get initial =>
      name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

  /// Payday of the payout at [index].
  DateTime? paydayAt(int index) {
    final first = firstUnlock;
    final interval = intervalSeconds;
    if (first == null || interval == null) return null;
    return first.add(Duration(seconds: index * interval));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee': employee,
    'name': name,
    'total': total,
    'tranches': tranches,
    'asset': asset,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'hash': hash,
    'employer': ?employer,
    'balanceIds': balanceIds,
    if (firstUnlock != null)
      'firstUnlock': firstUnlock!.toUtc().toIso8601String(),
    'intervalSeconds': ?intervalSeconds,
    'revocable': revocable,
    if (cancelledAt != null)
      'cancelledAt': cancelledAt!.toUtc().toIso8601String(),
    'cancelHash': ?cancelHash,
    'cancelledPayouts': ?cancelledPayouts,
    'registryHash': ?registryHash,
    'registryContractId': ?registryContractId,
  };

  PayrollSchedule copyWith({
    DateTime? cancelledAt,
    String? cancelHash,
    int? cancelledPayouts,
    String? registryHash,
    String? registryContractId,
  }) => PayrollSchedule(
    id: id,
    employee: employee,
    name: name,
    total: total,
    tranches: tranches,
    asset: asset,
    createdAt: createdAt,
    hash: hash,
    employer: employer,
    balanceIds: balanceIds,
    firstUnlock: firstUnlock,
    intervalSeconds: intervalSeconds,
    revocable: revocable,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancelHash: cancelHash ?? this.cancelHash,
    cancelledPayouts: cancelledPayouts ?? this.cancelledPayouts,
    registryHash: registryHash ?? this.registryHash,
    registryContractId: registryContractId ?? this.registryContractId,
  );

  @override
  List<Object?> get props => [
    id,
    employee,
    name,
    total,
    tranches,
    hash,
    balanceIds,
    cancelledAt,
    cancelHash,
    cancelledPayouts,
    registryHash,
  ];
}

/// Payouts the employer can still take back: on-chain, revocable, and whose
/// payday is still in the future. Port of `cancellableIds`.
List<String> cancellableBalanceIds(
  PayrollSchedule schedule,
  Set<String> activeBalanceIds,
  DateTime now,
) {
  if (!schedule.revocable ||
      schedule.balanceIds.isEmpty ||
      schedule.firstUnlock == null ||
      schedule.intervalSeconds == null) {
    return const [];
  }
  return [
    for (var i = 0; i < schedule.balanceIds.length; i++)
      if (activeBalanceIds.contains(schedule.balanceIds[i]) &&
          schedule.paydayAt(i)!.isAfter(now))
        schedule.balanceIds[i],
  ];
}

/// The summary shown after a payroll is locked.
class PayrollProof extends Equatable {
  const PayrollProof({
    required this.hash,
    required this.total,
    required this.balanceCount,
    required this.employeeCount,
    required this.payouts,
    required this.firstUnlock,
    required this.asset,
    this.registryHash,
    this.registryContractId,
  });

  final String hash;
  final String total;
  final int balanceCount;
  final int employeeCount;
  final int payouts;
  final DateTime firstUnlock;
  final String asset;
  final String? registryHash;
  final String? registryContractId;

  @override
  List<Object?> get props => [hash, registryHash];
}

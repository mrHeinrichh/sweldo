import 'package:equatable/equatable.dart';

enum ClaimSource { stellar, local }

/// A completed claim, from Horizon or remembered on this device (which also
/// knows the amount and asset).
class ClaimRecord extends Equatable {
  const ClaimRecord({
    required this.id,
    required this.balanceId,
    required this.claimedAt,
    required this.source,
    this.transactionHash,
    this.amount,
    this.asset,
  });

  factory ClaimRecord.fromJson(Map<String, dynamic> json) => ClaimRecord(
    id: json['id'] as String? ?? '',
    balanceId: json['balanceId'] as String? ?? '',
    transactionHash: json['transactionHash'] as String?,
    claimedAt:
        DateTime.tryParse(json['claimedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    amount: json['amount'] as String?,
    asset: json['asset'] as String?,
    source: json['source'] == 'stellar'
        ? ClaimSource.stellar
        : ClaimSource.local,
  );

  final String id;
  final String balanceId;
  final String? transactionHash;
  final DateTime claimedAt;
  final String? amount;
  final String? asset;
  final ClaimSource source;

  String get proofKey =>
      transactionHash != null ? 'tx:$transactionHash' : 'balance:$balanceId';

  Map<String, dynamic> toJson() => {
    'id': id,
    'balanceId': balanceId,
    'transactionHash': ?transactionHash,
    'claimedAt': claimedAt.toUtc().toIso8601String(),
    'amount': ?amount,
    'asset': ?asset,
    'source': source.name,
  };

  ClaimRecord copyWith({String? amount, String? asset, ClaimSource? source}) =>
      ClaimRecord(
        id: id,
        balanceId: balanceId,
        transactionHash: transactionHash,
        claimedAt: claimedAt,
        amount: amount ?? this.amount,
        asset: asset ?? this.asset,
        source: source ?? this.source,
      );

  @override
  List<Object?> get props => [
    id,
    balanceId,
    transactionHash,
    claimedAt,
    amount,
    asset,
    source,
  ];
}

/// Joins local and on-chain history by transaction (or balance), keeping the
/// richer local amount/asset. Newest first. Port of `mergeClaimHistory`.
List<ClaimRecord> mergeClaimHistory(
  List<ClaimRecord> local,
  List<ClaimRecord> onChain,
) {
  final byProof = <String, ClaimRecord>{};
  for (final record in [...local, ...onChain]) {
    final previous = byProof[record.proofKey];
    byProof[record.proofKey] = record.copyWith(
      amount: previous?.amount ?? record.amount,
      asset: previous?.asset ?? record.asset,
      source: previous?.source == ClaimSource.local
          ? ClaimSource.local
          : record.source,
    );
  }
  return byProof.values.toList()
    ..sort((a, b) => b.claimedAt.compareTo(a.claimedAt));
}

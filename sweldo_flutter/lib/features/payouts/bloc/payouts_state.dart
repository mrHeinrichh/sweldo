part of 'payouts_bloc.dart';

class PayoutsState extends Equatable {
  const PayoutsState({
    this.address,
    this.loading = false,
    this.loaded = false,
    this.payouts = const [],
    this.history = const [],
    this.claimingId,
    this.claimedHashes = const {},
    this.freshClaimKey,
    this.receipt,
    this.notice,
  });

  final String? address;
  final bool loading;
  final bool loaded;
  final List<Payout> payouts;
  final List<ClaimRecord> history;
  final String? claimingId;

  /// Payouts claimed in this session → transaction hash. They stay on the
  /// timeline, stamped, until Horizon stops listing them.
  final Map<String, String> claimedHashes;

  /// History entry to animate in with a stamp.
  final String? freshClaimKey;
  final ConversionReceipt? receipt;
  final NoticeData? notice;

  List<Payout> get openPayouts =>
      payouts.where((p) => !claimedHashes.containsKey(p.balanceId)).toList();

  /// Sum of everything still locked or claimable, in stroops.
  BigInt get totalUnits => openPayouts.fold(
    BigInt.zero,
    (sum, p) => sum + (Amount.tryUnits(p.amount) ?? BigInt.zero),
  );

  PayoutsState copyWith({
    bool? loading,
    bool? loaded,
    List<Payout>? payouts,
    List<ClaimRecord>? history,
    String? Function()? claimingId,
    Map<String, String>? claimedHashes,
    String? Function()? freshClaimKey,
    ConversionReceipt? Function()? receipt,
    NoticeData? Function()? notice,
  }) => PayoutsState(
    address: address,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    payouts: payouts ?? this.payouts,
    history: history ?? this.history,
    claimingId: claimingId != null ? claimingId() : this.claimingId,
    claimedHashes: claimedHashes ?? this.claimedHashes,
    freshClaimKey: freshClaimKey != null ? freshClaimKey() : this.freshClaimKey,
    receipt: receipt != null ? receipt() : this.receipt,
    notice: notice != null ? notice() : this.notice,
  );

  @override
  List<Object?> get props => [
    address,
    loading,
    loaded,
    payouts,
    history,
    claimingId,
    claimedHashes,
    freshClaimKey,
    receipt,
    notice,
  ];
}

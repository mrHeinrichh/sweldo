import 'package:equatable/equatable.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import 'claim_predicate.dart';

class PayoutClaimant extends Equatable {
  const PayoutClaimant(this.destination, this.predicate);

  final String destination;
  final ClaimPredicate predicate;

  @override
  List<Object?> get props => [destination];
}

/// One time-locked payout (tranche): a claimable balance on the ledger.
class Payout extends Equatable {
  const Payout({
    required this.balanceId,
    required this.amount,
    required this.asset,
    required this.claimants,
    this.sponsor,
  });

  factory Payout.fromResponse(ClaimableBalanceResponse response) => Payout(
    balanceId: response.balanceId,
    amount: response.amount,
    asset: Asset.canonicalForm(response.asset),
    sponsor: response.sponsor,
    claimants: response.claimants
        .map(
          (c) => PayoutClaimant(
            c.destination,
            ClaimPredicate.fromResponse(c.predicate),
          ),
        )
        .toList(),
  );

  final String balanceId;
  final String amount;

  /// `native` or `CODE:ISSUER`, as Horizon writes it.
  final String asset;
  final String? sponsor;
  final List<PayoutClaimant> claimants;

  String get assetCode => asset == 'native' ? 'XLM' : asset.split(':').first;

  PayoutClaimant? claimantFor(String address) =>
      claimants.where((c) => c.destination == address).firstOrNull;

  /// When [address] may claim. Null means no time lock.
  DateTime? unlockTimeFor(String address) =>
      claimantFor(address)?.predicate.unlockTime;

  bool isUnlockedFor(String address, DateTime now) {
    final unlock = unlockTimeFor(address);
    return unlock == null || !now.isBefore(unlock);
  }

  @override
  List<Object?> get props => [balanceId, amount, asset];
}

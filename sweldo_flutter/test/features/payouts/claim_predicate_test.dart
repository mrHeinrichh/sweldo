import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/features/payouts/domain/claim_predicate.dart';
import 'package:sweldo/features/payouts/domain/claim_record.dart';
import 'package:sweldo/features/payouts/domain/payout.dart';

ClaimantPredicateResponse _before(String time) =>
    ClaimantPredicateResponse(null, null, null, null, time, null);

void main() {
  final payday = DateTime.utc(2026, 11, 3, 9);

  group('ClaimPredicate', () {
    test("reads Sweldo's employee predicate: not(before(payday))", () {
      final predicate = ClaimPredicate.fromResponse(ClaimantPredicateResponse(
          null, null, null, _before('2026-11-03T09:00:00Z'), null, null));
      expect(predicate.unlockTime, payday);
      expect(predicate.allows(payday.subtract(const Duration(seconds: 1))),
          isFalse);
      expect(predicate.allows(payday), isTrue);
    });

    test("the employer's predicate is the mirror image", () {
      final predicate =
          ClaimPredicate.fromResponse(_before('2026-11-03T09:00:00Z'));
      expect(predicate.unlockTime, isNull);
      expect(predicate.allows(payday.subtract(const Duration(minutes: 1))),
          isTrue);
      expect(predicate.allows(payday), isFalse);
    });

    test('accepts epoch seconds as well as ISO-8601', () {
      expect(parsePredicateTime('1793696400'), payday);
    });

    test('refuses predicates the conversion flow cannot evaluate', () {
      final relative = ClaimPredicate.fromResponse(
          ClaimantPredicateResponse(null, null, null, null, null, '3600'));
      expect(() => relative.allows(payday), throwsStateError);
    });
  });

  group('Payout', () {
    const ana = 'GANA';
    const boss = 'GBOSS';
    final payout = Payout(
      balanceId: '00000000abc',
      amount: '300.0000000',
      asset: 'USDC:GISSUER',
      claimants: [
        PayoutClaimant(ana, Not(BeforeAbsolute(payday))),
        PayoutClaimant(boss, BeforeAbsolute(payday)),
      ],
    );

    test('knows when each claimant may claim', () {
      expect(payout.assetCode, 'USDC');
      expect(payout.unlockTimeFor(ana), payday);
      expect(payout.isUnlockedFor(ana, payday), isTrue);
      expect(
          payout.isUnlockedFor(ana, payday.subtract(const Duration(seconds: 1))),
          isFalse);
    });
  });

  group('mergeClaimHistory', () {
    test('keeps local amounts and sorts newest first', () {
      final local = ClaimRecord(
        id: 'b1',
        balanceId: 'b1',
        transactionHash: 'tx1',
        claimedAt: DateTime.utc(2026, 10, 1),
        amount: '300',
        asset: 'USDC',
        source: ClaimSource.local,
      );
      final onChain = [
        ClaimRecord(
          id: 'op1',
          balanceId: 'b1',
          transactionHash: 'tx1',
          claimedAt: DateTime.utc(2026, 10, 1),
          source: ClaimSource.stellar,
        ),
        ClaimRecord(
          id: 'op2',
          balanceId: 'b2',
          transactionHash: 'tx2',
          claimedAt: DateTime.utc(2026, 11, 1),
          source: ClaimSource.stellar,
        ),
      ];
      final merged = mergeClaimHistory([local], onChain);
      expect(merged.map((r) => r.transactionHash), ['tx2', 'tx1']);
      expect(merged.last.amount, '300');
      expect(merged.last.source, ClaimSource.local);
    });

    test('round-trips through JSON', () {
      final record = ClaimRecord(
        id: 'b1',
        balanceId: 'b1',
        transactionHash: 'tx1',
        claimedAt: DateTime.utc(2026, 10, 1),
        amount: '17040',
        asset: 'PHPT',
        source: ClaimSource.local,
      );
      expect(ClaimRecord.fromJson(record.toJson()), record);
    });
  });
}

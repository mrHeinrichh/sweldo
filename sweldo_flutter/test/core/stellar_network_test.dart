import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/stellar/stellar_network.dart';

void main() {
  const hash =
      'db1108ff108a807150d02b8672d9a8c0e808bff918cdbe5c7605e63a7f565df5';
  const horizonId = '00000000$hash';
  const strkey = 'BAANWEII74IIVADRKDICXBTS3GUMB2AIX74RRTN6LR3ALZR2P5LF35OVGE';

  test('individual receipts convert Horizon XDR IDs to explorer StrKeys', () {
    expect(
      Explorer.claimableBalance(horizonId).toString(),
      'https://stellar.expert/explorer/testnet/claimable-balance/$strkey',
    );
    expect(StrKey.isValidClaimableBalanceId(strkey), isTrue);
    expect(horizonId.length, 72);
  });

  test('bare hashes, uppercase hex and StrKeys link to the same balance', () {
    for (final id in [hash, horizonId.toUpperCase(), strkey]) {
      expect(Explorer.claimableBalance(id), Explorer.claimableBalance(horizonId));
    }
  });

  test('bulk receipts preserve their transaction URL', () {
    expect(
      Explorer.transaction(hash).toString(),
      'https://stellar.expert/explorer/testnet/tx/$hash',
    );
  });

  test('invalid balance IDs cannot produce misleading links', () {
    for (final id in ['', 'invalid', '00000001$hash', hash.substring(2)]) {
      expect(() => Explorer.claimableBalance(id), throwsException);
    }
  });
}

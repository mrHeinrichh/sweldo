import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/features/wallet/domain/wallet_qr.dart';

void main() {
  const address = 'GCALNQQBXAPZ2WIRSDDBMSTAKCUH5SG6U76YBFLQLIXJTF7FE5AX7AOO';
  const uri = 'web+stellar:pay?destination=$address';

  test('wallet QR accepts only a complete checksum-valid public address', () {
    expect(parseWalletQr(address), address);
    expect(parseWalletQr(' \n$address\t '), address);
    for (final input in [
      '${address.substring(0, address.length - 1)}A',
      address.toLowerCase(),
      '$address$address',
      '$address\n$address',
    ]) {
      expect(() => parseWalletQr(input), throwsFormatException);
    }
  });

  test('SEP-7 payment QR imports one address and no payment instructions', () {
    expect(parseWalletQr(uri), address);
    expect(
      parseWalletQr('web+stellar:pay?%64estination=%47${address.substring(1)}'),
      address,
    );
    expect(
      parseWalletQr(
        '$uri&amount=999&asset_code=USDC&asset_issuer=$address&msg=Pay+me',
      ),
      address,
    );
    final callback = Uri.encodeQueryComponent(
      'url:https://example.com/${KeyPair.random().accountId}',
    );
    expect(parseWalletQr('$uri&callback=$callback'), address);
  });

  test('arbitrary URLs and look-alike schemes are rejected', () {
    for (final input in [
      'M${List.filled(68, 'A').join()}',
      'https://example.com/$address',
      'https://example.com?destination=$address',
      'stellar:$address',
      'web+stellar:tx?destination=$address',
      'web+stellar://pay?destination=$address',
      'web+stellar:PAY?destination=$address',
      'address=$address',
      'worker*',
      '*example.com',
    ]) {
      expect(
        () => parseWalletQr(input),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            walletQrInvalid,
          ),
        ),
      );
    }
  });

  test('secret keys, muxed and federation addresses say what was scanned', () {
    final secret = KeyPair.random().secretSeed;
    for (final input in [secret, 'web+stellar:pay?destination=$secret']) {
      expect(
        () => parseWalletQr(input),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', walletQrSecret)
              .having(
                (e) => e.message.contains(secret),
                'echoes secret',
                false,
              ),
        ),
      );
    }
    final muxed = MuxedAccount(address, BigInt.from(7)).accountId;
    expect(
      () => parseWalletQr(muxed),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          walletQrMuxed,
        ),
      ),
    );
    for (final input in [
      'ana*lobstr.co',
      'worker*example.com',
      'web+stellar:pay?destination=ana*lobstr.co',
    ]) {
      expect(
        () => parseWalletQr(input),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            walletQrFederation,
          ),
        ),
      );
    }
  });

  test(
    'ambiguous destinations, duplicate fields and fragments are rejected',
    () {
      for (final input in [
        '$uri&destination=$address',
        '$uri&%64estination=$address',
        '$uri&Destination=$address',
        '$uri&amount=1&amount=2',
        '$uri#ignored',
        'web+stellar:pay?Destination=$address',
        'web+stellar:pay?amount=1',
        'web+stellar:pay?destination=%20$address',
      ]) {
        expect(() => parseWalletQr(input), throwsFormatException);
      }
    },
  );

  test('memo-bearing QR requests cannot silently lose payment routing', () {
    for (final field in [
      'memo=123',
      'memo=',
      'memo_type=MEMO_ID',
      '%6Demo=123',
      'MEMO=123',
    ]) {
      expect(() => parseWalletQr('$uri&$field'), throwsFormatException);
    }
  });

  test('malformed escapes, whitespace and oversized payloads are rejected', () {
    for (final input in [
      '',
      '$uri&msg=%',
      '$uri&msg=%GG',
      '$uri&msg=%FF',
      '$uri&msg=hello world',
      '$uri&',
      '$uri&msg',
      '$uri&msg=${List.filled(8192, 'a').join()}',
    ]) {
      expect(() => parseWalletQr(input), throwsFormatException);
    }
  });
}

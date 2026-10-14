import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sweldo/features/account/data/local_test_faucet.dart';

void main() {
  const issuer = 'GASWHRKW7OTWP2YAY4IFMRLUSDIHHYOROTLPCWAKF3OC5GOOZFAHIOCB';
  const address = 'GCEQNONSUIPF674HU6PNCONFHSYFN5DVI3QU3VVA47NHVFCSNUDMAC4K';
  final hash = 'a' * 64;

  test('external faucet URLs cannot be used', () async {
    final faucet = LocalTestFaucet(
      url: 'https://untrusted.example',
      issuer: issuer,
      client: MockClient((_) async => fail('must not request a remote faucet')),
    );
    expect(await faucet.available(), false);
    await expectLater(faucet.fund(address), throwsA(isA<Exception>()));
  });

  test(
    'local capability checks do not fund; explicit funding checks issuer and receipt',
    () async {
      var posts = 0;
      final faucet = LocalTestFaucet(
        url: 'http://localhost:5174',
        issuer: issuer,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'network': 'Stellar Testnet',
                'code': 'USDC',
                'issuer': issuer,
                'amount': '25',
                'token': 'local-token',
              }),
              200,
            );
          }
          posts++;
          expect(request.headers['X-Sweldo-Test-Faucet-Token'], 'local-token');
          expect(jsonDecode(request.body), {'address': address});
          return http.Response(
            jsonEncode({
              'network': 'Stellar Testnet',
              'issuer': issuer,
              'address': address,
              'status': 'funded',
              'hash': hash,
            }),
            200,
          );
        }),
      );
      expect(await faucet.available(), true);
      expect(posts, 0);
      final receipt = await faucet.fund(address);
      expect(posts, 1);
      expect(receipt.status, 'funded');
      expect(receipt.hash, hash);
    },
  );

  test('wrong network or issuer does not enable a funding button', () async {
    for (final wrong in [
      {'network': 'Mainnet'},
      {'issuer': address},
    ]) {
      final faucet = LocalTestFaucet(
        url: 'http://localhost:5174',
        issuer: issuer,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'network': 'Stellar Testnet',
              'code': 'USDC',
              'issuer': issuer,
              'amount': '25',
              'token': 'local-token',
              ...wrong,
            }),
            200,
          ),
        ),
      );
      expect(await faucet.available(), false);
    }
  });
}

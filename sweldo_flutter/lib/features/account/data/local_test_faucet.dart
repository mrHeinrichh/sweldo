import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/error/app_exception.dart';

class TestFundingReceipt {
  const TestFundingReceipt(this.status, this.hash);
  final String status;
  final String? hash;
}

/// A debug-only client. The disposable issuer key stays in the local dev server.
class LocalTestFaucet {
  LocalTestFaucet({
    required String url,
    required this.issuer,
    http.Client? client,
  }) : _url = Uri.tryParse(url),
       _client = client ?? http.Client();

  final Uri? _url;
  final String issuer;
  final http.Client _client;
  String? _token;

  bool get enabled =>
      kDebugMode &&
      _url?.scheme == 'http' &&
      const [
        'localhost',
        '127.0.0.1',
        '::1',
        '10.0.2.2',
      ].contains(_url?.host) &&
      _url!.userInfo.isEmpty;

  Uri get _endpoint =>
      _url!.replace(path: '/__sweldo_local/test-usdc', query: '');

  Future<bool> available() async {
    if (!enabled) return false;
    try {
      final response = await _client
          .get(_endpoint)
          .timeout(const Duration(seconds: 5));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 ||
          body['network'] != 'Stellar Testnet' ||
          body['code'] != 'USDC' ||
          body['issuer'] != issuer ||
          body['amount'] != '25' ||
          body['token'] is! String) {
        return false;
      }
      _token = body['token'] as String;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TestFundingReceipt> fund(String address) async {
    if (!enabled || _token == null) {
      throw const UserFacingException(
        'The local Testnet faucet is unavailable.',
      );
    }
    final response = await _client.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        'X-Sweldo-Test-Faucet-Token': _token!,
      },
      body: jsonEncode({'address': address}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw UserFacingException(
        body['error'] as String? ?? 'Test funding was not confirmed.',
      );
    }
    final status = body['status'] as String?;
    final hash = body['hash'] as String?;
    if (!const ['funded', 'already-funded', 'pending'].contains(status) ||
        body['address'] != address ||
        body['network'] != 'Stellar Testnet' ||
        body['issuer'] != issuer ||
        (status != 'already-funded' &&
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash ?? ''))) {
      throw const UserFacingException(
        'Invalid Testnet funding receipt. Check the wallet before retrying.',
      );
    }
    return TestFundingReceipt(status!, hash);
  }
}

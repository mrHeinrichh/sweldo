import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

// The same messages as the web app's src/lib/wallet-qr.ts.
const walletQrInvalid =
    'Scan a Stellar wallet QR code containing a valid G… public address.';
const walletQrSecret =
    'This QR code is a secret key, not a wallet address. Nothing was saved. Ask the employee to show their public address (starts with G) and to keep that secret key private.';
const walletQrMuxed =
    'This is a muxed (M…) address. Payroll needs the employee’s main wallet address, which starts with G.';
const walletQrFederation =
    'This QR code shows a name*domain address. Ask the employee for the wallet address behind it: 56 characters starting with G.';

bool _isAddress(String value) =>
    RegExp(r'^G[A-Z2-7]{55}$').hasMatch(value) &&
    StrKey.isValidStellarAccountId(value);

/// Names the common wrong codes (a secret key, a muxed or federation address)
/// instead of a generic error.
Never _explain(String value) {
  if (RegExp(r'^S[A-Z2-7]{55}$').hasMatch(value) &&
      StrKey.isValidStellarSecretSeed(value)) {
    throw const FormatException(walletQrSecret);
  }
  if (RegExp(r'^M[A-Z2-7]{68}$').hasMatch(value) &&
      StrKey.isValidStellarMuxedAccountId(value)) {
    throw const FormatException(walletQrMuxed);
  }
  if (RegExp(
    r'^[^*\s]+\*[a-z0-9-]+(\.[a-z0-9-]+)+$',
    caseSensitive: false,
  ).hasMatch(value)) {
    throw const FormatException(walletQrFederation);
  }
  throw const FormatException(walletQrInvalid);
}

/// Reads an address only; payment amounts, assets and URLs are never acted on.
String parseWalletQr(String raw) {
  final text = raw.trim();
  if (text.isEmpty || text.length > 8192 || RegExp(r'\s').hasMatch(text)) {
    throw const FormatException(walletQrInvalid);
  }
  if (_isAddress(text)) return text;
  const prefix = 'web+stellar:pay?';
  if (!text.startsWith(prefix)) _explain(text);
  if (text.contains('#')) throw const FormatException(walletQrInvalid);

  final parameters = <String, String>{};
  for (final pair in text.substring(prefix.length).split('&')) {
    final equals = pair.indexOf('=');
    if (equals < 1) throw const FormatException(walletQrInvalid);
    late String key;
    late String value;
    try {
      key = Uri.decodeQueryComponent(pair.substring(0, equals));
      value = Uri.decodeQueryComponent(pair.substring(equals + 1));
    } catch (_) {
      throw const FormatException(walletQrInvalid);
    }
    final normalized = key.toLowerCase();
    if (parameters.containsKey(normalized)) {
      throw const FormatException(
        'This QR code has duplicate fields. Use a QR code with one wallet address.',
      );
    }
    if (normalized == 'memo' || normalized == 'memo_type') {
      throw const FormatException(
        'This QR code requires a memo. Payroll only supports wallet addresses without a memo.',
      );
    }
    if (normalized == 'destination' && key != 'destination') {
      throw const FormatException(walletQrInvalid);
    }
    parameters[normalized] = value;
  }
  final address = parameters['destination'] ?? '';
  if (!_isAddress(address)) _explain(address);
  return address;
}

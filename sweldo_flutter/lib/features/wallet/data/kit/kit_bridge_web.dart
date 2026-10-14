import 'dart:convert';
import 'dart:js_interop';

import '../../../../core/error/app_exception.dart';
import 'kit_bridge.dart';

@JS('SweldoWallets.call')
external JSPromise<JSString> _call(JSString payload);

KitBridge createBridge() => _BrowserBridge();

class _BrowserBridge implements KitBridge {
  int _version = 0;
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request) async {
    final version = _version;
    final result = await _call(jsonEncode(request).toJS).toDart;
    if (_version != version) {
      throw const WalletException('Wallet request cancelled.');
    }
    return jsonDecode(result.toDart) as Map<String, dynamic>;
  }

  @override
  void cancel() {
    _version++;
  }
}

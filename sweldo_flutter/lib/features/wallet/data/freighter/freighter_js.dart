// Bindings for `window.freighterApi` (@stellar/freighter-api 6.x), loaded by
// web/index.html. Web-only: imported through a conditional export.
import 'dart:js_interop';

@JS('freighterApi')
external FreighterApi? get freighterApi;

extension type FreighterApi._(JSObject _) implements JSObject {
  external JSPromise<FreighterResult> isConnected();
  external JSPromise<FreighterResult> isAllowed();
  external JSPromise<FreighterResult> setAllowed();
  external JSPromise<FreighterResult> requestAccess();
  external JSPromise<FreighterResult> getAddress();
  external JSPromise<FreighterResult> getNetwork();
  external JSPromise<FreighterResult> signTransaction(
    String xdr,
    FreighterSignOptions options,
  );
}

/// Every Freighter call resolves to an object that carries either its payload
/// or an `error`.
extension type FreighterResult._(JSObject _) implements JSObject {
  external FreighterError? get error;
  external bool? get isConnected;
  external bool? get isAllowed;
  external String? get address;
  external String? get network;
  external String? get networkPassphrase;
  external String? get signedTxXdr;
  external String? get signerAddress;
}

extension type FreighterError._(JSObject _) implements JSObject {
  external JSAny? get code;
  external String? get message;
  external JSArray<JSString>? get ext;
}

extension type FreighterSignOptions._(JSObject _) implements JSObject {
  external factory FreighterSignOptions({
    required String networkPassphrase,
    required String address,
  });
}

extension FreighterErrorText on FreighterError {
  String describe() {
    final text = message;
    if (text != null && text.isNotEmpty) return text;
    final details = ext?.toDart.map((e) => e.toDart).join(', ');
    if (details != null && details.isNotEmpty) return details;
    return 'error ${code?.dartify() ?? 'unknown'}';
  }
}

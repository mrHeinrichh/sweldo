import 'kit_bridge_stub.dart'
    if (dart.library.js_interop) 'kit_bridge_web.dart'
    if (dart.library.io) 'kit_bridge_native.dart'
    as platform;

abstract class KitBridge {
  bool get available;
  Future<Map<String, dynamic>> call(Map<String, dynamic> request);
  void cancel();
}

KitBridge createKitBridge() => platform.createBridge();

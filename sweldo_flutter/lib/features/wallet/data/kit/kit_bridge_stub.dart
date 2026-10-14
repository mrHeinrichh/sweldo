import '../../../../core/error/app_exception.dart';
import 'kit_bridge.dart';

KitBridge createBridge() => _UnavailableBridge();

class _UnavailableBridge implements KitBridge {
  @override
  bool get available => false;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request) =>
      Future.error(const WalletException('Use a supported browser or phone.'));
  @override
  void cancel() {}
}

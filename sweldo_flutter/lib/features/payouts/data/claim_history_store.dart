import '../../../core/storage/local_store.dart';
import '../domain/claim_record.dart';

/// Claims made on this device, which remember the amount and asset that
/// Horizon's claim operation doesn't carry.
class ClaimHistoryStore {
  ClaimHistoryStore(this._store);

  static const _prefix = 'sweldo-claim-history-v1';

  final LocalStore _store;

  String _key(String address) => '$_prefix:$address';

  List<ClaimRecord> read(String address) =>
      _store.readList(_key(address)).map(ClaimRecord.fromJson).toList();

  Future<void> save(String address, ClaimRecord claim) async {
    final next = mergeClaimHistory([claim, ...read(address)], const []);
    await _store.writeList(
      _key(address),
      next.take(50).map((r) => r.toJson()).toList(),
    );
  }
}

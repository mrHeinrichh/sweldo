import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/error_messages.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_session.dart';
import '../data/account_repository.dart';
import '../data/local_test_faucet.dart';

class AccountSetupState extends Equatable {
  const AccountSetupState({
    this.address,
    this.needsFunding = false,
    this.needsTrustline = false,
    this.funding = false,
    this.enabling = false,
    this.error,
    this.balances,
    this.faucetAvailable = false,
    this.fundingAsset = false,
    this.fundingReceipt,
    this.assetId = 'native',
  });

  final String? address;
  final String assetId;

  /// What the wallet holds, for the payroll coverage check.
  final WalletBalances? balances;

  /// The wallet doesn't exist on Testnet yet.
  final bool needsFunding;

  /// The payroll asset is issued and this wallet can't hold it yet.
  final bool needsTrustline;
  final bool funding;
  final bool enabling;
  final String? error;
  final bool faucetAvailable;
  final bool fundingAsset;
  final TestFundingReceipt? fundingReceipt;

  AccountSetupState copyWith({
    bool? needsFunding,
    bool? needsTrustline,
    bool? funding,
    bool? enabling,
    String? Function()? error,
    WalletBalances? Function()? balances,
    bool? faucetAvailable,
    bool? fundingAsset,
    TestFundingReceipt? fundingReceipt,
  }) => AccountSetupState(
    address: address,
    assetId: assetId,
    needsFunding: needsFunding ?? this.needsFunding,
    needsTrustline: needsTrustline ?? this.needsTrustline,
    funding: funding ?? this.funding,
    enabling: enabling ?? this.enabling,
    error: error != null ? error() : this.error,
    balances: balances != null ? balances() : this.balances,
    faucetAvailable: faucetAvailable ?? this.faucetAvailable,
    fundingAsset: fundingAsset ?? this.fundingAsset,
    fundingReceipt: fundingReceipt ?? this.fundingReceipt,
  );

  @override
  List<Object?> get props => [
    address,
    assetId,
    needsFunding,
    needsTrustline,
    funding,
    enabling,
    error,
    balances?.xlm,
    balances?.asset,
    faucetAvailable,
    fundingAsset,
    fundingReceipt,
  ];
}

/// Drives the "Get free test XLM" and "Enable USDC" prompts.
class AccountSetupCubit extends Cubit<AccountSetupState> {
  AccountSetupCubit({
    required AccountRepository repository,
    required WalletRepository wallet,
    required Asset payrollAsset,
  }) : _repository = repository,
       _wallet = wallet,
       _asset = payrollAsset,
       super(const AccountSetupState()) {
    _subscription = wallet.sessions.listen(_check);
    _check(wallet.session);
  }

  final AccountRepository _repository;
  final WalletRepository _wallet;
  Asset _asset;
  int _revision = 0;
  bool _busy = false;
  late final StreamSubscription<WalletSession?> _subscription;

  String get assetCode => _asset is AssetTypeCreditAlphaNum
      ? (_asset as AssetTypeCreditAlphaNum).code
      : 'XLM';

  bool selectAsset(Asset asset) {
    if (_busy) return false;
    if (Asset.canonicalForm(asset) == Asset.canonicalForm(_asset)) return true;
    _asset = asset;
    unawaited(_check(_wallet.session));
    return true;
  }

  bool _matches(String address, int revision) =>
      !isClosed && state.address == address && _revision == revision;

  Future<void> _check(WalletSession? session) async {
    final revision = ++_revision;
    final asset = _asset;
    final assetId = Asset.canonicalForm(asset);
    if (session == null || !session.onTestnet) {
      emit(AccountSetupState(assetId: assetId));
      return;
    }
    final address = session.address;
    emit(AccountSetupState(address: address, assetId: assetId));
    unawaited(_checkFaucet(address, asset, revision));
    try {
      final funded = await _repository.isFunded(address);
      if (!_matches(address, revision)) return;
      emit(state.copyWith(needsFunding: !funded));
      await _loadBalances(address, asset, revision);
      if (asset is AssetTypeNative) return;
      final trusted = await _repository.hasTrustline(address, asset);
      if (!_matches(address, revision)) return;
      emit(state.copyWith(needsTrustline: !trusted));
    } catch (_) {
      // A failed lookup must not block the page.
    }
  }

  Future<void> _checkFaucet(String address, Asset asset, int revision) async {
    if (asset is! AssetTypeCreditAlphaNum || asset.code != 'USDC') return;
    final available = await _repository.testFaucet?.available() ?? false;
    if (_matches(address, revision)) {
      emit(state.copyWith(faucetAvailable: available));
    }
  }

  Future<void> refresh() async {
    final address = state.address;
    if (address == null) return;
    final asset = _asset;
    final revision = _revision;
    try {
      final funded = await _repository.isFunded(address);
      final trusted =
          asset is AssetTypeNative ||
          await _repository.hasTrustline(address, asset);
      if (_matches(address, revision)) {
        emit(state.copyWith(needsFunding: !funded, needsTrustline: !trusted));
      }
      await _loadBalances(address, asset, revision);
    } catch (_) {}
  }

  Future<void> _loadBalances(String address, Asset asset, int revision) async {
    try {
      final balances = await _repository.balances(address, asset);
      if (_matches(address, revision)) {
        emit(state.copyWith(balances: () => balances));
      }
    } catch (_) {
      // Coverage is a hint; a failed read just hides it.
    }
  }

  Future<void> fund() async {
    final address = state.address;
    if (address == null || _busy) return;
    final revision = _revision;
    _busy = true;
    emit(state.copyWith(funding: true, error: () => null));
    try {
      await _repository.fundWithFriendbot(address);
      final funded = await _repository.isFunded(address);
      if (!_matches(address, revision)) return;
      emit(state.copyWith(needsFunding: !funded));
      if (funded) await refresh();
    } catch (error) {
      if (_matches(address, revision)) {
        emit(state.copyWith(error: () => friendlyError(error)));
      }
    } finally {
      _busy = false;
      if (_matches(address, revision)) emit(state.copyWith(funding: false));
    }
  }

  Future<void> enableAsset() async {
    final address = state.address;
    if (address == null || _asset is AssetTypeNative || _busy) return;
    final asset = _asset;
    final revision = _revision;
    _busy = true;
    emit(state.copyWith(enabling: true, error: () => null));
    try {
      await _repository.addTrustline(address, asset);
      final trusted = await _repository.hasTrustline(address, asset);
      if (!_matches(address, revision)) return;
      emit(state.copyWith(needsTrustline: !trusted));
      await _loadBalances(address, asset, revision);
    } catch (error) {
      if (_matches(address, revision)) {
        emit(state.copyWith(error: () => friendlyError(error)));
      }
    } finally {
      _busy = false;
      if (_matches(address, revision)) emit(state.copyWith(enabling: false));
    }
  }

  Future<void> fundAsset() async {
    final address = state.address;
    final faucet = _repository.testFaucet;
    if (address == null ||
        _asset is AssetTypeNative ||
        faucet == null ||
        _busy ||
        state.fundingReceipt?.status == 'pending') {
      return;
    }
    final revision = _revision;
    final asset = _asset;
    _busy = true;
    emit(state.copyWith(fundingAsset: true, error: () => null));
    try {
      final receipt = await faucet.fund(address);
      if (!_matches(address, revision)) return;
      emit(state.copyWith(fundingReceipt: receipt));
      await _loadBalances(address, asset, revision);
    } catch (error) {
      if (_matches(address, revision)) {
        emit(state.copyWith(error: () => friendlyError(error)));
      }
    } finally {
      _busy = false;
      if (_matches(address, revision)) {
        emit(state.copyWith(fundingAsset: false));
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

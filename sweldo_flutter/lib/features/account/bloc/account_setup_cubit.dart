import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

import '../../../core/error/error_messages.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../wallet/domain/wallet_session.dart';
import '../data/account_repository.dart';

class AccountSetupState extends Equatable {
  const AccountSetupState({
    this.address,
    this.needsFunding = false,
    this.needsTrustline = false,
    this.funding = false,
    this.enabling = false,
    this.error,
    this.balances,
  });

  final String? address;

  /// What the wallet holds, for the payroll coverage check.
  final WalletBalances? balances;

  /// The wallet doesn't exist on Testnet yet.
  final bool needsFunding;

  /// The payroll asset is issued and this wallet can't hold it yet.
  final bool needsTrustline;
  final bool funding;
  final bool enabling;
  final String? error;

  AccountSetupState copyWith({
    bool? needsFunding,
    bool? needsTrustline,
    bool? funding,
    bool? enabling,
    String? Function()? error,
    WalletBalances? Function()? balances,
  }) => AccountSetupState(
    address: address,
    needsFunding: needsFunding ?? this.needsFunding,
    needsTrustline: needsTrustline ?? this.needsTrustline,
    funding: funding ?? this.funding,
    enabling: enabling ?? this.enabling,
    error: error != null ? error() : this.error,
    balances: balances != null ? balances() : this.balances,
  );

  @override
  List<Object?> get props => [
    address,
    needsFunding,
    needsTrustline,
    funding,
    enabling,
    error,
    balances?.xlm,
    balances?.asset,
  ];
}

/// Drives the "Get free test XLM" and "Enable USDC" prompts.
class AccountSetupCubit extends Cubit<AccountSetupState> {
  AccountSetupCubit({
    required AccountRepository repository,
    required WalletRepository wallet,
    required Asset payrollAsset,
  }) : _repository = repository,
       _asset = payrollAsset,
       super(const AccountSetupState()) {
    _subscription = wallet.sessions.listen(_check);
    _check(wallet.session);
  }

  final AccountRepository _repository;
  final Asset _asset;
  late final StreamSubscription<WalletSession?> _subscription;

  String get assetCode =>
      _asset is AssetTypeCreditAlphaNum ? (_asset).code : 'XLM';

  Future<void> _check(WalletSession? session) async {
    if (session == null || !session.onTestnet) {
      emit(const AccountSetupState());
      return;
    }
    final address = session.address;
    emit(AccountSetupState(address: address));
    try {
      final funded = await _repository.isFunded(address);
      if (isClosed || state.address != address) return;
      emit(state.copyWith(needsFunding: !funded));
      await _loadBalances(address);
      if (_asset is AssetTypeNative) return;
      final trusted = await _repository.hasTrustline(address, _asset);
      if (isClosed || state.address != address) return;
      emit(state.copyWith(needsTrustline: !trusted));
    } catch (_) {
      // A failed lookup must not block the page.
    }
  }

  Future<void> refresh() async {
    final address = state.address;
    if (address == null) return;
    try {
      final funded = await _repository.isFunded(address);
      final trusted =
          _asset is AssetTypeNative ||
          await _repository.hasTrustline(address, _asset);
      if (!isClosed && state.address == address) {
        emit(state.copyWith(needsFunding: !funded, needsTrustline: !trusted));
      }
      await _loadBalances(address);
    } catch (_) {}
  }

  Future<void> _loadBalances(String address) async {
    try {
      final balances = await _repository.balances(address, _asset);
      if (!isClosed && state.address == address) {
        emit(state.copyWith(balances: () => balances));
      }
    } catch (_) {
      // Coverage is a hint; a failed read just hides it.
    }
  }

  Future<void> fund() async {
    final address = state.address;
    if (address == null || state.funding) return;
    emit(state.copyWith(funding: true, error: () => null));
    try {
      await _repository.fundWithFriendbot(address);
      final funded = await _repository.isFunded(address);
      emit(state.copyWith(funding: false, needsFunding: !funded));
      if (funded) await refresh();
    } catch (error) {
      emit(state.copyWith(funding: false, error: () => friendlyError(error)));
    }
  }

  Future<void> enableAsset() async {
    final address = state.address;
    if (address == null || state.enabling) return;
    emit(state.copyWith(enabling: true, error: () => null));
    try {
      await _repository.addTrustline(address, _asset);
      final trusted = await _repository.hasTrustline(address, _asset);
      emit(state.copyWith(enabling: false, needsTrustline: !trusted));
    } catch (error) {
      emit(state.copyWith(enabling: false, error: () => friendlyError(error)));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

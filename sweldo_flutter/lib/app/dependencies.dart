import '../core/config/app_config.dart';
import '../core/storage/local_store.dart';
import '../core/stellar/horizon_client.dart';
import '../core/stellar/transaction_signer.dart';
import '../features/account/data/account_repository.dart';
import '../features/conversion/data/conversion_repository.dart';
import '../features/payouts/data/claim_history_store.dart';
import '../features/payouts/data/payouts_repository.dart';
import '../features/payroll/data/payroll_repository.dart';
import '../features/payroll/data/registry_repository.dart';
import '../features/payroll/data/schedule_store.dart';
import '../features/wallet/data/freighter/freighter_extension_connector.dart';
import '../features/wallet/data/walletconnect/freighter_mobile_connector.dart';
import '../features/wallet/data/wallet_repository.dart';

/// Every long-lived object, built once at startup and handed to the widget
/// tree through `RepositoryProvider`s.
class AppDependencies {
  AppDependencies._({
    required this.config,
    required this.horizon,
    required this.wallet,
    required this.account,
    required this.payroll,
    required this.registry,
    required this.schedules,
    required this.payouts,
    required this.claimHistory,
    required this.conversion,
    required this.store,
  });

  factory AppDependencies.create(AppConfig config, LocalStore store) {
    final horizon = HorizonClient();
    final wallet = WalletRepository(
      store: store,
      connectors: [
        FreighterExtensionConnector(),
        FreighterMobileConnector(projectId: config.walletConnectProjectId),
      ],
    );
    final submitter = TransactionSubmitter(horizon, wallet);
    return AppDependencies._(
      config: config,
      horizon: horizon,
      wallet: wallet,
      account: AccountRepository(horizon, submitter),
      payroll: PayrollRepository(horizon, submitter),
      registry: RegistryRepository(
        contractId: config.registryContractId,
        horizon: horizon,
        submitter: submitter,
      ),
      schedules: ScheduleStore(store),
      payouts: PayoutsRepository(horizon, submitter),
      claimHistory: ClaimHistoryStore(store),
      conversion: ConversionRepository(horizon, wallet),
      store: store,
    );
  }

  final AppConfig config;
  final HorizonClient horizon;
  final WalletRepository wallet;
  final AccountRepository account;
  final PayrollRepository payroll;
  final RegistryRepository registry;
  final ScheduleStore schedules;
  final PayoutsRepository payouts;
  final ClaimHistoryStore claimHistory;
  final ConversionRepository conversion;
  final LocalStore store;
}

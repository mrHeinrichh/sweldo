import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';

/// Sweldo runs on Stellar Testnet only.
abstract final class StellarNetwork {
  static const horizonUrl = 'https://horizon-testnet.stellar.org';
  static const sorobanRpcUrl = 'https://soroban-testnet.stellar.org';
  static const friendbotUrl = 'https://friendbot.stellar.org';
  static final Network network = Network.TESTNET;
  static String get passphrase => network.networkPassphrase;

  /// Freighter reports the active network by name.
  static const walletNetworkName = 'TESTNET';

  /// WalletConnect CAIP-2 chain id.
  static const walletConnectChain = 'stellar:testnet';

  /// Stellar caps a transaction at 100 operations.
  static const maxOperationsPerTransaction = 100;
  static const maxPayoutsPerEmployee = 50;
  static const transactionTimeout = Duration(seconds: 180);
}

/// Links to the public Testnet explorer, so every action can be verified.
abstract final class Explorer {
  static const _base = 'https://stellar.expert/explorer/testnet';
  static const home = _base;

  static Uri transaction(String hash) => Uri.parse('$_base/tx/$hash');
  static Uri claimableBalance(String id) =>
      Uri.parse('$_base/claimable-balance/$id');
  static Uri contract(String id) => Uri.parse('$_base/contract/$id');
  static Uri account(String id) => Uri.parse('$_base/account/$id');
}

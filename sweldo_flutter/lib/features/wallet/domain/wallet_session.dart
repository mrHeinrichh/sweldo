import 'package:equatable/equatable.dart';

import '../../../core/stellar/stellar_network.dart';

/// Ways to reach Freighter.
enum WalletKind {
  /// The Freighter browser extension (Flutter web).
  freighterExtension(
    'Freighter extension',
    'Sign in this browser with the Freighter extension.',
  ),

  /// The Freighter app for iOS and Android, paired through WalletConnect.
  freighterMobile(
    'Freighter app',
    'Approve each payroll action in Freighter on your phone.',
  );

  const WalletKind(this.title, this.description);

  final String title;
  final String description;
}

class WalletSession extends Equatable {
  const WalletSession({
    required this.address,
    required this.network,
    required this.kind,
  });

  final String address;

  /// Freighter's network name, e.g. `TESTNET` or `PUBLIC`.
  final String network;
  final WalletKind kind;

  bool get onTestnet => network == StellarNetwork.walletNetworkName;

  @override
  List<Object?> get props => [address, network, kind];
}

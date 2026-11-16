import 'package:equatable/equatable.dart';

import '../../../core/stellar/stellar_network.dart';

/// Supported wallet transports.
enum WalletKind {
  /// The Varial browser extension (Flutter web).
  freighterExtension(
    'Varial extension',
    'Sign in this browser with the Varial extension.',
  ),

  /// The Varial app for iOS and Android, paired through WalletConnect.
  freighterMobile(
    'Varial app',
    'Approve each payroll action in Varial on your phone.',
  ),
  xbull('xBull', 'Connect and approve Testnet transactions with xBull.');

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

  /// Reported network, or the explicitly requested Testnet for xBull.
  final String network;
  final WalletKind kind;

  bool get onTestnet => network == StellarNetwork.walletNetworkName;

  @override
  List<Object?> get props => [address, network, kind];
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/stellar/transaction_activity.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/layout.dart';
import '../../core/widgets/operation_progress.dart';
import '../../features/wallet/bloc/wallet_bloc.dart';

class WalletActivityBanner extends StatefulWidget {
  const WalletActivityBanner({super.key});

  @override
  State<WalletActivityBanner> createState() => _WalletActivityBannerState();
}

class _WalletActivityBannerState extends State<WalletActivityBanner>
    with WidgetsBindingObserver {
  bool _away = false;
  bool _returned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _away = true;
    }
    if (state == AppLifecycleState.resumed && _away) {
      _away = false;
      markTransactionWalletReturn();
      if (mounted) setState(() => _returned = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletBloc>().state;
    return ValueListenableBuilder<TransactionActivity?>(
      valueListenable: transactionActivity,
      builder: (context, activity, _) {
        Widget? progress;
        if (activity != null) {
          progress = TransactionActivityView(activity: activity);
        } else if (wallet.status == WalletStatus.restoring ||
            wallet.status == WalletStatus.connecting) {
          final restoring = wallet.status == WalletStatus.restoring;
          progress = OperationProgress(
            key: ValueKey(wallet.status),
            title: restoring
                ? 'Reconnecting your wallet'
                : 'Connecting your wallet',
            message: restoring
                ? 'Checking your previous wallet session. You can reconnect if it has expired.'
                : _returned
                ? 'You’re back. Receiving your wallet’s connection approval…'
                : wallet.pairingUri != null
                ? 'Connection link ready. Approve the request in Varial, then return here.'
                : 'Opening a secure wallet connection. Check your wallet for the request.',
            steps: const ['Connection request', 'Wallet approval', 'Connected'],
            currentStep: wallet.pairingUri == null ? 0 : 1,
            slowMessage: 'If the request is still pending, open your wallet to approve it. You can cancel and reconnect from the wallet picker.',
          );
        }
        if (progress == null) {
          _returned = false;
          return const SizedBox.shrink();
        }
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.36,
          ),
          child: SingleChildScrollView(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: SwSpace.sm),
                child: progress,
              ),
            ),
          ),
        );
      },
    );
  }
}

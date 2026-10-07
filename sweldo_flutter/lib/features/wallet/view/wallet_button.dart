import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stellar/stellar_network.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/external_link.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sw_button.dart';
import '../bloc/wallet_bloc.dart';
import 'connect_wallet_sheet.dart';
import '../../../core/theme/sw_icons.dart';

enum _WalletAction { copy, explorer, disconnect }

/// Connect / connected-account control in the top bar. Morphs between its
/// two states so the change reads as the same control updating.
class WalletButton extends StatelessWidget {
  const WalletButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WalletBloc>().state;
    final session = state.session;
    final compact = !isWide(context);

    final Widget child;
    if (session == null) {
      child = SwButton(
        key: const ValueKey('connect'),
        label: state.status == WalletStatus.restoring
            ? 'Checking…'
            : compact
            ? 'Connect'
            : 'Connect wallet',
        icon: SwIcons.wallet,
        tone: SwButtonTone.secondary,
        loading: state.isBusy,
        onPressed: () => showConnectWalletSheet(context),
      );
    } else {
      child = PopupMenuButton<_WalletAction>(
        key: ValueKey(session.address),
        tooltip: 'Wallet options',
        position: PopupMenuPosition.under,
        color: SwColors.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(SwRadius.panel),
          side: BorderSide(color: SwColors.rule),
        ),
        onSelected: (action) => _onAction(context, action, session.address),
        itemBuilder: (_) => [
          _item(_WalletAction.copy, SwIcons.copy, 'Copy address'),
          _item(
            _WalletAction.explorer,
            SwIcons.external,
            'View on Stellar Expert',
          ),
          _item(_WalletAction.disconnect, SwIcons.logout, 'Disconnect'),
        ],
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(SwRadius.field),
            border: Border.all(
              color: session.onTestnet ? SwColors.rule : SwColors.caution,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: session.onTestnet ? SwColors.payday : SwColors.caution,
                ),
              ),
              const SizedBox(width: SwSpace.sm),
              Text(
                shortKey(session.address, 4),
                style: SwType.mono.copyWith(
                  color: SwColors.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                SwIcons.chevronDown,
                size: 18,
                color: SwColors.inkMuted,
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: SwMotion.of(context, SwMotion.standard),
      curve: SwMotion.enter,
      child: AnimatedSwitcher(
        duration: SwMotion.of(context, SwMotion.standard),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }

  PopupMenuItem<_WalletAction> _item(
    _WalletAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: SwColors.inkMuted),
        const SizedBox(width: SwSpace.md),
        Text(label, style: SwType.label),
      ],
    ),
  );

  Future<void> _onAction(
    BuildContext context,
    _WalletAction action,
    String address,
  ) async {
    switch (action) {
      case _WalletAction.copy:
        await Clipboard.setData(ClipboardData(text: address));
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Address copied.')));
        }
      case _WalletAction.explorer:
        await openExternal(Explorer.account(address));
      case _WalletAction.disconnect:
        if (context.mounted) {
          context.read<WalletBloc>().add(const WalletDisconnectRequested());
        }
    }
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/widgets/key_text.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/sw_button.dart';
import '../../../../core/theme/sw_icons.dart';

/// Connected wallet, total still to come, and a manual refresh.
class WalletOverview extends StatelessWidget {
  const WalletOverview({
    super.key,
    required this.address,
    required this.totalUnits,
    required this.assetLabel,
    required this.activeCount,
    required this.loading,
    required this.onRefresh,
  });

  final String address;
  final BigInt totalUnits;
  final String assetLabel;
  final int activeCount;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final wallet = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connected wallet', style: SwType.caption),
        KeyText(
          address,
          edge: 8,
          style: SwType.mono.copyWith(color: SwColors.ink, fontSize: 14),
        ),
      ],
    );
    final total = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Locked and claimable', style: SwType.caption),
        const SizedBox(height: 2),
        TweenAnimationBuilder<double>(
          tween: Tween(end: double.parse(Amount.string(totalUnits))),
          duration: SwMotion.of(context, SwMotion.deliberate),
          curve: SwMotion.enter,
          builder: (context, value, _) => Text.rich(
            TextSpan(
              children: [
                TextSpan(text: Amount.format(value), style: SwType.amountLarge),
                TextSpan(
                  text: ' $assetLabel',
                  style: SwType.label.copyWith(color: SwColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final count = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payouts ahead', style: SwType.caption),
        const SizedBox(height: 2),
        Text('$activeCount', style: SwType.amountLarge),
      ],
    );
    final refresh = SwIconButton(
      icon: SwIcons.refresh,
      tooltip: 'Read the ledger again',
      loading: loading,
      onPressed: onRefresh,
      size: 44,
    );

    return Panel(
      child: wide
          ? Row(
              children: [
                Expanded(flex: 4, child: wallet),
                Expanded(flex: 4, child: total),
                Expanded(flex: 2, child: count),
                refresh,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: wallet),
                    refresh,
                  ],
                ),
                const Divider(height: SwSpace.xl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: total),
                    count,
                  ],
                ),
              ],
            ),
    );
  }
}

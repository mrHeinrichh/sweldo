import 'package:flutter/material.dart';

import '../../../../core/motion/effects.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/external_link.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/punch_card.dart';
import '../../../../core/widgets/sw_button.dart';
import '../../domain/payout.dart';

/// One payout on the employee's pay schedule. Its state follows the clock:
/// locked with a countdown, then ready to claim — and once claimed, the row
/// turns over like a split-flap board to show its stamped receipt.
class PayoutRow extends StatelessWidget {
  const PayoutRow({
    super.key,
    required this.payout,
    required this.address,
    required this.onClaim,
    required this.claiming,
    required this.disabled,
    this.onConvert,
    this.claimedHash,
  });

  final Payout payout;
  final String address;
  final VoidCallback onClaim;
  final VoidCallback? onConvert;
  final bool claiming;
  final bool disabled;
  final String? claimedHash;

  @override
  Widget build(BuildContext context) {
    final claimed = claimedHash != null;
    return FlipCard(
      vertical: true,
      flipped: claimed,
      front: SecondTicker(builder: (context, now) => _front(context, now)),
      back: _back(context),
    );
  }

  Widget _front(BuildContext context, DateTime now) {
    final unlockAt = payout.unlockTimeFor(address);
    final unlocked = unlockAt == null || !now.isBefore(unlockAt);
    final wide = context.up(Breakpoint.sm);

    final String when;
    if (unlockAt == null) {
      when = 'Claimable any time';
    } else if (unlocked) {
      when = 'Unlocked ${formatDateTime(unlockAt)}';
    } else {
      when = 'Unlocks ${formatDateTime(unlockAt)}';
    }

    final Widget action;
    if (unlocked) {
      action = Wrap(
        key: const ValueKey('ready'),
        spacing: SwSpace.sm,
        runSpacing: SwSpace.sm,
        alignment: WrapAlignment.end,
        children: [
          if (onConvert != null)
            SwButton(
              label: 'Claim as PHPT',
              icon: SwIcons.convert,
              onPressed: disabled ? null : onConvert,
            ),
          SwButton(
            label: onConvert != null ? 'Claim USDC only' : 'Claim',
            icon: onConvert != null ? null : SwIcons.claim,
            tone: onConvert != null
                ? SwButtonTone.secondary
                : SwButtonTone.payday,
            loading: claiming,
            onPressed: disabled ? null : onClaim,
          ),
        ],
      );
    } else {
      final left = countdownLabel(unlockAt.difference(now));
      action = Container(
        key: const ValueKey('locked'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: SwColors.rule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(SwIcons.hourglass, size: 14, color: SwColors.locked),
            const SizedBox(width: 6),
            Text(
              left,
              style: SwType.figures.copyWith(color: SwColors.locked),
              semanticsLabel: 'Unlocks in $left',
            ),
          ],
        ),
      );
    }

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${Amount.format(payout.amount)} ${payout.assetCode}',
          style: SwType.amount.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (unlocked)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: PingDot(),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(SwIcons.locked, size: 13, color: SwColors.locked),
              ),
            Flexible(child: Text(when, style: SwType.caption)),
          ],
        ),
        ExternalLink(
          label: 'View on-chain',
          uri: Explorer.claimableBalance(payout.balanceId),
          color: SwColors.inkMuted,
          style: SwType.caption.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );

    final switcher = AnimatedSwitcher(
      duration: SwMotion.of(context, SwMotion.standard),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.85, end: 1.0).animate(animation),
          alignment: Alignment.centerRight,
          child: child,
        ),
      ),
      child: action,
    );

    final slot = PunchSlot(
      state: unlocked ? PunchState.ready : PunchState.locked,
    );
    return Semantics(
      container: true,
      label: unlocked ? 'Payout ready to claim' : 'Locked payout',
      child: Padding(
        padding: const EdgeInsets.all(SwSpace.lg),
        child: wide
            ? Row(
                children: [
                  slot,
                  const SizedBox(width: SwSpace.lg),
                  Expanded(child: details),
                  const SizedBox(width: SwSpace.md),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: switcher,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 4), child: slot),
                  const SizedBox(width: SwSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        const SizedBox(height: SwSpace.md),
                        Align(alignment: Alignment.centerLeft, child: switcher),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// The receipt side: punched slot, stamp, and the transaction.
  Widget _back(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Claimed payout',
      child: Container(
        color: SwColors.stampWash,
        padding: const EdgeInsets.all(SwSpace.lg),
        child: Row(
          children: [
            const PunchSlot(state: PunchState.punched),
            const SizedBox(width: SwSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${Amount.format(payout.amount)} ${payout.assetCode} is in your wallet',
                    style: SwType.subtitle,
                  ),
                  const SizedBox(height: 2),
                  if (claimedHash != null)
                    ExternalLink(
                      label: 'View transaction',
                      uri: Explorer.transaction(claimedHash!),
                      style: SwType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: SwSpace.md),
            const ClaimedStamp(animate: true),
          ],
        ),
      ),
    );
  }
}

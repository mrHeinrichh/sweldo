import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/external_link.dart';
import '../../../../core/widgets/layout.dart';
import '../../domain/claim_record.dart';
import '../../../../core/theme/sw_icons.dart';

/// Completed claims for this wallet, each with its transaction proof.
class ClaimHistoryList extends StatelessWidget {
  const ClaimHistoryList({
    super.key,
    required this.history,
    required this.assetLabel,
    this.freshKey,
  });

  final List<ClaimRecord> history;
  final String assetLabel;
  final String? freshKey;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(
            title: 'Claim history',
            description: 'Completed claims for this wallet.',
            trailing: Text('${history.length} claimed', style: SwType.caption),
          ),
          const SizedBox(height: SwSpace.lg),
          if (history.isEmpty)
            Text(
              'No claims yet. Each payout you claim appears here with its '
              'transaction proof.',
              style: SwType.bodySmall,
            )
          else
            AnimatedSize(
              duration: SwMotion.of(context, SwMotion.standard),
              curve: SwMotion.enter,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  for (var i = 0; i < history.length; i++) ...[
                    if (i > 0) const Divider(height: SwSpace.lg),
                    _HistoryRow(
                      key: ValueKey(history[i].proofKey),
                      record: history[i],
                      assetLabel: assetLabel,
                      fresh: history[i].proofKey == freshKey,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    super.key,
    required this.record,
    required this.assetLabel,
    required this.fresh,
  });

  final ClaimRecord record;
  final String assetLabel;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: SwColors.paydayWash,
            shape: BoxShape.circle,
          ),
          child: const Icon(SwIcons.check, size: 16, color: SwColors.payday),
        ),
        const SizedBox(width: SwSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.amount != null
                    ? '${Amount.format(record.amount)} ${record.asset ?? assetLabel}'
                    : 'Payroll payout claimed',
                style: SwType.figures.copyWith(fontSize: 16),
              ),
              Text(formatDateTime(record.claimedAt), style: SwType.caption),
              if (record.balanceId.isNotEmpty)
                Text(
                  shortKey(record.balanceId, 8),
                  style: SwType.mono.copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
        if (record.transactionHash != null)
          ExternalLink(
            label: 'View transaction',
            uri: Explorer.transaction(record.transactionHash!),
            style: SwType.caption.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
    if (!fresh || SwMotion.reduced(context)) return row;
    return row
        .animate()
        .fadeIn(duration: SwMotion.standard)
        .slideY(begin: -0.2, end: 0, curve: SwMotion.enter)
        .then()
        .shimmer(duration: SwMotion.deliberate, color: SwColors.paydayWash);
  }
}

import 'package:flutter/material.dart';

import '../../../core/stellar/stellar_network.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/amount.dart';
import '../../../core/widgets/external_link.dart';
import '../../../core/widgets/key_text.dart';
import '../../../core/widgets/punch_card.dart';
import '../domain/conversion_quote.dart';

/// Proof that a claim-and-convert landed.
class ConversionReceiptCard extends StatelessWidget {
  const ConversionReceiptCard({super.key, required this.receipt});

  final ConversionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final received = receipt.receivedAmount;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(SwSpace.lg),
        decoration: BoxDecoration(
          color: SwColors.paydayWash,
          borderRadius: const BorderRadius.all(SwRadius.panel),
          border: Border.all(color: SwColors.payday.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Payout claimed as PHPT', style: SwType.subtitle),
                ),
                const ClaimedStamp(
                  label: 'Converted',
                  animate: true,
                  color: SwColors.payday,
                ),
              ],
            ),
            const SizedBox(height: SwSpace.sm),
            Text(
              '${Amount.format(receipt.sentAmount)} test-USDC claimed. '
              '${received != null ? '${Amount.format(received)} PHPT received.' : 'At least ${Amount.format(receipt.minimumAmount)} PHPT received. Open the transaction for the exact amount.'}',
              style: SwType.bodySmall.copyWith(color: SwColors.ink),
            ),
            const SizedBox(height: SwSpace.sm),
            KeyText(receipt.hash, edge: 10),
            ExternalLink(
              label: 'Verify on Stellar Expert',
              uri: Explorer.transaction(receipt.hash),
              color: SwColors.payday,
            ),
          ],
        ),
      ),
    );
  }
}

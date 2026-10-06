import 'package:flutter/material.dart';

import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/external_link.dart';
import '../../../../core/widgets/key_text.dart';
import '../../../../core/widgets/punch_card.dart';
import '../../domain/payroll_schedule.dart';

/// The receipt stub printed after a payroll is locked.
class PayrollProofCard extends StatelessWidget {
  const PayrollProofCard({super.key, required this.proof});

  final PayrollProof proof;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Total locked', '${Amount.format(proof.total)} ${proof.asset}'),
      ('Payouts created', '${proof.balanceCount}'),
      ('Employees', '${proof.employeeCount}'),
      ('Payouts each', '${proof.payouts}'),
      ('First payday', formatDateTime(proof.firstUnlock)),
    ];
    return PayrollPaper(
      header: const PaperHeader(
        title: 'Payroll locked on Stellar Testnet',
        trailing: ClaimedStamp(label: 'Locked', animate: true),
      ),
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SwSpace.lg,
              vertical: 10,
            ),
            child: Row(
              children: [
                Expanded(child: Text(label, style: SwType.bodySmall)),
                Text(value, style: SwType.figures),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(SwSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payroll transaction', style: SwType.caption),
              KeyText(proof.hash, edge: 10),
              ExternalLink(
                label: 'Verify on Stellar Expert',
                uri: Explorer.transaction(proof.hash),
              ),
              if (proof.registryContractId != null) ...[
                const SizedBox(height: SwSpace.md),
                Text('Soroban payroll registry', style: SwType.caption),
                KeyText(proof.registryContractId!, edge: 10),
                if (proof.registryHash != null)
                  ExternalLink(
                    label: 'Verify registry proof',
                    uri: Explorer.transaction(proof.registryHash!),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

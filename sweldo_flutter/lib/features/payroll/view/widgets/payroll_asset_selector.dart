import 'package:flutter/material.dart';

import '../../../../core/stellar/payroll_asset.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/sw_icons.dart';

class PayrollAssetSelector extends StatelessWidget {
  const PayrollAssetSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.semanticLabel = 'Payroll asset for all employees',
  });

  final List<PayrollAssetOption> options;
  final String value;
  final ValueChanged<String>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Payroll asset for all employees (Testnet)',
    child: Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: 92,
        height: 44,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              alignment: Alignment.centerRight,
              style: SwType.label.copyWith(color: SwColors.inkMuted),
              borderRadius: BorderRadius.circular(6),
              icon: const Icon(
                SwIcons.chevronDown,
                size: 14,
                color: SwColors.inkMuted,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option.id,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(option.code),
                    ),
                  ),
              ],
              onChanged: onChanged == null
                  ? null
                  : (value) {
                      if (value != null) onChanged!(value);
                    },
            ),
          ),
        ),
      ),
    ),
  );
}

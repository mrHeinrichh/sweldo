import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/sw_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/sw_button.dart';

/// Groups of four make a 56-character key easy to read back to its owner.
/// The first and last groups are darker: they're the ones people compare.
class AddressGroups extends StatelessWidget {
  const AddressGroups(this.address, {super.key});

  final String address;

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (var i = 0; i < address.length; i += 4)
        address.substring(i, math.min(i + 4, address.length)),
    ];
    final base = SwType.mono.copyWith(
      fontSize: 14,
      height: 1.6,
      color: SwColors.inkMuted,
    );
    final edge = base.copyWith(
      color: SwColors.ink,
      fontWeight: FontWeight.w500,
    );
    return Semantics(
      label: address,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SwSpace.md),
        decoration: BoxDecoration(
          color: SwColors.paper,
          border: Border.all(color: SwColors.rule),
          borderRadius: const BorderRadius.all(SwRadius.field),
        ),
        child: Wrap(
          spacing: 4.6,
          children: [
            for (var i = 0; i < groups.length; i++)
              Text(
                groups[i],
                style: i == 0 || i == groups.length - 1 ? edge : base,
              ),
          ],
        ),
      ),
    );
  }
}

/// Buttons side by side while each gets 190 points, stacked full width below
/// that, like the web's `flex: 1 1 190px`. Pass buttons with `expand: true`.
class QrActions extends StatelessWidget {
  const QrActions(this.children, {super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final sideBySide =
          box.maxWidth >=
          children.length * 190 + (children.length - 1) * SwSpace.sm;
      if (sideBySide) {
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: SwSpace.sm),
              Expanded(child: children[i]),
            ],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: SwSpace.sm),
            children[i],
          ],
        ],
      );
    },
  );
}

/// The reassurance line at the foot of both QR sheets.
class QrPrivacyNote extends StatelessWidget {
  const QrPrivacyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(SwIcons.protectedPay, size: 14, color: SwColors.payday),
      ),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: SwType.caption)),
    ],
  );
}

/// The sheet title with its close button.
class QrSheetHeading extends StatelessWidget {
  const QrSheetHeading({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.onClose,
  });

  final String title;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: SwType.title)),
      SwIconButton(
        icon: SwIcons.close,
        tooltip: closeLabel,
        onPressed: onClose,
      ),
    ],
  );
}

/// [children] with the sheet's 16-point rhythm between them.
List<Widget> spaced(List<Widget> children, {double gap = SwSpace.lg}) => [
  for (var i = 0; i < children.length; i++) ...[
    if (i > 0) SizedBox(height: gap),
    children[i],
  ],
];

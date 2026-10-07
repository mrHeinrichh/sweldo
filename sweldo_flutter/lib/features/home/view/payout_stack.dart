import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/motion/interactive.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/sw_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// Six locked payouts as a 3D pile. Hovering (or tapping on touch) spreads
/// them into a grid so each payday can be read; leaving stacks them again.
class PayoutStack3D extends StatefulWidget {
  const PayoutStack3D({super.key, required this.assetLabel});

  final String assetLabel;

  @override
  State<PayoutStack3D> createState() => _PayoutStack3DState();
}

class _PayoutStack3DState extends State<PayoutStack3D> {
  bool _hovering = false;
  bool _pinned = false;

  static const _paydays = [
    'Nov 3',
    'Dec 3',
    'Jan 3',
    'Feb 3',
    'Mar 3',
    'Apr 3',
  ];

  bool get _open => _hovering || _pinned;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: Interactive(
            onTap: () => setState(() => _pinned = !_pinned),
            lift: 0,
            hoverShadow: false,
            pressScale: 0.99,
            semanticLabel: _open
                ? 'Stack the six payouts'
                : 'Spread the six payouts',
            radius: const BorderRadius.all(SwRadius.panel),
            child: SizedBox(
              height: 380,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _open ? 1 : 0),
                duration: SwMotion.of(
                  context,
                  const Duration(milliseconds: 750),
                ),
                curve: Curves.easeInOutCubic,
                builder: (context, t, _) => LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < _paydays.length; i++)
                        _ticket(i, t, constraints.maxWidth),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: SwSpace.sm),
        AnimatedSwitcher(
          duration: SwMotion.of(context, SwMotion.standard),
          child: Row(
            key: ValueKey(_open),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _open ? SwIcons.ledger : SwIcons.chevronDown,
                size: 14,
                color: SwColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                _open
                    ? 'Six paydays, each locked until its date'
                    : 'Hover or tap to spread the payouts',
                style: SwType.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ticket(int i, double t, double width) {
    const w = 176.0, h = 116.0;
    final columns = width < 480 ? 2 : 3;
    final col = i % columns;
    final row = i ~/ columns;
    final rows = (_paydays.length / columns).ceil();
    final gapX = math.min(196.0, (width - w) / math.max(1, columns - 1));

    // Stacked: a leaning pile seen from above. Spread: a tidy grid.
    final stackedX = 0.0, stackedY = 46 - i * 15.0;
    final spreadX = (col - (columns - 1) / 2) * gapX;
    final spreadY = (row - (rows - 1) / 2) * (h + 16);
    // Each ticket leaves the pile slightly after the one below it.
    final local = Curves.easeOutCubic.transform(
      ((t * 1.4) - i * 0.08).clamp(0.0, 1.0),
    );

    final x = lerpDouble(stackedX, spreadX, local)!;
    final y = lerpDouble(stackedY, spreadY, local)!;
    final rotX = lerpDouble(0.98, 0.22, local)!;
    final rotZ = lerpDouble(-0.62 + i * 0.03, -0.04, local)!;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..translateByDouble(x, y, 0, 1)
        ..rotateX(rotX)
        ..rotateZ(rotZ),
      child: Container(
        width: w,
        height: h,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(SwRadius.card),
          border: Border.all(color: SwColors.rule),
          boxShadow: [
            BoxShadow(
              color: SwColors.ink.withValues(alpha: 0.10 + 0.06 * (1 - local)),
              blurRadius: 18,
              offset: Offset(0, 10 - 4 * local),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(SwIcons.payday, size: 14, color: SwColors.inkMuted),
                const SizedBox(width: 6),
                Text(_paydays[i], style: SwType.label),
                const Spacer(),
                const Icon(SwIcons.locked, size: 16, color: SwColors.stamp),
              ],
            ),
            const Spacer(),
            Text(
              '300 ${widget.assetLabel}',
              style: SwType.amount.copyWith(fontSize: 22),
            ),
          ],
        ),
      ),
    );
  }
}

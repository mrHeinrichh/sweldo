import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/motion/tilt.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/punch_card.dart';
import '../../../core/theme/sw_icons.dart';

/// A worker's pay schedule, printed onto payroll paper. It's a working model
/// of the real flow: one payout is ready, and claiming it stamps the row.
class DemoPayCard extends StatefulWidget {
  const DemoPayCard({super.key, required this.assetLabel});

  final String assetLabel;

  @override
  State<DemoPayCard> createState() => _DemoPayCardState();
}

class _DemoPayCardState extends State<DemoPayCard> {
  late final DateTime _anchor = DateTime.now();
  bool _claimed = false;

  // One claimed, one ready, one about to unlock while you watch, one later.
  late final List<_DemoRow> _rows = [
    _DemoRow(_anchor.subtract(const Duration(days: 15)), _DemoStatus.claimed),
    _DemoRow(_anchor.subtract(const Duration(minutes: 3)), _DemoStatus.ready),
    _DemoRow(
      _anchor.add(const Duration(minutes: 2, seconds: 48)),
      _DemoStatus.locked,
    ),
    _DemoRow(_anchor.add(const Duration(days: 15)), _DemoStatus.locked),
  ];

  @override
  Widget build(BuildContext context) {
    final reduced = SwMotion.reduced(context);
    final rows = [
      for (var i = 0; i < _rows.length; i++)
        _printIn(
          _DemoRowView(
            row: _rows[i],
            asset: widget.assetLabel,
            claimedNow: i == 1 && _claimed,
            onClaim: i == 1 && !_claimed
                ? () => setState(() => _claimed = true)
                : null,
          ),
          index: i,
          reduced: reduced,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tilt3D(
          maxTilt: 7,
          child: PayrollPaper(
            elevated: true,
            header: PaperHeader(
              title: "Ana Santos's pay",
              trailing: Text(
                '1,200 ${widget.assetLabel} locked',
                style: SwType.figures.copyWith(color: SwColors.inkMuted),
              ),
            ),
            children: rows,
          ),
        ),
        const SizedBox(height: SwSpace.md),
        AnimatedSwitcher(
          duration: SwMotion.of(context, SwMotion.standard),
          child: _claimed
              ? Row(
                  key: const ValueKey('claimed'),
                  children: [
                    Expanded(
                      child: Text(
                        'That is the whole claim: one signature, straight to '
                        'her wallet.',
                        style: SwType.caption,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _claimed = false),
                      child: const Text('Reset'),
                    ),
                  ],
                )
              : Text(
                  key: const ValueKey('hint'),
                  'A sample schedule. Try claiming the payout that is ready.',
                  style: SwType.caption,
                ),
        ),
      ],
    );
  }

  /// Rows feed in top to bottom, like a printer advancing the form. This is
  /// the app's one unprompted animation.
  Widget _printIn(Widget child, {required int index, required bool reduced}) {
    if (reduced) return child;
    return child
        .animate(delay: (180 + index * 110).ms)
        .fadeIn(duration: SwMotion.print, curve: SwMotion.enter)
        .moveY(
          begin: -12,
          end: 0,
          duration: SwMotion.print,
          curve: SwMotion.enter,
        );
  }
}

enum _DemoStatus { claimed, ready, locked }

class _DemoRow {
  const _DemoRow(this.payday, this.status);
  final DateTime payday;
  final _DemoStatus status;
}

class _DemoRowView extends StatelessWidget {
  const _DemoRowView({
    required this.row,
    required this.asset,
    required this.claimedNow,
    this.onClaim,
  });

  final _DemoRow row;
  final String asset;
  final bool claimedNow;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    return SecondTicker(
      builder: (context, now) {
        final unlocked = !now.isBefore(row.payday);
        final status = claimedNow
            ? _DemoStatus.claimed
            : row.status == _DemoStatus.locked && unlocked
            ? _DemoStatus.ready
            : row.status;
        final punch = switch (status) {
          _DemoStatus.claimed => PunchState.punched,
          _DemoStatus.ready => PunchState.ready,
          _DemoStatus.locked => PunchState.locked,
        };

        final Widget trailing = switch (status) {
          _DemoStatus.claimed => ClaimedStamp(
            key: ValueKey('stamp$claimedNow'),
            animate: claimedNow,
          ),
          _DemoStatus.ready => FilledButton(
            key: const ValueKey('claim'),
            onPressed: onClaim,
            style: FilledButton.styleFrom(
              backgroundColor: SwColors.payday,
              visualDensity: VisualDensity.compact,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(SwRadius.field),
              ),
            ),
            child: const Text('Claim'),
          ),
          _DemoStatus.locked => Row(
            key: const ValueKey('locked'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(SwIcons.locked, size: 15, color: SwColors.locked),
              const SizedBox(width: 4),
              Text(
                countdownLabel(row.payday.difference(now)),
                style: SwType.figures.copyWith(color: SwColors.locked),
              ),
            ],
          ),
        };

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SwSpace.lg,
            vertical: SwSpace.md,
          ),
          child: Row(
            children: [
              PunchSlot(state: punch),
              const SizedBox(width: SwSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '300 $asset',
                      style: SwType.figures.copyWith(fontSize: 16),
                    ),
                    Text(switch (status) {
                      _DemoStatus.locked =>
                        'Payday ${formatShortDate(row.payday)}',
                      _DemoStatus.ready =>
                        'Unlocked ${formatShortDate(row.payday)}',
                      _DemoStatus.claimed =>
                        claimedNow
                            ? 'Claimed just now'
                            : 'Claimed ${formatShortDate(row.payday)}',
                    }, style: SwType.caption),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedSwitcher(
                    duration: SwMotion.of(context, SwMotion.quick),
                    child: trailing,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

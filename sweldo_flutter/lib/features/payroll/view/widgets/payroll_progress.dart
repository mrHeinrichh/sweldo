import 'package:flutter/material.dart';

import '../../../../core/motion/interactive.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../bloc/payroll_form/payroll_form_bloc.dart';

enum _StepStatus { todo, current, done }

/// Where the employer is in the payroll: team, schedule, lock. Each step
/// updates live as the form fills and jumps to its section when tapped.
class PayrollProgress extends StatelessWidget {
  const PayrollProgress({
    super.key,
    required this.state,
    required this.onSelect,
  });

  final PayrollFormState state;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = state.recipients;
    final valid = rows.where((r) => r.hasValidAddress).length;
    final amountsOk = rows.every(
      (r) => (Amount.tryUnits(r.total) ?? BigInt.zero) > BigInt.zero,
    );
    final teamDone = valid == rows.length && amountsOk;
    final scheduleDone =
        state.payouts >= 1 &&
        state.payouts <= StellarNetwork.maxPayoutsPerEmployee &&
        !state.overOperationLimit;
    final locked = state.lastProof != null;

    final steps = [
      (
        icon: SwIcons.team,
        title: 'Team',
        detail: teamDone
            ? '${rows.length} ${plural(rows.length, 'employee')} ready'
            : '$valid of ${rows.length} wallets added',
        done: teamDone,
      ),
      (
        icon: SwIcons.payday,
        title: 'Schedule',
        detail:
            '${state.payouts} ${plural(state.payouts, 'payout')}, '
            '${state.cadence.label.toLowerCase()}',
        done: scheduleDone,
      ),
      (
        icon: SwIcons.locked,
        title: 'Lock',
        detail: state.submitting
            ? 'Signing…'
            : locked
            ? 'Locked on Stellar'
            : 'One signature',
        done: locked && !state.submitting,
      ),
    ];

    final statuses = <_StepStatus>[];
    var foundCurrent = false;
    for (final step in steps) {
      if (step.done) {
        statuses.add(_StepStatus.done);
      } else if (!foundCurrent) {
        statuses.add(_StepStatus.current);
        foundCurrent = true;
      } else {
        statuses.add(_StepStatus.todo);
      }
    }

    final compact = !context.up(Breakpoint.sm);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: _Step(
              number: i + 1,
              icon: steps[i].icon,
              title: steps[i].title,
              detail: steps[i].detail,
              status: statuses[i],
              compact: compact,
              onTap: () => onSelect(i),
            ),
          ),
          if (i < steps.length - 1)
            Padding(
              padding: EdgeInsets.only(top: compact ? 17 : 19),
              child: SizedBox(
                width: compact ? 16 : 28,
                child: _Connector(filled: statuses[i] == _StepStatus.done),
              ),
            ),
        ],
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(height: 2, color: SwColors.rule),
        AnimatedFractionallySizedBox(
          duration: SwMotion.of(context, SwMotion.deliberate),
          curve: SwMotion.enter,
          widthFactor: filled ? 1 : 0,
          child: Container(height: 2, color: SwColors.payday),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    required this.compact,
    required this.onTap,
  });

  final int number;
  final IconData icon;
  final String title;
  final String detail;
  final _StepStatus status;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = SwMotion.of(context, SwMotion.standard);
    final (fill, iconColor, border) = switch (status) {
      _StepStatus.done => (SwColors.payday, Colors.white, SwColors.payday),
      _StepStatus.current => (SwColors.stamp, Colors.white, SwColors.stamp),
      _StepStatus.todo => (Colors.white, SwColors.inkFaint, SwColors.rule),
    };
    return Interactive(
      onTap: onTap,
      lift: 0,
      hoverShadow: false,
      semanticLabel: 'Step $number, $title: $detail',
      radius: const BorderRadius.all(SwRadius.field),
      builder: (context, state) {
        final circle = AnimatedContainer(
          duration: duration,
          curve: SwMotion.enter,
          width: compact ? 36 : 40,
          height: compact ? 36 : 40,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
            boxShadow: status == _StepStatus.current
                ? [
                    BoxShadow(
                      color: SwColors.stamp.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: duration,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween(begin: -0.25, end: 0.0).animate(animation),
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(
              status == _StepStatus.done ? SwIcons.check : icon,
              key: ValueKey(status == _StepStatus.done),
              size: 18,
              color: iconColor,
            ),
          ),
        );
        final texts = Column(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: SwType.label.copyWith(
                color: status == _StepStatus.todo
                    ? SwColors.inkMuted
                    : SwColors.ink,
                decoration: state.hovered ? TextDecoration.underline : null,
                decorationColor: SwColors.stamp,
              ),
            ),
            AnimatedSwitcher(
              duration: duration,
              child: Text(
                detail,
                key: ValueKey(detail),
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: SwType.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
        if (compact) {
          return Column(children: [circle, const SizedBox(height: 6), texts]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            circle,
            const SizedBox(width: SwSpace.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: texts,
              ),
            ),
          ],
        );
      },
    );
  }
}

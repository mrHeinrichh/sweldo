import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/motion/interactive.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/external_link.dart';
import '../../../../core/widgets/key_text.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/notice.dart';
import '../../../../core/widgets/sw_button.dart';
import '../../../wallet/bloc/wallet_bloc.dart';
import '../../../wallet/domain/wallet_session.dart';
import '../../bloc/schedules/schedules_bloc.dart';
import '../../domain/payroll_schedule.dart';
import '../../../../core/theme/sw_icons.dart';

/// Recent payrolls on this device, with future-payout cancellation.
/// Collapses to its header; the employer page hides it while it's empty.
class ScheduleList extends StatefulWidget {
  const ScheduleList({super.key});

  @override
  State<ScheduleList> createState() => _ScheduleListState();
}

class _ScheduleListState extends State<ScheduleList> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SchedulesBloc>().state;
    final count = state.schedules.length;
    final duration = SwMotion.of(context, SwMotion.standard);

    final header = Row(
      children: [
        Expanded(
          child: Interactive(
            onTap: () => setState(() => _expanded = !_expanded),
            lift: 0,
            hoverShadow: false,
            semanticLabel: _expanded
                ? 'Collapse recent payrolls'
                : 'Expand recent payrolls',
            builder: (context, interaction) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: SwColors.stampWash,
                      borderRadius: BorderRadius.all(SwRadius.field),
                    ),
                    child: const Icon(
                      SwIcons.receipt,
                      size: 18,
                      color: SwColors.stamp,
                    ),
                  ),
                  const SizedBox(width: SwSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Recent payrolls',
                                style: SwType.title,
                              ),
                            ),
                            const SizedBox(width: SwSpace.sm),
                            AnimatedSwitcher(
                              duration: duration,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  ),
                              child: Container(
                                key: ValueKey(count),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: SwColors.stamp,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(999),
                                  ),
                                ),
                                child: Text(
                                  '$count',
                                  style: SwType.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Saved on this device, each linked to its proof.',
                          style: SwType.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: duration,
                    curve: SwMotion.move,
                    child: Icon(
                      SwIcons.chevronDown,
                      size: 20,
                      color: interaction.hovered
                          ? SwColors.stamp
                          : SwColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (state.address != null) ...[
          const SizedBox(width: SwSpace.sm),
          SwIconButton(
            icon: SwIcons.refresh,
            tooltip: 'Check the ledger again',
            loading: !state.balancesLoaded,
            onPressed: () => context.read<SchedulesBloc>().add(
              const SchedulesRefreshRequested(),
            ),
          ),
        ],
      ],
    );

    return Panel(
      padding: EdgeInsets.all(context.responsive(SwSpace.lg, sm: SwSpace.xl)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          AnimatedNotice(
            state.notice,
            padding: const EdgeInsets.only(top: SwSpace.lg),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: duration,
              curve: SwMotion.enter,
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: SwSpace.lg),
                      child: Column(
                        children: [
                          for (var i = 0; i < count; i++) ...[
                            if (i > 0) const Divider(height: SwSpace.xl),
                            _ScheduleTile(
                              key: ValueKey(state.schedules[i].id),
                              schedule: state.schedules[i],
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({super.key, required this.schedule});

  final PayrollSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final perPayout = Amount.perPayout(schedule.total, schedule.tranches);
    final fresh =
        DateTime.now().difference(schedule.createdAt) <
        const Duration(seconds: 4);
    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: SwColors.stampWash,
              child: Text(
                schedule.initial,
                style: SwType.label.copyWith(color: SwColors.stampDeep),
              ),
            ),
            const SizedBox(width: SwSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule.name, style: SwType.subtitle),
                  KeyText(schedule.employee, edge: 5),
                  Text(
                    '${schedule.tranches} ${plural(schedule.tranches, 'payout')} '
                    'of ${Amount.format(perPayout)} ${schedule.asset}',
                    style: SwType.bodySmall,
                  ),
                  Text(
                    'Locked ${formatDateTime(schedule.createdAt)}',
                    style: SwType.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'View payroll transaction',
              icon: const Icon(
                SwIcons.external,
                size: 18,
                color: SwColors.inkMuted,
              ),
              onPressed: () =>
                  openExternal(Explorer.transaction(schedule.hash)),
            ),
          ],
        ),
        const SizedBox(height: SwSpace.md),
        _ScheduleControl(schedule: schedule),
      ],
    );
    if (!fresh || SwMotion.reduced(context)) return tile;
    return tile
        .animate()
        .fadeIn(duration: SwMotion.deliberate)
        .slideY(begin: -0.08, end: 0, curve: SwMotion.enter);
  }
}

/// The cancellation status line, re-evaluated every second because a
/// payout stops being cancellable the moment its payday arrives.
class _ScheduleControl extends StatelessWidget {
  const _ScheduleControl({required this.schedule});

  final PayrollSchedule schedule;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SchedulesBloc>().state;
    final session = context.select((WalletBloc b) => b.state.session);

    return SecondTicker(
      builder: (context, now) {
        final remaining = state.cancellableFor(schedule, now);
        final Widget content;
        if (!schedule.revocable) {
          content = _status('Original schedule. Cancellation was not enabled.');
        } else if (schedule.isCancelled) {
          final n = schedule.cancelledPayouts ?? 0;
          content = Wrap(
            spacing: SwSpace.md,
            runSpacing: SwSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _status(
                '$n future ${plural(n, 'payout')} returned to you',
                icon: SwIcons.check,
                color: SwColors.payday,
              ),
              if (schedule.cancelHash != null)
                ExternalLink(
                  label: 'Cancellation proof',
                  uri: Explorer.transaction(schedule.cancelHash!),
                  style: SwType.caption.copyWith(fontWeight: FontWeight.w600),
                ),
            ],
          );
        } else if (session == null) {
          content = _status(
            'Connect the employer wallet to manage this payroll.',
          );
        } else if (schedule.employer != session.address) {
          content = _status(
            'Connect the wallet that funded this payroll to manage it.',
          );
        } else if (!state.balancesLoaded) {
          content = _status('Checking future payouts on the ledger…');
        } else if (remaining.isNotEmpty) {
          content = Wrap(
            spacing: SwSpace.md,
            runSpacing: SwSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _status(
                '${remaining.length} future '
                '${plural(remaining.length, 'payout')} can still be cancelled',
              ),
              SwButton(
                label: 'Cancel remaining payroll',
                icon: SwIcons.undo,
                tone: SwButtonTone.danger,
                loading: state.cancellingId == schedule.id,
                onPressed: state.cancellingId != null
                    ? null
                    : () => _confirmCancel(context, session, remaining.length),
              ),
            ],
          );
        } else {
          content = _status(
            'Every payday has arrived. Nothing left to cancel.',
          );
        }

        return Container(
          padding: const EdgeInsets.all(SwSpace.md),
          decoration: BoxDecoration(
            color: schedule.isCancelled ? SwColors.paydayWash : SwColors.paper,
            borderRadius: const BorderRadius.all(SwRadius.field),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: SwMotion.of(context, SwMotion.quick),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(
                    content.runtimeType.toString() +
                        remaining.length.toString() +
                        schedule.isCancelled.toString(),
                  ),
                  child: content,
                ),
              ),
              if (schedule.registryContractId != null) ...[
                const SizedBox(height: SwSpace.xs),
                ExternalLink(
                  label: 'Recorded in the Soroban payroll registry',
                  uri: Explorer.contract(schedule.registryContractId!),
                  style: SwType.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _status(String text, {IconData? icon, Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            style: SwType.caption.copyWith(color: color ?? SwColors.inkMuted),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WalletSession session,
    int count,
  ) async {
    final bloc = context.read<SchedulesBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel future payouts for ${schedule.name}?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Sweldo re-checks all $count eligible '
            '${plural(count, 'payout')} on Stellar, then returns '
            '${count == 1 ? 'it' : 'them'} to your wallet. Payouts at or past '
            'payday stay with the employee.',
            style: SwType.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep payroll'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SwColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Cancel $count ${plural(count, 'payout')}'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(ScheduleCancelRequested(schedule, session));
    }
  }
}

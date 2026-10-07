import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/notice.dart';
import '../../../../core/widgets/punch_card.dart';
import '../../../../core/widgets/sw_button.dart';
import '../../../account/bloc/account_setup_cubit.dart';
import '../../../account/view/account_setup_prompts.dart';
import '../../../wallet/bloc/wallet_bloc.dart';
import '../../../wallet/view/connect_wallet_sheet.dart';
import '../../bloc/payroll_form/payroll_form_bloc.dart';
import '../../../tour/tour_controller.dart';
import 'payroll_progress.dart';
import 'payroll_proof_card.dart';
import 'recipient_row.dart';
import 'pay_schedule_builder.dart';

typedef _StepCopy = ({String title, String description, String? next});

const _steps = <_StepCopy>[
  (
    title: 'Who are you paying?',
    description:
        'Add each person with their Stellar wallet and the total to pay them.',
    next: 'Continue to schedule',
  ),
  (
    title: 'When do they get paid?',
    description:
        'Choose how often pay unlocks, how many times, and when it starts.',
    next: 'Continue to review',
  ),
  (
    title: 'Review and lock',
    description:
        'Check the plan, then sign once in Freighter to lock every payout.',
    next: null,
  ),
];

/// "New payroll" as three short steps: who gets paid, when, then one
/// signature. Each step fits on a screen, so nobody scrolls a long form.
class PayrollForm extends StatefulWidget {
  const PayrollForm({super.key});

  @override
  State<PayrollForm> createState() => _PayrollFormState();
}

class _PayrollFormState extends State<PayrollForm> {
  final _top = GlobalKey();
  bool _forward = true;
  late int _lastStep = context.read<PayrollFormBloc>().state.step;

  /// Rows present on first build don't animate in; rows added later do.
  late final Set<String> _initialIds = context
      .read<PayrollFormBloc>()
      .state
      .recipients
      .map((r) => r.id)
      .toSet();

  /// Brings the start of the form back into view if it scrolled away.
  void _revealTop() {
    final target = _top.currentContext;
    final box = target?.findRenderObject() as RenderBox?;
    if (target == null || box == null || !box.attached) return;
    if (box.localToGlobal(Offset.zero).dy >= 80) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.08,
      duration: SwMotion.of(context, const Duration(milliseconds: 500)),
      curve: SwMotion.move,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = context.read<AppConfig>().assetLabel;
    final state = context.watch<PayrollFormBloc>().state;
    final bloc = context.read<PayrollFormBloc>();
    final wide = isWide(context);
    final locked = state.step == 2 && state.lastProof != null;
    final heading = locked
        ? (
            title: 'Payroll locked',
            description:
                'Every payout is on the Stellar ledger. You can cancel future '
                'payouts until each payday.',
          )
        : (
            title: _steps[state.step].title,
            description: _steps[state.step].description,
          );

    final Widget body = switch (state.step) {
      0 => _TeamStep(initialIds: _initialIds),
      1 => const PayScheduleBuilder(),
      _ =>
        locked
            ? _LockedStep(onNew: () => bloc.add(const PayrollDraftStarted()))
            : const _ReviewStep(),
    };

    Widget step = Column(
      key: ValueKey(locked ? 'locked' : state.step),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          heading.title,
          style: SwType.amount.copyWith(fontSize: 24, height: 1.15),
        ),
        const SizedBox(height: 6),
        Text(heading.description, style: SwType.bodySmall),
        const SizedBox(height: SwSpace.xl),
        body,
      ],
    );
    if (!SwMotion.reduced(context)) {
      // The new step slides in from the side you're moving toward.
      step = step
          .animate(key: ValueKey('${locked ? 'locked' : state.step}'))
          .fadeIn(duration: SwMotion.standard, curve: SwMotion.enter)
          .moveX(
            begin: _forward ? 24 : -24,
            end: 0,
            duration: SwMotion.standard,
            curve: SwMotion.enter,
          );
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<PayrollFormBloc, PayrollFormState>(
          listenWhen: (previous, next) =>
              next.lastProof != null && previous.lastProof != next.lastProof,
          listener: (context, _) => context.read<AccountSetupCubit>().refresh(),
        ),
        BlocListener<PayrollFormBloc, PayrollFormState>(
          listenWhen: (previous, next) => previous.step != next.step,
          listener: (context, next) {
            _forward = next.step >= _lastStep;
            _lastStep = next.step;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _revealTop();
            });
          },
        ),
      ],
      child: Panel(
        padding: EdgeInsets.all(context.responsive(SwSpace.lg, sm: SwSpace.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(
              key: _top,
              child: PayrollProgress(
                state: state,
                onSelect: (index) => bloc.add(PayrollStepChanged(index)),
              ),
            ),
            const SizedBox(height: SwSpace.xl),
            AccountSetupPrompts(
              trustlineMessage:
                  'Add a $asset trustline so this wallet can hold and lock $asset '
                  'for payroll.',
            ),
            AnimatedNotice(
              state.notice,
              padding: const EdgeInsets.only(bottom: SwSpace.lg),
            ),
            step,
            if (!locked && wide) ...[
              const SizedBox(height: SwSpace.xl),
              const PayrollActions(),
            ],
            if (state.step == 2 && !locked) ...[
              const SizedBox(height: SwSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      SwIcons.protectedPay,
                      size: 14,
                      color: SwColors.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Funds move from your wallet into claimable balances on the '
                      'Stellar ledger. Sweldo never holds them.',
                      style: SwType.caption,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Back and Continue: at the foot of the form on wide screens, and pinned
/// above the bottom navigation on phones ([pinned]) so the next action never
/// needs a scroll.
class PayrollActions extends StatelessWidget {
  const PayrollActions({super.key, this.pinned = false});

  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PayrollFormBloc>().state;
    final bloc = context.read<PayrollFormBloc>();
    if (state.step == 2 && state.lastProof != null) {
      return const SizedBox.shrink();
    }

    final back = state.step > 0
        ? SwButton(
            label: 'Back',
            icon: SwIcons.back,
            tone: SwButtonTone.secondary,
            onPressed: state.submitting
                ? null
                : () => bloc.add(PayrollStepChanged(state.step - 1)),
          )
        : null;
    final primary = state.step < 2
        ? SwButton(
            label: _steps[state.step].next!,
            icon: SwIcons.forward,
            expand: pinned,
            onPressed: () => bloc.add(PayrollStepChanged(state.step + 1)),
          )
        : _LockButton(expand: pinned);

    if (!pinned) {
      return Container(
        padding: const EdgeInsets.only(top: SwSpace.lg),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: SwColors.rule)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [back ?? const SizedBox.shrink(), primary],
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: SwColors.sheet,
        border: Border(top: BorderSide(color: SwColors.rule)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.responsive(SwSpace.lg, sm: SwSpace.xl),
        vertical: SwSpace.md,
      ),
      child: Row(
        children: [
          if (back != null) ...[back, const SizedBox(width: SwSpace.md)],
          Expanded(child: primary),
        ],
      ),
    ).animate().fadeIn(duration: SwMotion.of(context, SwMotion.standard));
  }
}

class _LockButton extends StatelessWidget {
  const _LockButton({required this.expand});

  final bool expand;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PayrollFormBloc>().state;
    final session = context.select((WalletBloc b) => b.state.session);
    final label = session == null
        ? (context.up(Breakpoint.sm)
              ? 'Connect wallet to lock payroll'
              : 'Connect to lock')
        : state.progress ?? 'Lock payroll on Stellar';
    return TourTarget(
      id: 'lock',
      child: SwButton(
        label: label,
        icon: session == null ? SwIcons.wallet : SwIcons.locked,
        expand: expand,
        loading: state.submitting,
        onPressed: session == null
            ? () => showConnectWalletSheet(context)
            : state.blocked
            ? null
            : () => context.read<PayrollFormBloc>().add(
                PayrollSubmitted(session),
              ),
      ),
    );
  }
}

class _TeamStep extends StatelessWidget {
  const _TeamStep({required this.initialIds});

  final Set<String> initialIds;

  @override
  Widget build(BuildContext context) {
    final asset = context.read<AppConfig>().assetLabel;
    final state = context.watch<PayrollFormBloc>().state;
    final bloc = context.read<PayrollFormBloc>();
    final count = state.recipients.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$count ${plural(count, 'employee')}',
                style: SwType.caption,
              ),
            ),
            SwButton(
              label: context.up(Breakpoint.sm) ? 'Add employee' : 'Add',
              icon: SwIcons.add,
              tone: SwButtonTone.quiet,
              onPressed: state.submitting
                  ? null
                  : () => bloc.add(const RecipientAdded()),
            ),
          ],
        ),
        const SizedBox(height: SwSpace.sm),
        TourTarget(
          id: 'employees',
          child: AnimatedSize(
            duration: SwMotion.of(context, SwMotion.standard),
            curve: SwMotion.enter,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++)
                  Padding(
                    key: ValueKey(state.recipients[i].id),
                    padding: EdgeInsets.only(
                      bottom: i == count - 1 ? 0 : SwSpace.md,
                    ),
                    child: RecipientRow(
                      recipient: state.recipients[i],
                      index: i,
                      payouts: state.payouts,
                      assetLabel: asset,
                      removable: count > 1,
                      animateIn: !initialIds.contains(state.recipients[i].id),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The plan as a printed pay summary, then the checks, then the policy.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final asset = context.read<AppConfig>().assetLabel;
    final state = context.watch<PayrollFormBloc>().state;
    final bloc = context.read<PayrollFormBloc>();
    final people = state.recipients.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayrollPaper(
          header: PaperHeader(
            title:
                '$people ${plural(people, 'employee')} × ${state.payouts} '
                '${plural(state.payouts, 'payout')}',
            trailing: Text(
              '${Amount.formatUnits(state.totalLockedUnits)} $asset',
              style: SwType.amount,
            ),
          ),
          children: [
            for (var i = 0; i < people; i++)
              _ReviewRow(
                name: state.recipients[i].name.trim().isEmpty
                    ? 'Employee ${i + 1}'
                    : state.recipients[i].name.trim(),
                address: state.recipients[i].hasValidAddress
                    ? state.recipients[i].employee
                    : null,
                total: state.recipients[i].total,
                payouts: state.payouts,
                each: state.amountPerPayout(state.recipients[i].total),
                asset: asset,
              ),
          ],
        ),
        const SizedBox(height: SwSpace.lg),
        ScheduleInsights(
          leading: [
            if (state.missingAddresses > 0)
              InsightChip(
                icon: SwIcons.warning,
                tone: InsightTone.danger,
                text:
                    '${state.missingAddresses} '
                    '${plural(state.missingAddresses, 'employee needs', 'employees need')} '
                    'a wallet address',
                actionLabel: 'Add addresses',
                onAction: () => bloc.add(const PayrollStepChanged(0)),
              ),
            if (state.invalidAmounts > 0)
              InsightChip(
                icon: SwIcons.warning,
                tone: InsightTone.danger,
                text:
                    '${state.invalidAmounts} '
                    '${plural(state.invalidAmounts, 'amount')} can’t be split '
                    'into ${state.payouts} payouts',
                actionLabel: 'Fix amounts',
                onAction: () => bloc.add(const PayrollStepChanged(0)),
              ),
          ],
        ),
        const SizedBox(height: SwSpace.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(SwIcons.undo, size: 18, color: SwColors.stamp),
            const SizedBox(width: SwSpace.md),
            Expanded(
              child: Text(
                'You can cancel a payout until its payday. From payday on, only '
                'the employee can claim it.',
                style: SwType.bodySmall.copyWith(color: SwColors.ink),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.name,
    required this.address,
    required this.total,
    required this.payouts,
    required this.each,
    required this.asset,
  });

  final String name;
  final String? address;
  final String total;
  final int payouts;
  final String each;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SwSpace.lg,
        vertical: SwSpace.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: SwType.subtitle),
                if (address != null)
                  Text(
                    shortKey(address!, 6),
                    style: SwType.mono,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Row(
                    children: [
                      const Icon(SwIcons.key, size: 13, color: SwColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        'Wallet address missing',
                        style: SwType.caption.copyWith(color: SwColors.danger),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: SwSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${Amount.format(total.isEmpty ? '0' : total)} $asset',
                style: SwType.figures,
              ),
              Text(
                '$payouts × ${Amount.format(each)} $asset',
                style: SwType.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LockedStep extends StatelessWidget {
  const _LockedStep({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final proof = context.select((PayrollFormBloc b) => b.state.lastProof);
    if (proof == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayrollProofCard(key: ValueKey(proof.hash), proof: proof),
        const SizedBox(height: SwSpace.lg),
        Align(
          alignment: Alignment.centerRight,
          child: SwButton(
            label: 'Start a new payroll',
            icon: SwIcons.replay,
            tone: SwButtonTone.secondary,
            onPressed: onNew,
          ),
        ),
      ],
    );
  }
}

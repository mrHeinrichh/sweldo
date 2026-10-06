import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/motion/interactive.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/layout.dart';
import '../../../../core/widgets/notice.dart';
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

/// "New payroll": who gets paid, how much, how often — then one signature.
class PayrollForm extends StatefulWidget {
  const PayrollForm({super.key});

  @override
  State<PayrollForm> createState() => _PayrollFormState();
}

class _PayrollFormState extends State<PayrollForm> {
  final _sections = [GlobalKey(), GlobalKey(), GlobalKey()];

  /// Rows present on first build don't animate in; rows added later do.
  late final Set<String> _initialIds = context
      .read<PayrollFormBloc>()
      .state
      .recipients
      .map((r) => r.id)
      .toSet();

  void _jumpTo(int section) {
    final target = _sections[section].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: SwMotion.of(context, const Duration(milliseconds: 500)),
      curve: SwMotion.move,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = context.read<AppConfig>().assetLabel;
    final state = context.watch<PayrollFormBloc>().state;
    final session = context.select((WalletBloc b) => b.state.session);
    final bloc = context.read<PayrollFormBloc>();

    return BlocListener<PayrollFormBloc, PayrollFormState>(
      listenWhen: (previous, next) =>
          next.lastProof != null && previous.lastProof != next.lastProof,
      listener: (context, _) => context.read<AccountSetupCubit>().refresh(),
      child: Panel(
        padding: EdgeInsets.all(context.responsive(SwSpace.lg, sm: SwSpace.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeading(
              title: 'New payroll',
              description:
                  'One transaction creates every time-locked payout for every '
                  'employee below.',
            ),
            const SizedBox(height: SwSpace.xl),
            PayrollProgress(state: state, onSelect: _jumpTo),
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
            AnimatedSize(
              duration: SwMotion.of(context, SwMotion.deliberate),
              curve: SwMotion.enter,
              alignment: Alignment.topCenter,
              child: state.lastProof == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: SwSpace.xl),
                      child: PayrollProofCard(
                        key: ValueKey(state.lastProof!.hash),
                        proof: state.lastProof!,
                      ),
                    ),
            ),
            TourTarget(
              id: 'employees',
              child: Row(
                key: _sections[0],
                children: [
                  const Icon(SwIcons.team, size: 18, color: SwColors.ink),
                  const SizedBox(width: SwSpace.sm),
                  Expanded(child: Text('Employees', style: SwType.subtitle)),
                  TourTarget(
                    id: 'shuffle',
                    child: _ShuffleButton(
                      shuffles: state.shuffles,
                      onPressed: state.submitting
                          ? null
                          : () => bloc.add(const PayrollRandomized()),
                    ),
                  ),
                  const SizedBox(width: 4),
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
            ),
            const SizedBox(height: SwSpace.md),
            AnimatedSize(
              duration: SwMotion.of(context, SwMotion.standard),
              curve: SwMotion.enter,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < state.recipients.length; i++)
                    Padding(
                      key: ValueKey(state.recipients[i].id),
                      padding: const EdgeInsets.only(bottom: SwSpace.md),
                      child: RecipientRow(
                        recipient: state.recipients[i],
                        index: i,
                        payouts: state.payouts,
                        assetLabel: asset,
                        removable: state.recipients.length > 1,
                        shuffles: state.shuffles,
                        animateIn: !_initialIds.contains(
                          state.recipients[i].id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(key: _sections[1], height: SwSpace.lg),
            const PayScheduleBuilder(),
            const SizedBox(height: SwSpace.xl),
            _BatchSummary(key: _sections[2], state: state, asset: asset),
            const SizedBox(height: SwSpace.lg),
            const _CancellationPolicy(),
            const SizedBox(height: SwSpace.xl),
            TourTarget(
              id: 'lock',
              child: SwButton(
                label: session == null
                    ? 'Connect wallet to lock payroll'
                    : state.progress ?? 'Lock payroll on Stellar',
                icon: session == null ? SwIcons.wallet : SwIcons.locked,
                large: true,
                expand: true,
                loading: state.submitting,
                onPressed: () => session == null
                    ? showConnectWalletSheet(context)
                    : bloc.add(PayrollSubmitted(session)),
              ),
            ),
            const SizedBox(height: SwSpace.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  SwIcons.protectedPay,
                  size: 14,
                  color: SwColors.inkMuted,
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
        ),
      ),
    );
  }
}

/// Rolls new sample values. The dice turns once per roll.
class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton({required this.shuffles, required this.onPressed});

  final int shuffles;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final duration = SwMotion.of(context, const Duration(milliseconds: 600));
    return Interactive(
      onTap: onPressed,
      tooltip: 'Fill the form with new sample values',
      lift: 0,
      hoverShadow: false,
      builder: (context, state) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: state.hovered ? SwColors.stampWash : Colors.transparent,
          borderRadius: const BorderRadius.all(SwRadius.field),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: shuffles.toDouble() + (state.hovered ? 0.06 : 0),
              duration: duration,
              curve: Curves.easeOutBack,
              child: const Icon(
                SwIcons.shuffle,
                size: 18,
                color: SwColors.stamp,
              ),
            ),
            const SizedBox(width: SwSpace.sm),
            Text(
              'Shuffle',
              style: SwType.label.copyWith(color: SwColors.stamp),
            ),
          ],
        ),
      ),
    );
  }
}

/// Employees × payouts, the 100-operation budget, and the total.
class _BatchSummary extends StatelessWidget {
  const _BatchSummary({super.key, required this.state, required this.asset});

  final PayrollFormState state;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final people = state.recipients.length;
    return Container(
      padding: const EdgeInsets.all(SwSpace.lg),
      decoration: const BoxDecoration(
        color: SwColors.greenbar,
        borderRadius: BorderRadius.all(SwRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(SwIcons.ledger, size: 16, color: SwColors.ink),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '$people ${plural(people, 'employee')} × ${state.payouts} '
                        '${plural(state.payouts, 'payout')}',
                        style: SwType.bodySmall.copyWith(color: SwColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total locked', style: SwType.caption),
                  AnimatedSwitcher(
                    duration: SwMotion.of(context, SwMotion.quick),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      key: ValueKey(state.totalLockedUnits),
                      '${Amount.formatUnits(state.totalLockedUnits)} $asset',
                      style: SwType.amount,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancellationPolicy extends StatelessWidget {
  const _CancellationPolicy();

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

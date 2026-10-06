import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/sw_button.dart';
import '../bloc/account_setup_cubit.dart';
import '../../../core/theme/sw_icons.dart';

/// "Your practice wallet is empty" and "Enable USDC" prompts. Each appears
/// only while it's needed and collapses away once resolved.
class AccountSetupPrompts extends StatelessWidget {
  const AccountSetupPrompts({super.key, required this.trustlineMessage});

  /// Why this page needs the trustline, in the page's own terms.
  final String trustlineMessage;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccountSetupCubit>();
    final state = context.watch<AccountSetupCubit>().state;
    final asset = cubit.assetCode;

    final prompts = <Widget>[
      if (state.needsFunding)
        _Prompt(
          key: const ValueKey('fund'),
          icon: SwIcons.savings,
          title: 'This wallet is empty',
          body: 'Get free Testnet XLM to try Sweldo. It has no real value.',
          action: SwButton(
            label: 'Get free test XLM',
            loading: state.funding,
            onPressed: cubit.fund,
          ),
        )
      else if (state.needsTrustline)
        _Prompt(
          key: const ValueKey('trust'),
          icon: SwIcons.trustline,
          title: 'Enable $asset in this wallet',
          body: trustlineMessage,
          action: SwButton(
            label: 'Enable $asset',
            tone: SwButtonTone.secondary,
            loading: state.enabling,
            onPressed: cubit.enableAsset,
          ),
        ),
    ];

    return AnimatedSize(
      duration: SwMotion.of(context, SwMotion.standard),
      curve: SwMotion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: SwMotion.of(context, SwMotion.standard),
        child: prompts.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: prompts.first.key,
                padding: const EdgeInsets.only(bottom: SwSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    prompts.first,
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: SwSpace.sm),
                        child: Text(
                          state.error!,
                          style: SwType.caption.copyWith(
                            color: SwColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SwSpace.lg),
      decoration: BoxDecoration(
        color: SwColors.stampWash,
        borderRadius: const BorderRadius.all(SwRadius.panel),
        border: Border.all(color: SwColors.stamp.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: SwSpace.lg,
        runSpacing: SwSpace.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: SwColors.stamp),
                const SizedBox(width: SwSpace.md),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: SwType.subtitle),
                      const SizedBox(height: 2),
                      Text(body, style: SwType.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}

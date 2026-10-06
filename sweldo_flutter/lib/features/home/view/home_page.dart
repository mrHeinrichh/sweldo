import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/shell/page_frame.dart';
import '../../../core/config/app_config.dart';
import '../../../core/motion/effects.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/punch_card.dart';
import '../../../core/widgets/sw_button.dart';
import '../../story/view/story_page.dart';
import '../../story/view/story_player.dart';
import '../../tour/tour_controller.dart';
import 'demo_pay_card.dart';
import 'payout_stack.dart';
import 'process_explorer.dart';
import '../../../core/theme/sw_icons.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final wide = isWide(context);
    final intro = _Intro(wide: wide);
    final card = DemoPayCard(assetLabel: config.assetLabel);

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: intro),
                const SizedBox(width: SwSpace.huge),
                Expanded(flex: 5, child: card),
              ],
            )
          else ...[
            intro,
            const SizedBox(height: SwSpace.xxl),
            card,
          ],
          SizedBox(height: wide ? 96 : SwSpace.huge),
          const Reveal(child: _ProcessSection()),
          SizedBox(height: wide ? 96 : SwSpace.huge),
          const Reveal(child: _StorySection()),
          SizedBox(height: wide ? 96 : SwSpace.huge),
          Reveal(
            child: _MoneyFacts(
              conversionEnabled: config.conversionPair != null,
              assetLabel: config.assetLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Every payday, locked in.',
          style: wide
              ? SwType.display.copyWith(fontSize: 60, letterSpacing: -2.2)
              : SwType.display,
        ),
        const SizedBox(height: SwSpace.xl),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Sign once to lock a team’s salaries on Stellar. Each person '
            'claims their pay the moment it unlocks, straight to their own '
            'wallet. Sweldo never holds the money.',
            style: SwType.body.copyWith(fontSize: 18, height: 1.5),
          ),
        ),
        const SizedBox(height: SwSpace.xxl),
        TourTarget(
          id: 'hero-actions',
          child: Wrap(
            spacing: SwSpace.md,
            runSpacing: SwSpace.md,
            children: [
              SwButton(
                label: 'Set up payroll',
                large: true,
                onPressed: () => context.go(AppRoute.employer.path),
              ),
              SwButton(
                label: 'See my pay',
                large: true,
                tone: SwButtonTone.secondary,
                onPressed: () => context.go(AppRoute.employee.path),
              ),
            ],
          ),
        ),
        const SizedBox(height: SwSpace.lg),
        SwButton(
          label: 'Watch the 36-second story',
          icon: SwIcons.story,
          tone: SwButtonTone.quiet,
          onPressed: () => context.go(StoryPage.path),
        ),
        const SizedBox(height: SwSpace.md),
        Text(
          'Runs on Stellar Testnet with test money. Connect Freighter in your '
          'browser or on your phone.',
          style: SwType.bodySmall,
        ),
      ],
    );
  }
}

/// The process, hands-on: steps on one side, a 3D phone on the other.
class _ProcessSection extends StatelessWidget {
  const _ProcessSection();

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How a payroll runs',
          style: SwType.headline.copyWith(fontSize: wide ? 36 : 28),
        ),
        const SizedBox(height: SwSpace.sm),
        Text(
          'Pick a step to see it on the phone. Arrow keys move between steps.',
          style: SwType.body.copyWith(color: SwColors.inkMuted),
        ),
        const SizedBox(height: SwSpace.xl),
        const TourTarget(id: 'process', child: ProcessExplorer()),
      ],
    );
  }
}

/// The product, told as a short film: words first, then the app on a phone.
class _StorySection extends StatelessWidget {
  const _StorySection();

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Watch it start to finish',
          style: SwType.headline.copyWith(fontSize: wide ? 36 : 28),
        ),
        const SizedBox(height: SwSpace.sm),
        Text(
          'A 36-second story: one worker, from a locked payroll to pay in her wallet.',
          style: SwType.body.copyWith(color: SwColors.inkMuted),
        ),
        const SizedBox(height: SwSpace.xl),
        StoryPlayer(
          finishedLabel: 'Set up payroll',
          onFinishedAction: () => context.go(AppRoute.employer.path),
        ),
      ],
    );
  }
}

/// Plain answers to "where is the money?", beside the payouts themselves.
class _MoneyFacts extends StatelessWidget {
  const _MoneyFacts({
    required this.conversionEnabled,
    required this.assetLabel,
  });

  final bool conversionEnabled;
  final String assetLabel;

  @override
  Widget build(BuildContext context) {
    final facts = [
      (
        SwIcons.protectedPay,
        'Who holds the money',
        'The Stellar ledger. Each payout is a claimable balance that only the '
            'employee can claim, and only from payday on.',
      ),
      (
        SwIcons.undo,
        'Who can cancel',
        'The employer, for payouts whose payday hasn’t arrived. Pay that has '
            'unlocked belongs to the employee.',
      ),
      (
        SwIcons.amount,
        'What it costs',
        'A network fee of a fraction of a cent, plus a 1 XLM reserve per '
            'payout (0.5 XLM for each of its two claimants), returned to the '
            'employer once the payout is claimed or cancelled.',
      ),
      (
        SwIcons.convert,
        'Local currency',
        conversionEnabled
            ? 'Workers can claim test-USDC as PHPT in the same transaction, '
                  'through Stellar’s built-in exchange.'
            : 'With a test-USDC build, workers can claim straight into PHPT '
                  'through Stellar’s built-in exchange.',
      ),
    ];
    final wide = context.up(Breakpoint.lg);
    final paper = PayrollPaper(
      children: [
        for (final (icon, label, body) in facts)
          Padding(
            padding: const EdgeInsets.all(SwSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(SwRadius.field),
                  ),
                  child: Icon(icon, size: 18, color: SwColors.stamp),
                ),
                const SizedBox(width: SwSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: SwType.subtitle),
                      const SizedBox(height: SwSpace.xs),
                      Text(
                        body,
                        style: SwType.bodySmall.copyWith(color: SwColors.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final stack = PayoutStack3D(assetLabel: assetLabel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where the money is',
          style: SwType.headline.copyWith(
            fontSize: context.responsive(28.0, lg: 36),
          ),
        ),
        const SizedBox(height: SwSpace.xl),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 6, child: paper),
              const SizedBox(width: SwSpace.xxl),
              Expanded(flex: 5, child: stack),
            ],
          )
        else ...[
          stack,
          const SizedBox(height: SwSpace.xl),
          paper,
        ],
      ],
    );
  }
}

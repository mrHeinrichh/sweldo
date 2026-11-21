import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/shell/page_frame.dart';
import '../../../core/config/app_config.dart';
import '../../../core/motion/scroll_progress.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/sw_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/punch_card.dart';
import '../../../core/widgets/sw_button.dart';
import '../../story/view/story_page.dart';
import '../../story/view/story_player.dart';
import '../../tour/tour_controller.dart';
import 'demo_pay_card.dart';
import 'ledger_pulse.dart';
import 'page_spine.dart';
import 'payout_stack.dart';
import 'process_explorer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _labels = ['Overview', 'How it runs', 'The story', 'The money'];

  final _anchors = List.generate(_labels.length, (_) => GlobalKey());
  int _current = 0;
  double _fill = 0;

  bool _onScroll(ScrollNotification note) {
    if (note.metrics.axis != Axis.vertical) return false;
    final max = note.metrics.maxScrollExtent;
    final fill = max > 0 ? (note.metrics.pixels / max).clamp(0.0, 1.0) : 0.0;

    final viewport = note.context?.findRenderObject() as RenderBox?;
    final viewTop = viewport?.localToGlobal(Offset.zero).dy ?? 0;
    final viewHeight =
        viewport?.size.height ?? MediaQuery.sizeOf(context).height;
    final marker = viewTop + viewHeight * 0.42;

    var index = 0;
    for (var i = 0; i < _anchors.length; i++) {
      final box = _anchors[i].currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.localToGlobal(Offset.zero).dy <= marker) index = i;
    }

    if (index != _current || (fill - _fill).abs() >= 0.004) {
      setState(() {
        _current = index;
        _fill = fill.toDouble();
      });
    }
    return false;
  }

  void _jump(int index) {
    final anchor = _anchors[index].currentContext;
    if (anchor == null) return;
    Scrollable.ensureVisible(
      anchor,
      alignment: 0,
      duration: SwMotion.of(context, SwMotion.deliberate),
      curve: SwMotion.move,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final width = MediaQuery.sizeOf(context).width;
    final wide = isWide(context);
    final phone = width < 640;

    final page = PageFrame(
      child: Padding(
        // Keep the sheet clear of the margin until the viewport is wide
        // enough to hold it in the gutter.
        padding: EdgeInsets.only(
          left: phone ? 12 : (width < 1184 ? 18 : 0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyedSubtree(
              key: _anchors[0],
              child: _Hero(wide: wide, assetLabel: config.assetLabel),
            ),
            SizedBox(height: wide ? 96 : SwSpace.huge),
            _Section(
              anchor: _anchors[1],
              title: 'How a payroll runs',
              lede:
                  'Pick a step to see it on the phone. Arrow keys move between steps.',
              child: const TourTarget(id: 'process', child: ProcessExplorer()),
            ),
            SizedBox(height: wide ? 96 : SwSpace.huge),
            _Section(
              anchor: _anchors[2],
              title: 'Watch it start to finish',
              lede:
                  'A 36-second story: one worker, from a locked payroll to pay in her wallet.',
              child: StoryPlayer(
                finishedLabel: 'Set up payroll',
                onFinishedAction: () => context.go(AppRoute.employer.path),
              ),
            ),
            SizedBox(height: wide ? 96 : SwSpace.huge),
            _Section(
              anchor: _anchors[3],
              title: 'Where the money is',
              child: _MoneyFacts(
                conversionEnabled: config.conversionPair != null,
                assetLabel: config.assetLabel,
              ),
            ),
          ],
        ),
      ),
    );

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          page,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: PageSpine(
                labels: _labels,
                current: _current,
                fill: _fill,
                done: _fill > 0.985,
                railOnly: phone,
                onJump: _jump,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One orchestrated page load, then stillness. The web client runs the same
/// beats from `.home-seq`, at the same delays.
Widget _seq(Widget child, int delayMs, bool reduced) {
  if (reduced) return child;
  return child
      .animate()
      .fadeIn(
        delay: Duration(milliseconds: delayMs),
        duration: const Duration(milliseconds: 520),
        curve: SwMotion.enter,
      )
      .moveY(
        begin: 10,
        end: 0,
        delay: Duration(milliseconds: delayMs),
        duration: const Duration(milliseconds: 520),
        curve: SwMotion.enter,
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide, required this.assetLabel});

  final bool wide;
  final String assetLabel;

  @override
  Widget build(BuildContext context) {
    final intro = _Intro(wide: wide);
    final card = DemoPayCard(assetLabel: assetLabel);
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [intro, const SizedBox(height: SwSpace.xxl), card],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 6, child: intro),
        const SizedBox(width: SwSpace.huge),
        Expanded(flex: 5, child: card),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final reduced = SwMotion.reduced(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seq(
          Text(
            'Every payday, locked in.',
            style: wide
                ? SwType.display.copyWith(fontSize: 60, letterSpacing: -2.2)
                : SwType.display,
          ),
          60,
          reduced,
        ),
        const SizedBox(height: SwSpace.xl),
        _seq(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Sign once to lock a team’s salaries on Stellar. Each person '
              'claims their pay the moment it unlocks, straight to their own '
              'wallet. Sweldo never holds the money.',
              style: SwType.body.copyWith(fontSize: 18, height: 1.5),
            ),
          ),
          180,
          reduced,
        ),
        const SizedBox(height: SwSpace.lg),
        _seq(const LedgerPulse(), 300, reduced),
        const SizedBox(height: SwSpace.xxl),
        _seq(
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
          380,
          reduced,
        ),
        const SizedBox(height: SwSpace.lg),
        _seq(
          SwButton(
            label: 'Watch the 36-second story',
            icon: SwIcons.story,
            tone: SwButtonTone.quiet,
            onPressed: () => context.go(StoryPage.path),
          ),
          460,
          reduced,
        ),
        const SizedBox(height: SwSpace.md),
        _seq(
          Text(
            'Runs on Stellar Testnet with test money. Connect a supported '
            'wallet in your browser or on your phone.',
            style: SwType.bodySmall,
          ),
          520,
          reduced,
        ),
      ],
    );
  }
}

/// A section of the sheet. Its rule draws itself as the paper advances —
/// scroll position drives it, so it runs back the other way when the reader
/// scrolls up. Nothing here fades or slides in on arrival.
class _Section extends StatelessWidget {
  const _Section({
    required this.anchor,
    required this.title,
    required this.child,
    this.lede,
  });

  final Key anchor;
  final String title;
  final String? lede;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Column(
      key: anchor,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: SwType.headline.copyWith(fontSize: wide ? 36 : 28)),
        const SizedBox(height: 10),
        ScrollProgress(
          builder: (context, progress) => SizedBox(
            height: 1,
            child: ColoredBox(
              color: SwColors.rule,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: Curves.easeOutCubic.transform(
                    progress.clamp(0.0, 1.0),
                  ),
                  heightFactor: 1,
                  child: const ColoredBox(color: SwColors.stamp),
                ),
              ),
            ),
          ),
        ),
        if (lede != null) ...[
          const SizedBox(height: SwSpace.sm),
          Text(lede!, style: SwType.body.copyWith(color: SwColors.inkMuted)),
        ],
        const SizedBox(height: SwSpace.xl),
        child,
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
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [stack, const SizedBox(height: SwSpace.xl), paper],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 6, child: paper),
        const SizedBox(width: SwSpace.xxl),
        Expanded(flex: 5, child: stack),
      ],
    );
  }
}

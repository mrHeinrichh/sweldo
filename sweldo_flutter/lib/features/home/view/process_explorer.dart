import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../core/motion/interactive.dart';
import '../../../core/motion/tilt.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/sw_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../story/view/iphone_frame.dart';
import '../../story/view/phone_screens.dart';

enum _Screen { employer, worker, convert }

class _ProcessStep {
  const _ProcessStep(
    this.icon,
    this.title,
    this.body,
    this.screen,
    this.from,
    this.to,
  );

  final IconData icon;
  final String title;
  final String body;
  final _Screen screen;

  /// The stretch of story time this step plays on the phone.
  final double from;
  final double to;

  Duration get duration => Duration(milliseconds: ((to - from) * 1000).round());
}

const _steps = [
  _ProcessStep(
    SwIcons.team,
    'Add your team',
    'A wallet, a name and the total pay for each person.',
    _Screen.employer,
    4.6,
    6.4,
  ),
  _ProcessStep(
    SwIcons.sign,
    'Sign once',
    'Freighter approves one transaction that locks every payout.',
    _Screen.employer,
    6.4,
    10.3,
  ),
  _ProcessStep(
    SwIcons.hourglass,
    'Payday unlocks',
    'Each payout opens on its payday, to the second.',
    _Screen.worker,
    16.9,
    20.6,
  ),
  _ProcessStep(
    SwIcons.claim,
    'Claim in one tap',
    'The worker approves in Freighter and the pay lands in their wallet.',
    _Screen.worker,
    21.3,
    25.4,
  ),
  _ProcessStep(
    SwIcons.convert,
    'Take it in pesos',
    'Or convert USDC to PHPT in the same transaction.',
    _Screen.convert,
    27.0,
    30.4,
  ),
];

/// "How a payroll runs", hands-on: pick a step and a 3D iPhone turns to
/// play it. A short tour runs on its own until someone takes over.
class ProcessExplorer extends StatefulWidget {
  const ProcessExplorer({super.key});

  @override
  State<ProcessExplorer> createState() => _ProcessExplorerState();
}

class _ProcessExplorerState extends State<ProcessExplorer>
    with TickerProviderStateMixin {
  late final AnimationController _play = AnimationController(vsync: this)
    ..addStatusListener(_onPlayStatus);
  int _step = 0;
  bool _touring = false;
  bool _tourStarted = false;
  Timer? _advance;

  @override
  void dispose() {
    _advance?.cancel();
    _play.dispose();
    super.dispose();
  }

  bool get _reduced => SwMotion.reduced(context);

  double get _g {
    final step = _steps[_step];
    return step.from + (step.to - step.from) * _play.value;
  }

  void _select(int index, {bool byPerson = true}) {
    _advance?.cancel();
    if (byPerson) _touring = false;
    setState(() => _step = index.clamp(0, _steps.length - 1));
    _play.duration = _steps[_step].duration;
    if (_reduced) {
      _play.value = 1;
    } else {
      _play.forward(from: 0);
    }
  }

  void _onPlayStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_touring) return;
    _advance = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || !_touring) return;
      _select((_step + 1) % _steps.length, byPerson: false);
    });
  }

  void _onVisible(VisibilityInfo info) {
    if (_tourStarted || info.visibleFraction < 0.35) return;
    _tourStarted = true;
    _touring = !_reduced;
    _select(0, byPerson: false);
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.up(Breakpoint.lg);
    final list = _StepList(selected: _step, progress: _play, onSelect: _select);
    final stage = SizedBox(
      height: context.responsive(470.0, md: 560, lg: 640),
      child: AnimatedBuilder(
        animation: _play,
        builder: (context, _) => _PhoneStage(
          step: _step,
          g: _tourStarted ? _g : _steps.first.to,
          scale: context.responsive(0.48, md: 0.56, lg: 0.64),
        ),
      ),
    );

    return VisibilityDetector(
      key: const ValueKey('process-explorer'),
      onVisibilityChanged: _onVisible,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _select(_step + 1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _select(_step - 1),
        },
        child: FocusTraversalGroup(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: list),
                    const SizedBox(width: SwSpace.xxl),
                    Expanded(flex: 6, child: stage),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stage,
                    const SizedBox(height: SwSpace.lg),
                    list,
                  ],
                ),
        ),
      ),
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({
    required this.selected,
    required this.progress,
    required this.onSelect,
  });

  final int selected;
  final Animation<double> progress;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: SwSpace.sm),
            child: _StepTile(
              index: i,
              step: _steps[i],
              selected: i == selected,
              progress: progress,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.selected,
    required this.progress,
    required this.onTap,
  });

  final int index;
  final _ProcessStep step;
  final bool selected;
  final Animation<double> progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = SwMotion.of(context, const Duration(milliseconds: 250));
    return Interactive(
      onTap: onTap,
      selected: selected,
      semanticLabel: 'Step ${index + 1}: ${step.title}. ${step.body}',
      radius: const BorderRadius.all(SwRadius.panel),
      lift: selected ? 0 : 2,
      builder: (context, state) {
        final hot = selected || state.hovered;
        return AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : state.hovered
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.transparent,
            borderRadius: const BorderRadius.all(SwRadius.panel),
            border: Border.all(
              color: selected ? SwColors.rule : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: SwColors.ink.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: -8,
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(SwSpace.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected ? SwColors.stamp : SwColors.stampWash,
                        borderRadius: const BorderRadius.all(SwRadius.field),
                      ),
                      child: AnimatedScale(
                        duration: duration,
                        curve: Curves.easeOutBack,
                        scale: hot ? 1.1 : 1,
                        child: Icon(
                          step.icon,
                          size: 19,
                          color: selected ? Colors.white : SwColors.stamp,
                        ),
                      ),
                    ),
                    const SizedBox(width: SwSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${step.title}',
                            style: SwType.subtitle.copyWith(
                              color: hot ? SwColors.ink : SwColors.inkMuted,
                            ),
                          ),
                          // The description opens on the selected step.
                          AnimatedSize(
                            duration: duration,
                            curve: Curves.easeOut,
                            alignment: Alignment.topLeft,
                            child: selected
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      step.body,
                                      style: SwType.bodySmall,
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                    AnimatedOpacity(
                      duration: duration,
                      opacity: hot ? 1 : 0,
                      child: AnimatedSlide(
                        duration: duration,
                        offset: hot ? Offset.zero : const Offset(-0.4, 0),
                        child: const Icon(
                          SwIcons.chevronRight,
                          size: 18,
                          color: SwColors.stamp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => LinearProgressIndicator(
                    value: progress.value,
                    minHeight: 3,
                    color: SwColors.stamp,
                    backgroundColor: SwColors.stampWash,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The phone in 3D: extruded body, ground shadow, a swing toward the viewer
/// whenever the step changes, and pointer tilt on top.
class _PhoneStage extends StatelessWidget {
  const _PhoneStage({required this.step, required this.g, required this.scale});

  final int step;
  final double g;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final screen = switch (_steps[step].screen) {
      _Screen.employer => EmployerScreen(g: g),
      _Screen.worker => WorkerScreen(g: g),
      _Screen.convert => ConvertScreen(g: g),
    };
    final size = IPhoneFrame.size;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = size.width * scale;
        final h = size.height * scale;
        return TweenAnimationBuilder<double>(
          key: ValueKey(step),
          tween: Tween(begin: 1, end: 0),
          duration: SwMotion.of(context, const Duration(milliseconds: 900)),
          curve: Curves.easeOutBack,
          builder: (context, swing, _) {
            final baseY = -16 + 34 * swing; // turns in from the right
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ground shadow, wider while the phone swings.
                Positioned(
                  bottom: (constraints.maxHeight - h) / 2 - 18,
                  child: Container(
                    width: w * (0.9 + 0.15 * swing.abs()),
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(200, 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: SwColors.ink.withValues(alpha: 0.22),
                          blurRadius: 28,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                  ),
                ),
                Tilt3D(
                  maxTilt: 9,
                  baseX: 7,
                  baseY: baseY,
                  perspective: 0.0009,
                  radius: BorderRadius.circular(68 * scale),
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: FittedBox(child: _ExtrudedPhone(screen: screen)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The frame plus solid layers behind it, so a turned phone shows a body
/// with thickness instead of a paper-thin card.
class _ExtrudedPhone extends StatelessWidget {
  const _ExtrudedPhone({required this.screen});

  final Widget screen;

  @override
  Widget build(BuildContext context) {
    final size = IPhoneFrame.size;
    const layers = 9;
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = layers; i >= 1; i--)
            Transform(
              // Positive z sits farther from the viewer.
              transform: Matrix4.translationValues(0, 0, i * 3.2),
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFF3A3D46),
                    const Color(0xFF15171C),
                    i / layers,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(68)),
                ),
              ),
            ),
          IPhoneFrame(screen: screen),
          // A thin rim light along the top edge.
          Positioned(
            top: 2,
            left: size.width * 0.18,
            right: size.width * 0.18,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(2)),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0),
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

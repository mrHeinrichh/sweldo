import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/motion.dart';
import '../../core/theme/sw_icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/sw_button.dart';
import '../payroll/bloc/payroll_form/payroll_form_bloc.dart';
import 'tour_controller.dart';

/// The highlighting guide. Dims the app except for a hole around the current
/// target, so the highlighted control stays usable, and explains it in a card
/// that sits beside it (or as a sheet on phones).
class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.currentPath});

  final String currentPath;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => _measure());
  final _overlayKey = GlobalKey();
  final _focus = FocusNode(debugLabel: 'tour');
  Rect? _hole;
  bool _ready = false;
  int _shownIndex = -1;
  int _attempt = 0;

  TourController? get _controller => TourScope.maybeOf(context);

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _controller;
    if (controller == null) return;
    if (!controller.isOpen) {
      if (_ticker.isActive) _ticker.stop();
      _shownIndex = -1;
      return;
    }
    if (!_ticker.isActive) _ticker.start();
    if (controller.index != _shownIndex) {
      _shownIndex = controller.index;
      // Navigation and setState must wait until this frame is built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showStep(controller);
      });
    }
  }

  Future<void> _showStep(TourController controller) async {
    final step = controller.step;
    final attempt = ++_attempt;
    setState(() {
      _ready = false;
      if (step.target == null) _hole = null;
    });
    if (step.route != null && widget.currentPath != step.route) {
      context.go(step.route!);
    }
    if (step.target == null) {
      setState(() => _ready = true);
      _focus.requestFocus();
      return;
    }
    // Wait for the page to build the target.
    BuildContext? target;
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted || attempt != _attempt) return;
      // Open the payroll step that holds the target once the employer page
      // is up (entering it starts a new draft on step one).
      final wanted = step.payrollStep;
      if (wanted != null && widget.currentPath == '/employer') {
        final form = context.read<PayrollFormBloc>();
        if (form.state.step != wanted) {
          form.add(PayrollStepChanged(wanted));
          continue;
        }
      }
      target = controller.keyFor(step.target!)?.currentContext;
      if (target != null) break;
    }
    if (target == null || !target.mounted) {
      controller.skipUnavailable();
      return;
    }
    await Scrollable.ensureVisible(
      target,
      alignment: 0.35,
      duration: SwMotion.of(context, const Duration(milliseconds: 400)),
      curve: SwMotion.move,
    );
    if (!mounted || attempt != _attempt) return;
    setState(() => _ready = true);
    _focus.requestFocus();
  }

  void _measure() {
    final controller = _controller;
    final id = controller?.step.target;
    if (controller == null || id == null) return;
    final targetBox =
        controller.keyFor(id)?.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null || overlayBox == null || !targetBox.attached) return;
    final topLeft = targetBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final rect = (topLeft & targetBox.size).inflate(8);
    if (_hole == null ||
        (rect.topLeft - _hole!.topLeft).distance > 0.5 ||
        (rect.size.width - _hole!.width).abs() > 0.5 ||
        (rect.size.height - _hole!.height).abs() > 0.5) {
      setState(() => _hole = rect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.isOpen) {
      return const SizedBox.shrink();
    }
    final step = controller.step;
    final duration = SwMotion.of(context, const Duration(milliseconds: 350));
    final hole = step.target == null ? null : _hole;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): controller.next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): controller.back,
        const SingleActivator(LogicalKeyboardKey.escape): controller.finish,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: LayoutBuilder(
          key: _overlayKey,
          builder: (context, constraints) {
            final size = constraints.biggest;
            final shade = SwColors.ink.withValues(alpha: 0.6);
            final children = <Widget>[];

            if (hole == null) {
              children.add(Positioned.fill(child: _Shade(color: shade)));
            } else {
              final h = hole;
              children.addAll([
                _pane(duration, 0, 0, size.width, math.max(0, h.top), shade),
                _pane(
                  duration,
                  h.bottom,
                  0,
                  size.width,
                  math.max(0, size.height - h.bottom),
                  shade,
                ),
                _pane(duration, h.top, 0, math.max(0, h.left), h.height, shade),
                _pane(
                  duration,
                  h.top,
                  h.right,
                  math.max(0, size.width - h.right),
                  h.height,
                  shade,
                ),
                AnimatedPositioned(
                  duration: duration,
                  curve: SwMotion.move,
                  left: h.left,
                  top: h.top,
                  width: h.width,
                  height: h.height,
                  child: const IgnorePointer(child: _Ring()),
                ),
              ]);
            }
            children.add(
              _card(context, controller, step, hole, size, duration),
            );
            return Stack(children: children);
          },
        ),
      ),
    );
  }

  Widget _pane(
    Duration duration,
    double top,
    double left,
    double width,
    double height,
    Color color,
  ) {
    return AnimatedPositioned(
      duration: duration,
      curve: SwMotion.move,
      top: top,
      left: left,
      width: width,
      height: height,
      child: _Shade(color: color),
    );
  }

  Widget _card(
    BuildContext context,
    TourController controller,
    TourStep step,
    Rect? hole,
    Size size,
    Duration duration,
  ) {
    const width = 360.0;
    const estimatedHeight = 230.0;
    final compact = size.width < 640;
    final card = _TourCard(
      key: ValueKey(controller.index),
      controller: controller,
      ready: _ready,
    );

    if (compact) {
      return Positioned(
        left: 12,
        right: 12,
        bottom: 12 + MediaQuery.paddingOf(context).bottom,
        child: card,
      );
    }
    if (hole == null) {
      return Center(child: SizedBox(width: 420, child: card));
    }
    final below = hole.bottom + 14;
    final top = below + estimatedHeight < size.height - 12
        ? below
        : math.max(12.0, hole.top - estimatedHeight - 14);
    final left = (hole.center.dx - width / 2)
        .clamp(12.0, math.max(12.0, size.width - width - 12))
        .toDouble();
    return AnimatedPositioned(
      duration: duration,
      curve: SwMotion.move,
      top: top,
      left: left,
      width: width,
      child: card,
    );
  }
}

/// Dims and swallows taps outside the spotlight.
class _Shade extends StatelessWidget {
  const _Shade({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(color: color),
    );
  }
}

class _Ring extends StatefulWidget {
  const _Ring();

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SwMotion.reduced(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = math.sin(_pulse.value * math.pi);
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(SwRadius.panel),
            border: Border.all(color: const Color(0xFFA996FF), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFA996FF).withValues(alpha: 0.3 - 0.2 * t),
                spreadRadius: 4 + 6 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({super.key, required this.controller, required this.ready});

  final TourController controller;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final step = controller.step;
    final total = controller.steps.length;
    final duration = SwMotion.of(context, const Duration(milliseconds: 220));
    return AnimatedOpacity(
      duration: duration,
      opacity: ready ? 1 : 0,
      child: AnimatedSlide(
        duration: duration,
        curve: Curves.easeOut,
        offset: ready ? Offset.zero : const Offset(0, 0.04),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: 'Guide, step ${controller.index + 1} of $total',
          child: Material(
            color: Colors.white,
            elevation: 12,
            shadowColor: SwColors.ink.withValues(alpha: 0.4),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(SwRadius.sheet),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        SwIcons.guide,
                        size: 14,
                        color: SwColors.stamp,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${controller.index + 1} of $total',
                        style: SwType.caption.copyWith(
                          color: SwColors.stamp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close the guide',
                        visualDensity: VisualDensity.compact,
                        onPressed: controller.finish,
                        icon: const Icon(SwIcons.close, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: (controller.index + 1) / total),
                      duration: SwMotion.of(context, SwMotion.standard),
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 4,
                        backgroundColor: SwColors.stampWash,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    step.title,
                    style: SwType.subtitle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(step.body, style: SwType.bodySmall),
                  if (step.tryIt != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: const BoxDecoration(
                        color: SwColors.stampWash,
                        borderRadius: BorderRadius.all(SwRadius.field),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            SwIcons.pointer,
                            size: 15,
                            color: SwColors.stampDeep,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step.tryIt!,
                              style: SwType.caption.copyWith(
                                color: SwColors.stampDeep,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (controller.index == 0)
                        SwButton(
                          label: 'Skip',
                          tone: SwButtonTone.secondary,
                          onPressed: controller.finish,
                        )
                      else
                        SwButton(
                          label: 'Back',
                          icon: SwIcons.back,
                          tone: SwButtonTone.secondary,
                          onPressed: controller.back,
                        ),
                      const SizedBox(width: SwSpace.sm),
                      SwButton(
                        label: controller.isLast ? 'Done' : 'Next',
                        icon: controller.isLast
                            ? SwIcons.check
                            : SwIcons.forward,
                        onPressed: controller.next,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

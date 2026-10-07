import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Tailwind's `animate-ping`: a solid dot with a ring that keeps radiating.
/// Used for "live" signals: Testnet connection and pay that's ready now.
class PingDot extends StatefulWidget {
  const PingDot({super.key, this.color = SwColors.payday, this.size = 8});

  final Color color;
  final double size;

  @override
  State<PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<PingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SwMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              // cubic-bezier(0, 0, 0.2, 1), scale 1 → 2.2, opacity .75 → 0
              final t = const Cubic(0, 0, 0.2, 1).transform(_controller.value);
              return Transform.scale(
                scale: 1 + 1.2 * t,
                child: Opacity(opacity: 0.75 * (1 - t), child: dot),
              );
            },
          ),
          dot,
        ],
      ),
    );
  }
}

/// Tailwind's `animate-pulse` placeholder for content that is loading.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: SwColors.greenbar,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    );
    if (SwMotion.reduced(context)) return box;
    return FadeTransition(
      opacity: Tween(
        begin: 1.0,
        end: 0.45,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: box,
    );
  }
}

/// A card with two faces that turns over in 3D when [flipped] changes.
class FlipCard extends StatelessWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.flipped,
    this.duration = const Duration(milliseconds: 700),
    this.vertical = false,
  });

  final Widget front;
  final Widget back;
  final bool flipped;
  final Duration duration;

  /// Turn over the top edge (a split-flap board) instead of the side.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? math.pi : 0),
      duration: SwMotion.of(context, duration),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, _) {
        final showBack = angle > math.pi / 2;
        // Lift toward the viewer mid-turn, so the card reads as an object.
        final lift = math.sin(angle) * 0.06;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateY(vertical ? 0 : angle)
            ..rotateX(vertical ? angle : 0)
            ..scaleByDouble(1 + lift, 1 + lift, 1, 1),
          child: showBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: vertical
                      ? Matrix4.rotationX(math.pi)
                      : Matrix4.rotationY(math.pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}

/// Fades and rises a section into place the first time it scrolls into
/// view. Reserved for the few home-page sections that introduce a new idea.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  final _key = UniqueKey();
  bool _shown = false;

  void _onVisibility(VisibilityInfo info) {
    if (_shown || info.visibleFraction < 0.12) return;
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (SwMotion.reduced(context)) return widget.child;
    return VisibilityDetector(
      key: _key,
      onVisibilityChanged: _onVisibility,
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: _shown ? Offset.zero : const Offset(0, 0.04),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

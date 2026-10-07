import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Continuous-form payroll paper: a tractor-feed edge with sprocket holes and
/// greenbar banding on alternate rows. Sweldo uses it wherever a list *is* a
/// pay schedule.
class PayrollPaper extends StatelessWidget {
  const PayrollPaper({
    super.key,
    required this.children,
    this.header,
    this.elevated = false,
  });

  final Widget? header;
  final List<Widget> children;

  /// Only the home-screen demo card floats; everywhere else paper lies flat.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(SwRadius.card),
        border: Border.all(color: SwColors.rule),
        boxShadow: elevated
            ? const [
                BoxShadow(
                  color: Color(0x1A14213A),
                  blurRadius: 32,
                  offset: Offset(0, 18),
                  spreadRadius: -12,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(SwRadius.card),
        child: CustomPaint(
          painter: const _TractorFeedPainter(),
          child: Padding(
            padding: const EdgeInsets.only(left: _TractorFeedPainter.margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                for (var i = 0; i < children.length; i++)
                  ColoredBox(
                    color: i.isEven ? SwColors.greenbar : Colors.white,
                    child: children[i],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TractorFeedPainter extends CustomPainter {
  const _TractorFeedPainter();

  static const margin = 22.0;
  static const _pitch = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Paint()..color = SwColors.paper;
    final rim = Paint()
      ..color = SwColors.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var y = _pitch / 2; y < size.height; y += _pitch) {
      canvas.drawCircle(Offset(margin / 2, y), 3.6, hole);
      canvas.drawCircle(Offset(margin / 2, y), 3.6, rim);
    }
    // Perforation line between the feed strip and the form.
    final perforation = Paint()
      ..color = SwColors.rule
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(
        Offset(margin, y),
        Offset(margin, math.min(y + 3, size.height)),
        perforation,
      );
    }
  }

  @override
  bool shouldRepaint(_TractorFeedPainter oldDelegate) => false;
}

/// The column header printed at the top of the payroll paper.
class PaperHeader extends StatelessWidget {
  const PaperHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SwSpace.lg,
        SwSpace.md,
        SwSpace.lg,
        SwSpace.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SwColors.rule)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: SwType.subtitle)),
          ?trailing,
        ],
      ),
    );
  }
}

/// A violet rubber stamp. Lands with a thump when [animate] is true.
class ClaimedStamp extends StatelessWidget {
  const ClaimedStamp({
    super.key,
    this.label = 'Claimed',
    this.animate = false,
    this.color = SwColors.stamp,
  });

  final String label;
  final bool animate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final stamp = Transform.rotate(
      angle: -0.14,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.85), width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.85)),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: Text(
            label,
            style: SwType.label.copyWith(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
    if (!animate || SwMotion.reduced(context)) return stamp;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: SwMotion.deliberate,
      curve: SwMotion.enter,
      builder: (context, t, child) {
        final scale = 1.9 - 0.9 * SwMotion.stamp.transform(t);
        return Opacity(
          opacity: Curves.easeOut.transform(math.min(1, t * 2.5)),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: stamp,
    );
  }
}

/// The punch slot at the start of a payout row: empty while locked, ringed
/// when payday has come, punched through once claimed.
enum PunchState { locked, ready, punched }

class PunchSlot extends StatelessWidget {
  const PunchSlot({super.key, required this.state});

  final PunchState state;

  @override
  Widget build(BuildContext context) {
    final (fill, border) = switch (state) {
      PunchState.locked => (
        Colors.white,
        SwColors.locked.withValues(alpha: 0.45),
      ),
      PunchState.ready => (SwColors.paydayWash, SwColors.payday),
      PunchState.punched => (SwColors.stamp, SwColors.stamp),
    };
    return AnimatedContainer(
      duration: SwMotion.of(context, SwMotion.standard),
      curve: SwMotion.enter,
      width: 14,
      height: 22,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(7)),
        border: Border.all(color: border, width: 1.5),
      ),
    );
  }
}

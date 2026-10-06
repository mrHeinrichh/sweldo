import 'dart:async';

import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Desktop layout from Tailwind's `lg` breakpoint (1024px) up.
bool isWide(BuildContext context) => context.up(Breakpoint.lg);

/// Centers page content and caps its width.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    // px-4 sm:px-6 lg:px-8
    final gutter = context.responsive(
      SwSpace.lg,
      sm: SwSpace.xl,
      lg: SwSpace.xxl,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: SwBreakpoints.maxContent),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}

/// A flat surface for forms and lists. No shadow: hierarchy comes from the
/// rule and the radius, not from depth.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SwSpace.xl),
    this.color = SwColors.sheet,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(SwRadius.panel),
        border: Border.all(color: SwColors.rule),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A heading with an optional line of explanation underneath.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.style,
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: style ?? SwType.title),
              if (description != null) ...[
                const SizedBox(height: SwSpace.xs),
                Text(description!, style: SwType.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: SwSpace.md), trailing!],
      ],
    );
  }
}

/// Rebuilds once a second with the current time. Used by countdowns so a
/// whole page doesn't have to tick.
class SecondTicker extends StatefulWidget {
  const SecondTicker({super.key, required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<SecondTicker> createState() => _SecondTickerState();
}

class _SecondTickerState extends State<SecondTicker> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

import 'package:flutter/widgets.dart';

/// Tailwind's breakpoints, mobile first: a value set for `md` applies from
/// 768px up until something larger overrides it.
enum Breakpoint {
  base(0),
  sm(640),
  md(768),
  lg(1024),
  xl(1280),
  xxl(1536);

  const Breakpoint(this.minWidth);
  final double minWidth;

  static Breakpoint of(double width) =>
      values.lastWhere((bp) => width >= bp.minWidth);
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  Breakpoint get breakpoint => Breakpoint.of(screenWidth);

  /// `true` from [bp] up, like Tailwind's `md:` prefix.
  bool up(Breakpoint bp) => screenWidth >= bp.minWidth;

  /// Picks the value for the current width, cascading upward like
  /// `class="p-4 sm:p-6 lg:p-8"`.
  T responsive<T>(T base, {T? sm, T? md, T? lg, T? xl}) {
    final w = screenWidth;
    if (xl != null && w >= Breakpoint.xl.minWidth) return xl;
    if (lg != null && w >= Breakpoint.lg.minWidth) return lg;
    if (md != null && w >= Breakpoint.md.minWidth) return md;
    if (sm != null && w >= Breakpoint.sm.minWidth) return sm;
    return base;
  }
}

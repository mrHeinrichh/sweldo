import 'package:flutter/widgets.dart';

/// Motion answers what a person did. The only unprompted motion in the app is
/// the payroll card printing in on the home screen.
abstract final class SwMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 280);
  static const deliberate = Duration(milliseconds: 480);
  static const print = Duration(milliseconds: 420);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const move = Curves.easeInOutCubic;

  /// The stamp lands hard, then settles.
  static const stamp = Cubic(0.2, 1.6, 0.4, 1);

  /// Whether the platform asked to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when reduced motion is on.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

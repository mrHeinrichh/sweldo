import 'package:flutter/animation.dart';

/// One beat of the story: words print first, then animation takes over.
class StoryScene {
  const StoryScene({
    required this.start,
    required this.end,
    required this.lines,
    required this.caption,
    this.quietFrom = 99,
  });

  /// Seconds from the start of the story.
  final double start;
  final double end;

  /// Printed lines, in order.
  final List<String> lines;

  /// Lines from this index on are set quieter, as a follow-up thought.
  final int quietFrom;

  /// Plain-language description for screen readers and reduced motion.
  final String caption;

  double get duration => end - start;

  /// The frame that best summarises the scene, used as a still.
  double get keyFrame => end - 0.7;
}

/// "Ana gets paid": the whole product in 36 seconds.
abstract final class StoryScript {
  static const scenes = [
    StoryScene(
      start: 0,
      end: 4.5,
      lines: ['Ana gets paid', 'every month.', 'Some paydays came late.'],
      quietFrom: 2,
      caption: 'Ana is paid monthly, and some of her paydays came late.',
    ),
    StoryScene(
      start: 4.5,
      end: 11,
      lines: ['Her employer', 'locks six paydays.', 'One signature does it.'],
      quietFrom: 2,
      caption:
          'Her employer opens Sweldo, sets six monthly payouts, and signs '
          'once in Freighter. The payroll is locked.',
    ),
    StoryScene(
      start: 11,
      end: 16,
      lines: [
        'The money waits',
        'on Stellar.',
        'Not with Sweldo.',
        'Not with her employer.',
      ],
      quietFrom: 2,
      caption:
          'Six time-locked payouts sit on the Stellar ledger. Nobody can '
          'take them early.',
    ),
    StoryScene(
      start: 16,
      end: 21,
      lines: ['Payday arrives', 'to the second.'],
      caption:
          "On Ana's phone, the countdown reaches zero and her first payout "
          'turns ready to claim.',
    ),
    StoryScene(
      start: 21,
      end: 26.5,
      lines: ['One tap.', 'Her pay is in her wallet.'],
      quietFrom: 1,
      caption:
          'Ana taps Claim, approves in Freighter, and 300 USDC lands in '
          'her wallet. The payout is stamped claimed.',
    ),
    StoryScene(
      start: 26.5,
      end: 31.5,
      lines: ['Next month,', 'she takes pesos.', 'Converted on Stellar.'],
      quietFrom: 2,
      caption:
          'The next payday she claims as PHPT, converted through '
          "Stellar's built-in exchange in the same transaction.",
    ),
    StoryScene(
      start: 31.5,
      end: 36,
      lines: ['Sweldo.', 'Payroll that keeps its promise.'],
      quietFrom: 1,
      caption: 'Sweldo: payroll that keeps its promise.',
    ),
  ];

  static double get total => scenes.last.end;

  static int sceneAt(double seconds) {
    for (var i = 0; i < scenes.length; i++) {
      if (seconds < scenes[i].end) return i;
    }
    return scenes.length - 1;
  }
}

/// Progress of [g] through the window [a, b], clamped to 0…1.
double seg(double g, double a, double b) =>
    b <= a ? (g >= b ? 1 : 0) : ((g - a) / (b - a)).clamp(0.0, 1.0);

double easeOut(double t) => Curves.easeOutCubic.transform(t);
double easeInOut(double t) => Curves.easeInOutCubic.transform(t);
double easeBack(double t) => Curves.easeOutBack.transform(t);

/// 0 → 1 → 0 over the window, for flashes like a tap.
double pulse(double g, double a, double b) {
  final t = seg(g, a, b);
  return t <= 0 || t >= 1 ? 0 : (t < 0.3 ? t / 0.3 : (1 - t) / 0.7);
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../domain/story_script.dart';
import 'iphone_frame.dart';
import 'phone_screens.dart';
import '../../../core/theme/sw_icons.dart';

/// Fixed-size stages, scaled to fit by the player.
enum StageFormat {
  landscape(Size(1280, 720)),
  portrait(Size(720, 1080));

  const StageFormat(this.size);
  final Size size;
}

/// One frame of the story at time [g] (seconds). The whole film is printed
/// on continuous-form payroll paper: lines print in, and between scenes the
/// paper feeds up to make room for the next.
class StoryStage extends StatelessWidget {
  const StoryStage({super.key, required this.g, required this.format});

  final double g;
  final StageFormat format;

  bool get _landscape => format == StageFormat.landscape;

  /// How far the paper has advanced: one band pair per scene change.
  double get _feed {
    var feed = 0.0;
    for (final scene in StoryScript.scenes.skip(1)) {
      feed += 96 * easeInOut(seg(g, scene.start - 0.5, scene.start));
    }
    return feed;
  }

  @override
  Widget build(BuildContext context) {
    final size = format.size;
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _PaperPainter(feed: _feed)),
          ),
          for (var i = 0; i < StoryScript.scenes.length; i++)
            _SceneWords(
              scene: StoryScript.scenes[i],
              index: i,
              g: g,
              landscape: _landscape,
            ),
          _LatePayslip(g: g, landscape: _landscape),
          _Ledger(g: g, landscape: _landscape),
          _Phone(g: g, landscape: _landscape),
        ],
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter({required this.feed});

  final double feed;
  static const _band = 48.0;
  static const _margin = 34.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = SwColors.paper);
    final band = Paint()..color = SwColors.greenbar.withValues(alpha: 0.7);
    final offset = -(feed % (_band * 2));
    for (var y = offset; y < size.height; y += _band * 2) {
      canvas.drawRect(
        Rect.fromLTWH(_margin, y, size.width - _margin * 2, _band),
        band,
      );
    }
    // Tractor-feed strips on both edges, moving with the paper.
    final hole = Paint()..color = Colors.white;
    final rim = Paint()
      ..color = SwColors.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final holeOffset = -(feed % 24);
    for (var y = holeOffset + 12; y < size.height; y += 24) {
      for (final x in [_margin / 2, size.width - _margin / 2]) {
        canvas.drawCircle(Offset(x, y), 5, hole);
        canvas.drawCircle(Offset(x, y), 5, rim);
      }
    }
    final perf = Paint()
      ..color = SwColors.rule
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 8) {
      for (final x in [_margin, size.width - _margin]) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 4), perf);
      }
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) => old.feed != feed;
}

/// A scene's lines, printed one after another with a print head running
/// along each, then fed up and away as the scene ends.
class _SceneWords extends StatelessWidget {
  const _SceneWords({
    required this.scene,
    required this.index,
    required this.g,
    required this.landscape,
  });

  final StoryScene scene;
  final int index;
  final double g;
  final bool landscape;

  bool get _outro => index == StoryScript.scenes.length - 1;

  @override
  Widget build(BuildContext context) {
    if (g < scene.start - 0.01 || g > scene.end + 0.01) {
      return const SizedBox.shrink();
    }
    // Last scene holds its words on screen.
    final exit = _outro ? 0.0 : easeInOut(seg(g, scene.end - 0.5, scene.end));
    final first = landscape ? 58.0 : 56.0;
    final rest = landscape ? 40.0 : 38.0;

    final lines = <Widget>[];
    for (var i = 0; i < scene.lines.length; i++) {
      final a = scene.start + 0.25 + i * 0.75;
      final printed = seg(g, a, a + 0.6);
      final quiet = i >= scene.quietFrom;
      final fontSize = _outro
          ? (i == 0 ? (landscape ? 120.0 : 104.0) : (landscape ? 44.0 : 32.0))
          : (quiet ? rest : first);
      lines.add(
        _PrintedLine(
          text: scene.lines[i],
          printed: printed,
          style: SwType.display.copyWith(
            fontSize: fontSize,
            height: 1.06,
            letterSpacing: fontSize > 80 ? -4 : -1.6,
            color: quiet ? SwColors.inkMuted : SwColors.ink,
            fontWeight: quiet ? FontWeight.w700 : FontWeight.w800,
          ),
        ),
      );
    }

    final left = landscape ? 88.0 : 64.0;
    final top = landscape ? (_outro ? 200.0 : 170.0) : 92.0;
    final width = landscape ? (_outro ? 1000.0 : 600.0) : 600.0;
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: Transform.translate(
        offset: Offset(0, -140 * exit),
        child: Opacity(
          opacity: 1 - exit,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: line),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrintedLine extends StatelessWidget {
  const _PrintedLine({
    required this.text,
    required this.printed,
    required this.style,
  });

  final String text;
  final double printed;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (printed <= 0) return SizedBox(height: style.fontSize! * 1.06);
    final printing = printed < 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: printed,
              child: Transform.translate(
                offset: Offset(0, 6 * (1 - easeOut(printed))),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(text, style: style, maxLines: 1, softWrap: false),
                ),
              ),
            ),
          ),
        ),
        // The print head rides the edge of the line while it prints.
        if (printing)
          Container(
            width: 5,
            height: style.fontSize! * 0.9,
            margin: const EdgeInsets.only(left: 4),
            color: SwColors.stamp,
          ),
      ],
    );
  }
}

/// Scene 1: the old way. A payslip arrives, its payday slips, and it gets
/// stamped late.
class _LatePayslip extends StatelessWidget {
  const _LatePayslip({required this.g, required this.landscape});

  final double g;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final s = StoryScript.scenes.first;
    if (g < s.start + 0.6 || g > s.end + 0.05) return const SizedBox.shrink();
    final enter = easeBack(seg(g, s.start + 0.6, s.start + 1.3));
    final slip = easeOut(seg(g, 2.4, 2.9));
    final stamp = seg(g, 2.9, 3.4);
    final exit = easeInOut(seg(g, s.end - 0.5, s.end));

    const w = 380.0, h = 236.0;
    final left = landscape ? 930 - w / 2 : (720 - w) / 2;
    final top = landscape ? 230.0 : 430.0;
    final payday = SwType.amount.copyWith(fontSize: 26);

    return Positioned(
      left: left,
      top: top - 120 * (1 - enter) - 140 * exit,
      child: Opacity(
        opacity: math.min(1, enter * 2) * (1 - exit),
        child: Transform.rotate(
          angle: -0.04 + (1 - enter) * 0.1,
          child: Container(
            width: w,
            height: h,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(SwRadius.card),
              border: Border.all(color: SwColors.rule),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A14213A),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payslip',
                      style: SwType.label.copyWith(color: SwColors.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Text('Ana Santos', style: SwType.title),
                    const Spacer(),
                    Text('Payday', style: SwType.caption),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Text(
                              'Oct 30',
                              style: payday.copyWith(
                                color: Color.lerp(
                                  SwColors.ink,
                                  SwColors.inkFaint,
                                  slip,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              top: 17,
                              child: Container(
                                width: 92 * slip,
                                height: 3,
                                color: SwColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Opacity(
                          opacity: slip,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - slip)),
                            child: Text(
                              'Nov 6?',
                              style: payday.copyWith(color: SwColors.danger),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (stamp > 0)
                  Positioned(
                    right: 0,
                    top: 6,
                    child: Opacity(
                      opacity: math.min(1, stamp * 2.5),
                      child: Transform.scale(
                        scale:
                            1.9 -
                            0.9 *
                                const Cubic(0.2, 1.6, 0.4, 1).transform(stamp),
                        child: Transform.rotate(
                          angle: -0.14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: SwColors.danger,
                                width: 2.5,
                              ),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(6),
                              ),
                            ),
                            child: Text(
                              'Late',
                              style: SwType.title.copyWith(
                                color: SwColors.danger,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scene 3: six payouts drop onto the ledger and lock.
class _Ledger extends StatelessWidget {
  const _Ledger({required this.g, required this.landscape});

  final double g;
  final bool landscape;

  static const _months = ['Nov 3', 'Dec 3', 'Jan 3', 'Feb 3', 'Mar 3', 'Apr 3'];

  @override
  Widget build(BuildContext context) {
    const scene = 2;
    final s = StoryScript.scenes[scene];
    if (g < s.start + 0.3 || g > s.end + 0.05) return const SizedBox.shrink();
    final exit = easeInOut(seg(g, s.end - 0.5, s.end));

    final columns = landscape ? 3 : 2;
    const cardW = 172.0, cardH = 128.0, gap = 18.0;
    final gridW = columns * cardW + (columns - 1) * gap;
    final origin = landscape
        ? const Offset(700, 210)
        : Offset((720 - gridW) / 2, 430);

    return Positioned.fill(
      child: Opacity(
        opacity: 1 - exit,
        child: Transform.translate(
          offset: Offset(0, -140 * exit),
          child: Stack(
            children: [
              Positioned(
                left: origin.dx,
                top: origin.dy - 46,
                child: Opacity(
                  opacity: seg(g, s.start + 0.3, s.start + 0.7),
                  child: Text(
                    'Stellar ledger, Testnet',
                    style: SwType.label.copyWith(color: SwColors.inkMuted),
                  ),
                ),
              ),
              for (var i = 0; i < 6; i++)
                _ticket(i, origin, columns, cardW, cardH, gap, s.start),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ticket(
    int i,
    Offset origin,
    int columns,
    double w,
    double h,
    double gap,
    double start,
  ) {
    final dropAt = start + 0.6 + i * 0.28;
    final drop = seg(g, dropAt, dropAt + 0.55);
    if (drop <= 0) return const SizedBox.shrink();
    final lock = seg(g, dropAt + 0.5, dropAt + 0.8);
    final col = i % columns, row = i ~/ columns;
    final x = origin.dx + col * (w + gap);
    final y = origin.dy + row * (h + gap) - 220 * (1 - easeBack(drop));
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        opacity: math.min(1, drop * 2.5),
        child: Transform.rotate(
          angle: (1 - easeOut(drop)) * (i.isEven ? -0.12 : 0.1),
          child: Container(
            width: w,
            height: h,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(SwRadius.card),
              border: Border.all(color: SwColors.rule),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1414213A),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_months[i], style: SwType.label),
                    const Spacer(),
                    Opacity(
                      opacity: lock,
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * easeBack(lock),
                        child: const Icon(
                          SwIcons.locked,
                          size: 20,
                          color: SwColors.stamp,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text('300 USDC', style: SwType.amount.copyWith(fontSize: 26)),
                Text('Locked until payday', style: SwType.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The iPhone: in for the employer, out for the ledger, back for Ana.
class _Phone extends StatelessWidget {
  const _Phone({required this.g, required this.landscape});

  final double g;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final presence = math.max(
      seg(g, 5.0, 5.8) - seg(g, 10.5, 11.1),
      seg(g, 16.0, 16.8) - seg(g, 31.4, 32.2),
    );
    if (presence <= 0) return const SizedBox.shrink();
    final p = easeOut(presence);

    final scale = landscape ? 0.76 : 0.78;
    final frame = IPhoneFrame.size;
    final left = landscape
        ? 930 - frame.width * scale / 2
        : 360 - frame.width * scale / 2;
    final top = landscape ? (720 - frame.height * scale) / 2 : 262.0;

    // Screens push left like an iOS navigation between Ana's pay and the
    // conversion sheet.
    final push = easeInOut(seg(g, 26.5, 27.0));
    final Widget screen;
    if (g < 13) {
      screen = EmployerScreen(g: g);
    } else if (push <= 0) {
      screen = WorkerScreen(g: g);
    } else if (push >= 1) {
      screen = ConvertScreen(g: g);
    } else {
      screen = Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(-130 * push, 0),
              child: WorkerScreen(g: g),
            ),
          ),
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(IPhoneFrame.screenSize.width * (1 - push), 0),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: Color(0x2214213A), blurRadius: 24),
                  ],
                ),
                child: ConvertScreen(g: g),
              ),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: left,
      top: top + (1 - p) * 520,
      child: Opacity(
        opacity: math.min(1, presence * 1.6),
        child: Transform.rotate(
          angle: (1 - p) * 0.09,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: IPhoneFrame(screen: screen),
          ),
        ),
      ),
    );
  }
}

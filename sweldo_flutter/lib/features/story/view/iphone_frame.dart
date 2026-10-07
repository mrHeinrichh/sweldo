import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/sw_icons.dart';

/// An iPhone-shaped device frame (6.1" class, 390 × 844 points) with a
/// Dynamic Island, side buttons, status bar and home indicator.
class IPhoneFrame extends StatelessWidget {
  const IPhoneFrame({super.key, required this.screen, this.time = '9:41'});

  static const screenSize = Size(390, 844);
  static const _bezel = 13.0;
  static const size = Size(390 + _bezel * 2, 844 + _bezel * 2);

  final Widget screen;
  final String time;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Side buttons sit just outside the body.
          _button(left: true, top: 150, height: 34),
          _button(left: true, top: 210, height: 64),
          _button(left: true, top: 288, height: 64),
          _button(left: false, top: 240, height: 100),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1B1D24),
              borderRadius: const BorderRadius.all(Radius.circular(68)),
              border: Border.all(color: const Color(0xFF4A4E59), width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3314213A),
                  blurRadius: 60,
                  offset: Offset(0, 30),
                  spreadRadius: -16,
                ),
              ],
            ),
            padding: const EdgeInsets.all(_bezel - 2.5),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(56)),
              child: SizedBox.fromSize(
                size: screenSize,
                child: Stack(
                  children: [
                    Positioned.fill(child: screen),
                    _StatusBar(time: time),
                    Positioned(
                      top: 11,
                      left: (screenSize.width - 124) / 2,
                      child: Container(
                        width: 124,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: (screenSize.width - 134) / 2,
                      child: Container(
                        width: 134,
                        height: 5,
                        decoration: BoxDecoration(
                          color: SwColors.ink.withValues(alpha: 0.85),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button({
    required bool left,
    required double top,
    required double height,
  }) {
    return Positioned(
      top: top,
      left: left ? -3 : null,
      right: left ? null : -3,
      child: Container(
        width: 5,
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFF3A3D46),
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.time});

  final String time;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Archivo',
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: SwColors.ink,
    );
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 16, 30, 0),
        child: Row(
          children: [
            Text(time, style: style),
            const Spacer(),
            const Icon(SwIcons.signal, size: 17, color: SwColors.ink),
            const SizedBox(width: 5),
            const Icon(SwIcons.wifi, size: 17, color: SwColors.ink),
            const SizedBox(width: 6),
            Container(
              width: 26,
              height: 12.5,
              padding: const EdgeInsets.all(1.6),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                border: Border.all(
                  color: SwColors.ink.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: SwColors.ink,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

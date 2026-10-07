import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../motion/interactive.dart';

/// The original Sweldo mark: a banknote on a violet tile, and the "sweldo."
/// wordmark set in Manrope ExtraBold with a violet full stop.
abstract final class SweldoBrand {
  static const violetLight = Color(0xFF8069EE);
  static const violetDark = Color(0xFF5C43CF);
  static const violet = Color(0xFF7157E8);
  static const wordmarkInk = Color(0xFF1D1A26);
}

class SweldoMark extends StatelessWidget {
  const SweldoMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.29),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SweldoBrand.violetLight, SweldoBrand.violetDark],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF664DD5).withValues(alpha: 0.25),
            blurRadius: size * 0.47,
            offset: Offset(0, size * 0.18),
          ),
        ],
      ),
      child: Icon(LucideIcons.banknote, color: Colors.white, size: size * 0.62),
    );
  }
}

class SweldoLogo extends StatelessWidget {
  const SweldoLogo({
    super.key,
    this.onTap,
    this.compact = false,
    this.size = 34,
  });

  final VoidCallback? onTap;
  final bool compact;
  final double size;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SweldoMark(size: size),
        if (!compact) ...[
          SizedBox(width: size * 0.27),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'sweldo'),
                TextSpan(
                  text: '.',
                  style: TextStyle(color: SweldoBrand.violet),
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w800,
              fontSize: size * 0.66,
              letterSpacing: -size * 0.03,
              height: 1,
              color: SweldoBrand.wordmarkInk,
            ),
          ),
        ],
      ],
    );
    if (onTap == null) return content;
    return Interactive(
      onTap: onTap,
      lift: 0,
      hoverShadow: false,
      semanticLabel: 'Sweldo home',
      radius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.all(2), child: content),
    );
  }
}

import 'package:flutter/material.dart';

import '../motion/interactive.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

enum SwButtonTone { primary, payday, secondary, quiet, danger }

/// The single button component, with Tailwind-style states:
/// `hover:-translate-y-px hover:shadow-[color]/25 active:scale-[.97]
///  focus-visible:ring-2` and an icon that nudges on hover.
class SwButton extends StatelessWidget {
  const SwButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = SwButtonTone.primary,
    this.loading = false,
    this.expand = false,
    this.large = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final SwButtonTone tone;
  final bool loading;
  final bool expand;
  final bool large;
  final String? tooltip;

  ({Color bg, Color bgHover, Color fg, Color border, Color glow})
  get _palette => switch (tone) {
    SwButtonTone.primary => (
      bg: SwColors.stamp,
      bgHover: SwColors.stampDeep,
      fg: Colors.white,
      border: SwColors.stamp,
      glow: SwColors.stamp,
    ),
    SwButtonTone.payday => (
      bg: SwColors.payday,
      bgHover: const Color(0xFF155C3A),
      fg: Colors.white,
      border: SwColors.payday,
      glow: SwColors.payday,
    ),
    SwButtonTone.secondary => (
      bg: Colors.white,
      bgHover: Colors.white,
      fg: SwColors.ink,
      border: SwColors.rule,
      glow: SwColors.ink,
    ),
    SwButtonTone.quiet => (
      bg: Colors.transparent,
      bgHover: SwColors.stampWash,
      fg: SwColors.stamp,
      border: Colors.transparent,
      glow: Colors.transparent,
    ),
    SwButtonTone.danger => (
      bg: Colors.white,
      bgHover: SwColors.dangerWash,
      fg: SwColors.danger,
      border: SwColors.danger.withValues(alpha: 0.35),
      glow: SwColors.danger,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final enabled = onPressed != null && !loading;
    final height = large ? 52.0 : 44.0;
    final quiet = tone == SwButtonTone.quiet;
    final duration = SwMotion.of(context, const Duration(milliseconds: 200));

    Widget button = Interactive(
      onTap: enabled ? onPressed : null,
      tooltip: tooltip,
      semanticLabel: loading ? '$label, working' : null,
      lift: quiet ? 0 : 1.5,
      hoverShadow: !quiet,
      shadowColor: palette.glow,
      builder: (context, state) {
        final hovered = state.hovered && enabled;
        return AnimatedOpacity(
          duration: duration,
          opacity: onPressed == null ? 0.5 : 1,
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            height: height,
            padding: EdgeInsets.symmetric(horizontal: quiet ? 10 : 18),
            decoration: BoxDecoration(
              color: hovered ? palette.bgHover : palette.bg,
              borderRadius: const BorderRadius.all(SwRadius.field),
              border: Border.all(
                color: tone == SwButtonTone.secondary && hovered
                    ? SwColors.ink.withValues(alpha: 0.35)
                    : palette.border,
              ),
            ),
            child: Center(
              widthFactor: 1,
              child: AnimatedSwitcher(
                duration: duration,
                child: Row(
                  key: ValueKey(loading),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.fg,
                        ),
                      )
                    else if (icon != null)
                      AnimatedScale(
                        duration: duration,
                        curve: Curves.easeOutBack,
                        scale: hovered ? 1.14 : 1,
                        child: Icon(icon, size: 18, color: palette.fg),
                      ),
                    if (loading || icon != null)
                      const SizedBox(width: SwSpace.sm),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: SwType.label.copyWith(
                          color: palette.fg,
                          fontSize: large ? 16 : 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (expand) button = SizedBox(width: double.infinity, child: button);
    return button;
  }
}

/// A square icon-only button with a tooltip, used for copy and refresh.
class SwIconButton extends StatelessWidget {
  const SwIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
    this.size = 40,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool loading;
  final double size;

  @override
  Widget build(BuildContext context) {
    final duration = SwMotion.of(context, const Duration(milliseconds: 200));
    return Interactive(
      onTap: loading ? null : onPressed,
      tooltip: tooltip,
      lift: 1,
      builder: (context, state) => AnimatedContainer(
        duration: duration,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: state.hovered ? SwColors.stampWash : Colors.white,
          borderRadius: const BorderRadius.all(SwRadius.field),
          border: Border.all(
            color: state.hovered ? SwColors.stamp : SwColors.rule,
          ),
        ),
        child: Center(
          child: loading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : AnimatedRotation(
                  // A refresh glyph turns a little toward its meaning on hover.
                  turns: state.hovered ? 0.12 : 0,
                  duration: duration,
                  child: Icon(
                    icon,
                    size: 18,
                    color: state.hovered ? SwColors.stamp : SwColors.ink,
                  ),
                ),
        ),
      ),
    );
  }
}

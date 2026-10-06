import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Hover, press and keyboard-focus state for anything clickable.
@immutable
class InteractionState {
  const InteractionState({
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
    this.enabled = true,
  });

  final bool hovered;
  final bool pressed;
  final bool focused;
  final bool enabled;

  bool get active => enabled && (hovered || focused);
}

/// The Tailwind interaction kit in one widget:
/// `transition duration-200 ease-out hover:-translate-y-0.5 hover:shadow-lg
///  active:scale-[.97] focus-visible:ring-2 ring-offset-2 cursor-pointer`.
///
/// Use [builder] when children should react too (Tailwind's `group-hover`).
class Interactive extends StatefulWidget {
  const Interactive({
    super.key,
    this.onTap,
    this.child,
    this.builder,
    this.lift = 2,
    this.pressScale = 0.97,
    this.radius = const BorderRadius.all(SwRadius.field),
    this.shadowColor = const Color(0xFF14213A),
    this.hoverShadow = true,
    this.ring = true,
    this.semanticLabel,
    this.selected,
    this.tooltip,
  }) : assert(child != null || builder != null);

  final VoidCallback? onTap;
  final Widget? child;
  final Widget Function(BuildContext context, InteractionState state)? builder;

  /// Pixels to rise on hover.
  final double lift;
  final double pressScale;
  final BorderRadius radius;
  final Color shadowColor;
  final bool hoverShadow;

  /// Draw a focus ring when focused from the keyboard.
  final bool ring;
  final String? semanticLabel;
  final bool? selected;
  final String? tooltip;

  @override
  State<Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<Interactive> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _activate() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final state = InteractionState(
      hovered: _hovered,
      pressed: _pressed,
      focused: _focused,
      enabled: _enabled,
    );
    final reduced = SwMotion.reduced(context);
    final duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final lifted = _enabled && _hovered && !_pressed;
    final scale = _enabled && _pressed ? widget.pressScale : 1.0;
    final dy = lifted && !reduced ? -widget.lift : 0.0;

    Widget content = widget.builder?.call(context, state) ?? widget.child!;

    content = AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      transformAlignment: Alignment.center,
      transform: Matrix4.translationValues(0, dy, 0)
        ..scaleByDouble(scale, scale, 1, 1),
      decoration: BoxDecoration(
        borderRadius: widget.radius,
        boxShadow: widget.hoverShadow && _enabled
            ? [
                BoxShadow(
                  color: widget.shadowColor.withValues(
                    alpha: lifted ? 0.16 : 0,
                  ),
                  blurRadius: lifted ? 22 : 0,
                  offset: Offset(0, lifted ? 10 : 0),
                  spreadRadius: lifted ? -6 : 0,
                ),
              ]
            : const [],
      ),
      child: content,
    );

    if (widget.ring) {
      // `ring-2 ring-offset-2`, painted outside the bounds so focus never
      // shifts layout.
      content = CustomPaint(
        foregroundPainter: _RingPainter(
          radius: widget.radius,
          visible: _focused,
        ),
        child: content,
      );
    }

    content = FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled ? _activate : null,
        child: content,
      ),
    );

    content = Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: content,
    );
    if (widget.tooltip != null) {
      content = Tooltip(message: widget.tooltip!, child: content);
    }
    return content;
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.radius, required this.visible});

  final BorderRadius radius;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final rect = (Offset.zero & size).inflate(4);
    canvas.drawRRect(
      (radius + BorderRadius.circular(4)).toRRect(rect),
      Paint()
        ..color = SwColors.stamp
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.visible != visible || old.radius != radius;
}

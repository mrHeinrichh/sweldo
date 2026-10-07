import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/motion.dart';

/// Turns its child in 3D toward the pointer, with a soft light glare that
/// slides across the surface, then springs back when the pointer leaves.
/// Touch works too: dragging a finger tilts it while held.
class Tilt3D extends StatefulWidget {
  const Tilt3D({
    super.key,
    required this.child,
    this.maxTilt = 10,
    this.baseX = 0,
    this.baseY = 0,
    this.perspective = 0.0012,
    this.glare = true,
    this.radius = const BorderRadius.all(Radius.circular(6)),
  });

  final Widget child;

  /// Maximum tilt in degrees.
  final double maxTilt;

  /// Resting pose in degrees, for objects that sit at an angle.
  final double baseX;
  final double baseY;
  final double perspective;
  final bool glare;
  final BorderRadius radius;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController.unbounded(
    vsync: this,
  );
  Offset _pointer = Offset.zero; // -1…1 in both axes
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _engaged = false;

  @override
  void initState() {
    super.initState();
    _spring.addListener(
      () => setState(() {
        _pointer = Offset.lerp(_from, _to, _spring.value.clamp(0.0, 1.2))!;
      }),
    );
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _aim(Offset local, Size size, {bool settle = false}) {
    final target = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
    _animateTo(target, settle: settle);
  }

  void _animateTo(Offset target, {bool settle = false}) {
    _from = _pointer;
    _to = target;
    _spring.value = 0;
    if (settle) {
      // A slightly bouncy return, like a card let go of.
      _spring.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 120, damping: 12),
          0,
          1,
          0,
        ),
      );
    } else {
      _spring.animateTo(
        1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
      );
    }
  }

  void _release() {
    _engaged = false;
    _animateTo(Offset.zero, settle: true);
  }

  @override
  Widget build(BuildContext context) {
    if (SwMotion.reduced(context)) {
      return Transform(
        alignment: Alignment.center,
        transform: _matrix(Offset.zero),
        child: widget.child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 400,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 400,
        );
        return Listener(
          onPointerDown: (e) {
            _engaged = true;
            _aim(e.localPosition, size);
          },
          onPointerMove: (e) {
            if (_engaged) _aim(e.localPosition, size);
          },
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: MouseRegion(
            onHover: (e) => _aim(e.localPosition, size),
            onExit: (_) => _release(),
            child: Transform(
              alignment: Alignment.center,
              transform: _matrix(_pointer),
              child: Stack(
                children: [
                  widget.child,
                  if (widget.glare)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRRect(
                          borderRadius: widget.radius,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(_pointer.dx, _pointer.dy),
                                radius: 1.1,
                                colors: [
                                  Colors.white.withValues(
                                    alpha: 0.22 * _pointer.distance.clamp(0, 1),
                                  ),
                                  Colors.white.withValues(alpha: 0),
                                ],
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
        );
      },
    );
  }

  Matrix4 _matrix(Offset p) {
    final deg = math.pi / 180;
    return Matrix4.identity()
      ..setEntry(3, 2, widget.perspective)
      ..rotateX((widget.baseX - p.dy * widget.maxTilt) * deg)
      ..rotateY((widget.baseY + p.dx * widget.maxTilt) * deg);
  }
}

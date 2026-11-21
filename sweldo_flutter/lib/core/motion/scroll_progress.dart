import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// How far a widget has travelled through the scroll viewport, 0 to 1, read
/// from scroll position rather than fired once on entry — so it runs back
/// the other way when the reader scrolls up. The web client's
/// `useScrollProgress` measures the same fractions against the same
/// viewport, so both clients draw the same frame at the same offset.
class ScrollProgress extends StatefulWidget {
  const ScrollProgress({
    super.key,
    required this.builder,
    this.start = 0.92,
    this.end = 0.62,
  });

  /// Where the widget's top sits, as a fraction of the viewport height.
  final double start;
  final double end;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<ScrollProgress> createState() => _ScrollProgressState();
}

class _ScrollProgressState extends State<ScrollProgress> {
  double _progress = 0;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position?.removeListener(_update);
    _position = Scrollable.maybeOf(context)?.position;
    _position?.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _update() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final viewport =
        Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final viewTop = viewport?.localToGlobal(Offset.zero).dy ?? 0;
    final viewHeight = viewport?.size.height ??
        MediaQuery.sizeOf(context).height;
    if (viewHeight <= 0) return;
    final top = (box.localToGlobal(Offset.zero).dy - viewTop) / viewHeight;
    final next = ((widget.start - top) / (widget.start - widget.end))
        .clamp(0.0, 1.0)
        .toDouble();
    if ((next - _progress).abs() < 0.003) return;
    setState(() => _progress = next);
  }

  @override
  void dispose() {
    _position?.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (SwMotion.reduced(context)) return widget.builder(context, 1);
    return widget.builder(context, _progress);
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// The page's tractor-feed margin: the payroll paper's own edge, at the
/// scale of the whole page. One punch slot per section, in the vocabulary
/// the app already uses everywhere else — empty while a section is still
/// ahead of you, ringed for the one you are in, punched violet once you
/// have passed it. The feed line fills as the paper advances.
///
/// The web client draws the same margin from `PageSpine.tsx`.
class PageSpine extends StatelessWidget {
  const PageSpine({
    super.key,
    required this.labels,
    required this.current,
    required this.fill,
    required this.done,
    required this.onJump,
    this.railOnly = false,
  });

  final List<String> labels;
  final int current;
  final double fill;

  /// The paper has fed all the way through; the margin steps out of the footer.
  final bool done;

  /// On a phone the sheet's own sprocket margin is millimetres away, and a
  /// second column of holes beside it reads as noise rather than as the
  /// page's edge. There the margin keeps the feed line alone, which still
  /// says how far through the paper you are.
  final bool railOnly;

  final void Function(int index) onJump;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = railOnly ? 14.0 : (size.width < 1184 ? 30.0 : 34.0);

    final rail = Positioned(
      top: 0,
      bottom: 0,
      child: SizedBox(
        width: railOnly ? 2 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(1),
          child: ColoredBox(
            color: SwColors.rule,
            child: Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: fill.clamp(0.0, 1.0),
                widthFactor: 1,
                child: const ColoredBox(color: SwColors.stamp),
              ),
            ),
          ),
        ),
      ),
    );

    final Widget margin = railOnly
        ? SizedBox(
            width: width,
            height: size.height * 0.46,
            child: Stack(alignment: Alignment.center, children: [rail]),
          )
        : SizedBox(
            width: width,
            child: Stack(
              alignment: Alignment.center,
              children: [
                rail,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < labels.length; i++) ...[
                        if (i > 0) const SizedBox(height: 20),
                        _Punch(
                          label: labels[i],
                          state: i < current
                              ? _State.punched
                              : i == current
                              ? _State.ready
                              : _State.locked,
                          onTap: () => onJump(i),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );

    return IgnorePointer(
      ignoring: done,
      child: AnimatedOpacity(
        opacity: done ? 0 : 1,
        duration: SwMotion.of(context, SwMotion.standard),
        curve: SwMotion.enter,
        child: margin,
      ),
    );
  }
}

enum _State { locked, ready, punched }

class _Punch extends StatefulWidget {
  const _Punch({required this.label, required this.state, required this.onTap});

  final String label;
  final _State state;
  final VoidCallback onTap;

  @override
  State<_Punch> createState() => _PunchState();
}

class _PunchState extends State<_Punch> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final ready = widget.state == _State.ready;
    final punched = widget.state == _State.punched;
    const hole = 11.0;

    return Semantics(
      button: true,
      selected: ready,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: SwMotion.of(context, SwMotion.standard),
                  curve: SwMotion.enter,
                  width: ready ? hole * 1.18 : hole,
                  height: ready ? hole * 1.18 : hole,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: punched
                        ? SwColors.stamp
                        : ready
                        ? SwColors.paydayWash
                        : SwColors.paper,
                    border: Border.all(
                      color: punched
                          ? SwColors.stamp
                          : ready
                          ? SwColors.payday
                          : _hovering
                          ? SwColors.stamp
                          : SwColors.rule,
                      width: 1.5,
                    ),
                  ),
                ),
                if (_hovering)
                  Positioned(
                    left: 34,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: SwColors.ink,
                        borderRadius: BorderRadius.all(SwRadius.card),
                      ),
                      child: Text(
                        widget.label,
                        softWrap: false,
                        style: SwType.caption.copyWith(color: SwColors.paper),
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

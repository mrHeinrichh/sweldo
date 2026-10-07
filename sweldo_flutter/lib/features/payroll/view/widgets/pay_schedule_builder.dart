import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/motion/interactive.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/stellar/stellar_network.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/sw_icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/utils/amount.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/widgets/layout.dart';
import '../../../account/bloc/account_setup_cubit.dart';
import '../../../tour/tour_controller.dart';
import '../../../account/data/account_repository.dart';
import '../../../wallet/bloc/wallet_bloc.dart';
import '../../bloc/payroll_form/payroll_form_bloc.dart';
import '../../domain/pay_cadence.dart';

extension PayCadenceIcon on PayCadence {
  IconData get icon => switch (this) {
    PayCadence.minute => SwIcons.everyMinute,
    PayCadence.day => SwIcons.daily,
    PayCadence.week => SwIcons.weekly,
    PayCadence.month => SwIcons.monthly,
  };

  /// "every week", for the schedule sentence.
  String get phrase =>
      this == PayCadence.minute ? 'every minute' : 'every $unit';

  String units(int n) => '$n ${plural(n, unit)}';
}

/// The schedule as one smart, editable unit: a sentence whose parts are
/// controls, a track of payouts to drag, and presets. The checks that follow
/// from it live on the review step ([ScheduleInsights]).
class PayScheduleBuilder extends StatelessWidget {
  const PayScheduleBuilder({super.key});

  /// Finds the payout track in tests.
  static const trackKey = ValueKey('payout-track');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PayrollFormBloc>().state;
    return SecondTicker(
      builder: (context, now) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TourTarget(
            id: 'schedule-sentence',
            child: _ScheduleSentence(state: state, now: now),
          ),
          const SizedBox(height: SwSpace.xl),
          TourTarget(
            id: 'payout-track',
            child: _PayoutTrack(
              key: trackKey,
              payouts: state.payouts,
              capacity: state.capacity,
              paydays: state.paydays(now),
              onChanged: (n) => context.read<PayrollFormBloc>().add(
                ScheduleChanged(payouts: n),
              ),
            ),
          ),
          const SizedBox(height: SwSpace.xl),
          TourTarget(
            id: 'presets',
            child: _Presets(state: state),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The sentence: "Pay [every week], [6 times], starting [in 1 week]."

class _ScheduleSentence extends StatelessWidget {
  const _ScheduleSentence({required this.state, required this.now});

  final PayrollFormState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PayrollFormBloc>();
    final style = SwType.title.copyWith(
      fontSize: context.responsive(19.0, sm: 21),
      fontWeight: FontWeight.w500,
      height: 1.6,
    );
    final cadence = state.cadence;
    final first = state.firstPayday(now);

    final startLabel = state.firstPaydayAt != null
        ? 'on ${formatShortDate(state.firstPaydayAt!)}'
        : state.firstPaydayIn == 0
        ? 'right away'
        : 'in ${cadence.units(state.firstPaydayIn)}';

    return Semantics(
      label:
          'Pay ${cadence.phrase}, ${state.payouts} times, starting $startLabel',
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: [
          Text('Pay', style: style),
          _MenuToken(
            label: cadence.phrase,
            icon: cadence.icon,
            after: ',',
            afterStyle: style,
            items: [
              for (final c in PayCadence.values)
                _TokenItem(
                  icon: c.icon,
                  title: c.label,
                  subtitle: c.hint ?? 'Every ${c.unit}',
                  selected: c == cadence,
                  onSelected: () => bloc.add(ScheduleChanged(cadence: c)),
                ),
            ],
          ),
          _MenuToken(
            label: state.payouts == 1 ? 'once' : '${state.payouts} times',
            icon: SwIcons.ledger,
            after: ',',
            afterStyle: style,
            items: [
              for (final n in [1, 3, 6, 12, 24])
                if (n <= state.capacity)
                  _TokenItem(
                    icon: SwIcons.ledger,
                    title: n == 1 ? 'Once' : '$n times',
                    subtitle: n == 1
                        ? 'A single payout'
                        : 'Last payday ${cadence.units(n - 1)} after the first',
                    selected: n == state.payouts,
                    onSelected: () => bloc.add(ScheduleChanged(payouts: n)),
                  ),
              _TokenItem(
                icon: SwIcons.payday,
                title: 'Pay until a date…',
                subtitle: cadence == PayCadence.minute
                    ? 'Not for minute-by-minute demos'
                    : 'Sweldo counts the paydays for you',
                onSelected: cadence == PayCadence.minute
                    ? null
                    : () => _payUntil(context, first),
              ),
            ],
          ),
          Text('starting', style: style),
          _MenuToken(
            label: startLabel,
            icon: SwIcons.timer,
            after: '.',
            afterStyle: style,
            items: [
              _TokenItem(
                icon: SwIcons.everyMinute,
                title: 'Right away',
                subtitle: 'The first payout is claimable once locked',
                selected:
                    state.firstPaydayAt == null && state.firstPaydayIn == 0,
                onSelected: () =>
                    bloc.add(const ScheduleChanged(firstPaydayIn: 0)),
              ),
              for (final n in [1, 2, 3])
                _TokenItem(
                  icon: SwIcons.timer,
                  title: 'In ${cadence.units(n)}',
                  subtitle: formatDateTime(now.add(cadence.interval * n)),
                  selected:
                      state.firstPaydayAt == null && state.firstPaydayIn == n,
                  onSelected: () => bloc.add(ScheduleChanged(firstPaydayIn: n)),
                ),
              _TokenItem(
                icon: SwIcons.payday,
                title: 'On a date…',
                subtitle: 'Paydays start at 9:00 AM that day',
                selected: state.firstPaydayAt != null,
                onSelected: () => _startOn(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _payUntil(BuildContext context, DateTime first) async {
    final bloc = context.read<PayrollFormBloc>();
    final cadence = state.cadence;
    final initial = state.paydays(now).last;
    final end = await showDatePicker(
      context: context,
      helpText: 'Pay until',
      initialDate: initial,
      firstDate: DateUtils.dateOnly(first),
      lastDate: DateUtils.dateOnly(
        first,
      ).add(cadence.interval * state.capacity),
    );
    if (end == null) return;
    final lastMoment = DateTime(end.year, end.month, end.day, 23, 59);
    final count = lastMoment.difference(first).inSeconds ~/ cadence.seconds + 1;
    bloc.add(ScheduleChanged(payouts: count.clamp(1, state.capacity)));
  }

  Future<void> _startOn(BuildContext context) async {
    final bloc = context.read<PayrollFormBloc>();
    final today = DateUtils.dateOnly(now);
    final picked = await showDatePicker(
      context: context,
      helpText: 'First payday',
      initialDate: state.firstPaydayAt ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    if (DateUtils.isSameDay(picked, today)) {
      bloc.add(const ScheduleChanged(firstPaydayIn: 0));
    } else {
      final at = DateTime(picked.year, picked.month, picked.day, 9);
      bloc.add(ScheduleChanged(firstPaydayAt: () => at));
    }
  }
}

class _TokenItem {
  const _TokenItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelected,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onSelected;
  final bool selected;
}

/// An editable part of the sentence: a pill that opens a menu.
class _MenuToken extends StatelessWidget {
  const _MenuToken({
    required this.label,
    required this.icon,
    required this.items,
    this.after,
    this.afterStyle,
  });

  final String label;
  final IconData icon;
  final List<_TokenItem> items;

  /// Punctuation that stays on the same line as the token.
  final String? after;
  final TextStyle? afterStyle;

  @override
  Widget build(BuildContext context) {
    final duration = SwMotion.of(context, const Duration(milliseconds: 200));
    final anchor = MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(SwColors.sheet),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        elevation: const WidgetStatePropertyAll(10),
        shadowColor: WidgetStatePropertyAll(
          SwColors.ink.withValues(alpha: 0.3),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(SwRadius.panel),
            side: BorderSide(color: SwColors.rule),
          ),
        ),
      ),
      menuChildren: [
        for (final item in items)
          MenuItemButton(
            onPressed: item.onSelected,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(SwRadius.field),
                ),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)
                    ? SwColors.stampWash
                    : item.selected
                    ? SwColors.greenbar.withValues(alpha: 0.6)
                    : Colors.transparent,
              ),
            ),
            leadingIcon: Icon(
              item.icon,
              size: 18,
              color: item.onSelected == null
                  ? SwColors.inkFaint
                  : SwColors.stamp,
            ),
            trailingIcon: item.selected
                ? const Icon(SwIcons.check, size: 16, color: SwColors.payday)
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: SwType.label.copyWith(
                      color: item.onSelected == null
                          ? SwColors.inkFaint
                          : SwColors.ink,
                    ),
                  ),
                  Text(item.subtitle, style: SwType.caption),
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, _) => Interactive(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        semanticLabel: 'Change: $label',
        lift: 1,
        shadowColor: SwColors.stamp,
        radius: const BorderRadius.all(SwRadius.field),
        builder: (context, state) {
          final open = controller.isOpen;
          final hot = state.hovered || open;
          return AnimatedContainer(
            duration: duration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
            decoration: BoxDecoration(
              color: hot ? SwColors.stamp : SwColors.stampWash,
              borderRadius: const BorderRadius.all(SwRadius.field),
              border: Border.all(color: SwColors.stamp.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: hot ? Colors.white : SwColors.stamp,
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: SwType.subtitle.copyWith(
                      fontSize: context.responsive(16.0, sm: 18),
                      color: hot ? Colors.white : SwColors.stampDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: duration,
                  child: Icon(
                    SwIcons.chevronDown,
                    size: 16,
                    color: hot ? Colors.white : SwColors.stamp,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (after == null) return anchor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        anchor,
        Text(after!, style: afterStyle),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The track: one slot per possible payout, drag to set how many.

class _PayoutTrack extends StatefulWidget {
  const _PayoutTrack({
    super.key,
    required this.payouts,
    required this.capacity,
    required this.paydays,
    required this.onChanged,
  });

  final int payouts;
  final int capacity;
  final List<DateTime> paydays;
  final ValueChanged<int> onChanged;

  @override
  State<_PayoutTrack> createState() => _PayoutTrackState();
}

class _PayoutTrackState extends State<_PayoutTrack> {
  static const _slots = StellarNetwork.maxPayoutsPerEmployee;
  bool _dragging = false;
  bool _focused = false;

  void _setFrom(double dx, double width) {
    final pitch = width / _slots;
    final n = ((dx / pitch).floor() + 1).clamp(1, widget.capacity);
    if (n != widget.payouts) {
      HapticFeedback.selectionClick();
      widget.onChanged(n);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    int? next;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      next = widget.payouts + 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      next = widget.payouts - 1;
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      next = 1;
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      next = widget.capacity;
    }
    if (next == null) return KeyEventResult.ignored;
    final clamped = next.clamp(1, widget.capacity);
    if (clamped != widget.payouts) widget.onChanged(clamped);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final duration = SwMotion.of(context, const Duration(milliseconds: 220));
    final last = widget.paydays.isEmpty ? null : widget.paydays.last;
    final first = widget.paydays.isEmpty ? null : widget.paydays.first;

    return Semantics(
      slider: true,
      label: 'Payouts per employee',
      value: '${widget.payouts}',
      increasedValue: '${math.min(widget.payouts + 1, widget.capacity)}',
      decreasedValue: '${math.max(widget.payouts - 1, 1)}',
      onIncrease: () =>
          widget.onChanged(math.min(widget.payouts + 1, widget.capacity)),
      onDecrease: () => widget.onChanged(math.max(widget.payouts - 1, 1)),
      child: Focus(
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final pitch = width / _slots;
            final handleX = pitch * (widget.payouts - 0.5);
            const bubbleWidth = 128.0;
            final bubbleLeft = (handleX - bubbleWidth / 2).clamp(
              0.0,
              width - bubbleWidth,
            );
            final limitX = pitch * widget.capacity;

            return MouseRegion(
              cursor: _dragging
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _setFrom(d.localPosition.dx, width),
                onHorizontalDragStart: (d) {
                  setState(() => _dragging = true);
                  _setFrom(d.localPosition.dx, width);
                },
                onHorizontalDragUpdate: (d) =>
                    _setFrom(d.localPosition.dx, width),
                onHorizontalDragEnd: (_) => setState(() => _dragging = false),
                child: SizedBox(
                  height: 118,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Bubble with the count and the last payday.
                      AnimatedPositioned(
                        duration: _dragging ? Duration.zero : duration,
                        curve: Curves.easeOutCubic,
                        left: bubbleLeft,
                        top: 0,
                        width: bubbleWidth,
                        child: AnimatedScale(
                          duration: duration,
                          scale: _dragging ? 1.06 : 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: SwColors.ink,
                              borderRadius: const BorderRadius.all(
                                SwRadius.field,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: SwColors.ink.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  widget.payouts == 1
                                      ? '1 payout'
                                      : '${widget.payouts} payouts',
                                  style: SwType.label.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                if (last != null)
                                  Text(
                                    'ends ${formatShortDate(last)}',
                                    style: SwType.caption.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Slots.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 52,
                        height: 34,
                        child: Row(
                          children: [
                            for (var i = 1; i <= _slots; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: math.min(1.5, pitch * 0.12),
                                  ),
                                  child: _Slot(
                                    filled: i <= widget.payouts,
                                    edge: i == widget.payouts,
                                    locked: i > widget.capacity,
                                    duration: duration,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // The team's one-transaction limit.
                      if (widget.capacity < _slots)
                        Positioned(
                          left: limitX - 1,
                          top: 46,
                          height: 46,
                          child: Container(
                            width: 2,
                            color: SwColors.danger.withValues(alpha: 0.6),
                          ),
                        ),
                      // Knob under the bubble.
                      AnimatedPositioned(
                        duration: _dragging ? Duration.zero : duration,
                        curve: Curves.easeOutCubic,
                        left: handleX - 9,
                        top: 42,
                        child: AnimatedContainer(
                          duration: duration,
                          width: 18,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(9),
                            ),
                            border: Border.all(
                              color: _focused ? SwColors.stamp : SwColors.ink,
                              width: _focused ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: SwColors.ink.withValues(alpha: 0.25),
                                blurRadius: _dragging ? 14 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            SwIcons.grip,
                            size: 14,
                            color: SwColors.inkMuted,
                          ),
                        ),
                      ),
                      // Dates under the track.
                      if (first != null)
                        Positioned(
                          left: 0,
                          top: 100,
                          child: Text(
                            'Starts ${formatShortDate(first)}',
                            style: SwType.caption,
                          ),
                        ),
                      Positioned(
                        right: 0,
                        top: 100,
                        child: Text(
                          widget.capacity < _slots
                              ? 'Team limit ${widget.capacity}'
                              : 'Up to $_slots',
                          style: SwType.caption.copyWith(
                            color: widget.capacity < _slots
                                ? SwColors.danger
                                : SwColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.filled,
    required this.edge,
    required this.locked,
    required this.duration,
  });

  final bool filled;
  final bool edge;
  final bool locked;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return CustomPaint(
        painter: const _HatchPainter(),
        child: const SizedBox.expand(),
      );
    }
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: filled
            ? (edge ? SwColors.stampDeep : SwColors.stamp)
            : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: filled ? Colors.transparent : SwColors.rule),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(rect);
    canvas.drawRRect(rect, Paint()..color = SwColors.paper);
    final line = Paint()
      ..color = SwColors.rule
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Presets.

class _Preset {
  const _Preset(
    this.icon,
    this.title,
    this.cadence,
    this.payouts,
    this.firstIn,
  );

  final IconData icon;
  final String title;
  final PayCadence cadence;
  final int payouts;
  final int firstIn;
}

const _presets = [
  _Preset(SwIcons.everyMinute, 'Live demo', PayCadence.minute, 3, 1),
  _Preset(SwIcons.daily, 'Daily for 2 weeks', PayCadence.day, 14, 1),
  _Preset(SwIcons.weekly, 'Weekly for a quarter', PayCadence.week, 13, 1),
  _Preset(SwIcons.monthly, 'Monthly for a year', PayCadence.month, 12, 1),
];

class _Presets extends StatelessWidget {
  const _Presets({required this.state});

  final PayrollFormState state;

  @override
  Widget build(BuildContext context) {
    final chips = [for (final preset in _presets) _presetChip(context, preset)];
    if (context.up(Breakpoint.sm)) {
      return Wrap(spacing: SwSpace.sm, runSpacing: SwSpace.sm, children: chips);
    }
    // overflow-x-auto on phones.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: SwSpace.sm),
              child: chip,
            ),
        ],
      ),
    );
  }

  Widget _presetChip(BuildContext context, _Preset preset) {
    final payouts = math.min(preset.payouts, state.capacity);
    final selected =
        state.cadence == preset.cadence &&
        state.payouts == payouts &&
        state.firstPaydayIn == preset.firstIn &&
        state.firstPaydayAt == null;
    final duration = SwMotion.of(context, const Duration(milliseconds: 200));
    return Interactive(
      onTap: () => context.read<PayrollFormBloc>().add(
        ScheduleChanged(
          cadence: preset.cadence,
          payouts: payouts,
          firstPaydayIn: preset.firstIn,
        ),
      ),
      selected: selected,
      semanticLabel: 'Preset: ${preset.title}',
      shadowColor: SwColors.stamp,
      radius: const BorderRadius.all(Radius.circular(999)),
      builder: (context, interaction) => AnimatedContainer(
        duration: duration,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? SwColors.ink : Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: selected
                ? SwColors.ink
                : interaction.hovered
                ? SwColors.stamp
                : SwColors.rule,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? SwIcons.check : preset.icon,
              size: 15,
              color: selected ? Colors.white : SwColors.stamp,
            ),
            const SizedBox(width: 6),
            Text(
              preset.title,
              style: SwType.label.copyWith(
                fontSize: 13,
                color: selected ? Colors.white : SwColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Insights: what the plan means, checked against reality.

enum InsightTone { neutral, good, caution, danger }

/// Live checks of the plan against the calendar, the transaction limit and
/// the connected wallet. [leading] chips (such as what still blocks locking)
/// come first.
class ScheduleInsights extends StatelessWidget {
  const ScheduleInsights({super.key, this.leading = const []});

  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PayrollFormBloc>().state;
    return TourTarget(
      id: 'insights',
      child: SecondTicker(
        builder: (context, now) =>
            _Insights(state: state, now: now, leading: leading),
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({
    required this.state,
    required this.now,
    required this.leading,
  });

  final PayrollFormState state;
  final DateTime now;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final asset = context.read<AppConfig>().assetLabel;
    final native = !context.read<AppConfig>().usesIssuedAsset;
    final connected = context.select((WalletBloc b) => b.state.session != null);
    final balances = context.select((AccountSetupCubit c) => c.state.balances);
    final bloc = context.read<PayrollFormBloc>();

    final paydays = state.paydays(now);
    final first = paydays.first;
    final last = paydays.last;
    final cadence = state.cadence;
    final count = state.balanceCount;
    const limit = StellarNetwork.maxOperationsPerTransaction;

    final insights = <Widget>[
      ...leading,
      InsightChip(
        icon: SwIcons.payday,
        tone: InsightTone.neutral,
        text: cadence == PayCadence.minute
            ? 'First payday ${formatTime(first)}'
            : 'First payday ${formatDateTime(first)}',
      ),
      InsightChip(
        icon: SwIcons.hourglass,
        tone: InsightTone.neutral,
        text: state.payouts == 1
            ? 'One payout, nothing after it'
            : 'Last payday ${formatShortDate(last)}, '
                  '${cadence.units(state.payouts - 1)} after the first',
      ),
      if (state.overOperationLimit)
        InsightChip(
          icon: SwIcons.warning,
          tone: InsightTone.danger,
          text: '$count payouts won’t fit one transaction ($limit max)',
          actionLabel: 'Fit to one transaction',
          onAction: () => bloc.add(ScheduleChanged(payouts: state.capacity)),
        )
      else
        InsightChip(
          icon: SwIcons.ledger,
          tone: InsightTone.neutral,
          text: '$count of $limit payouts in one signature',
        ),
      _coverage(asset, native, connected, balances),
      if (cadence == PayCadence.minute)
        const InsightChip(
          icon: SwIcons.info,
          tone: InsightTone.neutral,
          text: 'Keep the pay page open to watch each payout unlock live',
        ),
      if (cadence == PayCadence.month)
        const InsightChip(
          icon: SwIcons.info,
          tone: InsightTone.neutral,
          text:
              'Monthly means every 30 days, so paydays drift from calendar dates',
        ),
    ];

    return Wrap(
      spacing: SwSpace.sm,
      runSpacing: SwSpace.sm,
      children: insights,
    );
  }

  Widget _coverage(
    String asset,
    bool native,
    bool connected,
    WalletBalances? balances,
  ) {
    if (!connected) {
      return const InsightChip(
        icon: SwIcons.wallet,
        tone: InsightTone.neutral,
        text: 'Connect a wallet to check it can cover this payroll',
      );
    }
    if (balances == null) {
      return const InsightChip(
        icon: SwIcons.wallet,
        tone: InsightTone.caution,
        text: 'This wallet isn’t funded on Testnet yet',
      );
    }
    final total = state.totalLockedUnits.toDouble() / 1e7;
    // Each payout reserves 0.5 XLM per claimant, and Sweldo uses two.
    final reserves = state.balanceCount * 1.0;
    final xlm = double.tryParse(balances.xlm) ?? 0;
    final spendableXlm = math.max(0.0, xlm - balances.reservedXlm);

    if (native) {
      final need = total + reserves;
      if (spendableXlm >= need) {
        return InsightChip(
          icon: SwIcons.protectedPay,
          tone: InsightTone.good,
          text:
              'Your wallet covers it, ${Amount.format(spendableXlm - need)} XLM to spare',
        );
      }
      return InsightChip(
        icon: SwIcons.warning,
        tone: InsightTone.caution,
        text:
            'Short by ${Amount.format(need - spendableXlm)} XLM, '
            'including ${Amount.format(reserves)} XLM in payout reserves',
      );
    }
    final held = double.tryParse(balances.asset) ?? 0;
    if (held < total) {
      return InsightChip(
        icon: SwIcons.warning,
        tone: InsightTone.caution,
        text: 'Short by ${Amount.format(total - held)} $asset',
      );
    }
    if (spendableXlm < reserves) {
      return InsightChip(
        icon: SwIcons.warning,
        tone: InsightTone.caution,
        text:
            'Needs ${Amount.format(reserves)} XLM for payout reserves; '
            'the wallet has ${Amount.format(spendableXlm)} free',
      );
    }
    return InsightChip(
      icon: SwIcons.protectedPay,
      tone: InsightTone.good,
      text:
          'Your wallet covers it, ${Amount.format(held - total)} $asset to spare',
    );
  }
}

/// One check about the plan, optionally with an action that fixes it.
class InsightChip extends StatelessWidget {
  const InsightChip({
    super.key,
    required this.icon,
    required this.tone,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final InsightTone tone;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (tone) {
      InsightTone.neutral => (SwColors.inkMuted, Colors.white),
      InsightTone.good => (SwColors.payday, SwColors.paydayWash),
      InsightTone.caution => (SwColors.caution, SwColors.cautionWash),
      InsightTone.danger => (SwColors.danger, SwColors.dangerWash),
    };
    return AnimatedSwitcher(
      duration: SwMotion.of(context, SwMotion.standard),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(SwRadius.field),
          border: Border.all(
            color: tone == InsightTone.neutral
                ? SwColors.rule
                : fg.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                style: SwType.caption.copyWith(
                  color: tone == InsightTone.neutral ? SwColors.ink : fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(width: SwSpace.sm),
              Interactive(
                onTap: onAction,
                lift: 0,
                hoverShadow: false,
                radius: const BorderRadius.all(Radius.circular(6)),
                builder: (context, state) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: state.hovered ? fg : Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                    border: Border.all(color: fg),
                  ),
                  child: Text(
                    actionLabel!,
                    style: SwType.caption.copyWith(
                      color: state.hovered ? Colors.white : fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/amount.dart';
import '../../../core/widgets/logo.dart';
import '../../../core/widgets/punch_card.dart';
import '../domain/story_script.dart';
import '../../../core/theme/sw_icons.dart';

// Every screen here is a pure function of story time, so the story can be
// paused, scrubbed and replayed frame-exactly.

/// The Sweldo app chrome inside the phone.
class _PhoneApp extends StatelessWidget {
  const _PhoneApp({required this.title, required this.children, this.tab = 2});

  final String title;
  final List<Widget> children;

  /// Selected bottom tab: 0 overview, 1 pay your team, 2 my pay.
  final int tab;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _body()),
        Positioned(left: 0, right: 0, bottom: 0, child: _TabBar(selected: tab)),
      ],
    );
  }

  Widget _body() {
    return ColoredBox(
      color: SwColors.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 62, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SweldoLogo(),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: const BoxDecoration(
                    color: SwColors.paydayWash,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    'Testnet',
                    style: SwType.caption.copyWith(
                      color: SwColors.payday,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(title, style: SwType.headline.copyWith(fontSize: 30)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The app's bottom navigation, as it appears on a phone.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected});

  final int selected;

  static const _items = [
    (SwIcons.overview, 'Overview'),
    (SwIcons.team, 'Pay your team'),
    (SwIcons.wallet, 'My pay'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 26),
      decoration: const BoxDecoration(
        color: SwColors.paper,
        border: Border(top: BorderSide(color: SwColors.rule)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 30,
                    decoration: BoxDecoration(
                      color: i == selected ? SwColors.stampWash : null,
                      borderRadius: const BorderRadius.all(Radius.circular(15)),
                    ),
                    child: Icon(
                      _items[i].$1,
                      size: 21,
                      color: i == selected ? SwColors.stamp : SwColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _items[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwType.caption.copyWith(
                      fontSize: 11,
                      color: i == selected ? SwColors.ink : SwColors.inkMuted,
                      fontWeight: i == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A finger tap: a dot that presses in and a ring that spreads.
class _Tapped extends StatelessWidget {
  const _Tapped({required this.t, required this.child});

  /// Progress through the tap window, 0…1 (0 and 1 mean no tap visible).
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final active = t > 0 && t < 1;
    final press = active ? math.sin(t * math.pi) : 0.0;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Transform.scale(scale: 1 - 0.04 * press, child: child),
        if (active) ...[
          Transform.scale(
            scale: 0.6 + 1.4 * t,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: SwColors.ink.withValues(alpha: 0.35 * (1 - t)),
                  width: 2,
                ),
              ),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SwColors.ink.withValues(alpha: 0.28 * press),
            ),
          ),
        ],
      ],
    );
  }
}

class _PhoneButton extends StatelessWidget {
  const _PhoneButton({
    required this.label,
    this.color = SwColors.stamp,
    this.tap = 0,
    this.icon,
  });

  final String label;
  final Color color;
  final double tap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _Tapped(
      t: tap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(SwRadius.field),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwType.label.copyWith(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stamp whose landing is driven by story time.
class _TimedStamp extends StatelessWidget {
  const _TimedStamp({
    required this.t,
    this.label = 'Claimed',
    this.color = SwColors.stamp,
  });

  final double t;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    final scale = 1.9 - 0.9 * const Cubic(0.2, 1.6, 0.4, 1).transform(t);
    return Opacity(
      opacity: math.min(1, t * 2.5),
      child: Transform.scale(
        scale: scale,
        child: ClaimedStamp(label: label, color: color),
      ),
    );
  }
}

/// The wallet's approval sheet sliding over the app.
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.visible,
    required this.approveTap,
    required this.title,
    required this.rows,
  });

  final double visible;
  final double approveTap;
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    if (visible <= 0) return const SizedBox.shrink();
    final shift = (1 - easeOut(visible)) * 420;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: SwColors.ink.withValues(alpha: 0.32 * visible),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Transform.translate(
            offset: Offset(0, shift),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 26),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: SwColors.rule,
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: SwColors.stampWash,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        child: const Icon(
                          SwIcons.sign,
                          size: 18,
                          color: SwColors.stamp,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: SwType.subtitle.copyWith(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final (label, value) in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(label, style: SwType.bodySmall)),
                          Text(value, style: SwType.figures),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  _PhoneButton(label: 'Approve', tap: approveTap),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Scene 2: the employer locks six payouts with one signature.
class EmployerScreen extends StatelessWidget {
  const EmployerScreen({super.key, required this.g});

  final double g;

  @override
  Widget build(BuildContext context) {
    const s = 4.5, e = 11.0;
    double at(double a, double b) => seg(g, s + a * (e - s), s + b * (e - s));
    final lockTap = at(0.26, 0.36);
    final sheet = at(0.34, 0.44) - at(0.64, 0.74);
    final approveTap = at(0.54, 0.64);
    final locked = at(0.72, 0.84);

    return Stack(
      children: [
        _PhoneApp(
          title: 'Pay your team',
          tab: 1,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(SwRadius.panel),
                border: Border.all(color: SwColors.rule),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ana Santos', style: SwType.subtitle),
                  Text('GBX7…Q2LM', style: SwType.mono),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Total pay', style: SwType.bodySmall),
                      ),
                      Text('1,800 USDC', style: SwType.figures),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      _chip('Monthly', selected: true),
                      _chip('6 payouts'),
                      _chip('First payday in 1 month'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: SwColors.greenbar,
                borderRadius: BorderRadius.all(SwRadius.panel),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '6 payouts of 300 USDC',
                      style: SwType.bodySmall.copyWith(color: SwColors.ink),
                    ),
                  ),
                  Text(
                    '1,800 USDC',
                    style: SwType.amount.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 150,
              child: locked > 0
                  ? Opacity(
                      opacity: math.min(1, locked * 3),
                      child: PayrollPaper(
                        header: PaperHeader(
                          title: 'Payroll locked',
                          trailing: _TimedStamp(t: locked, label: 'Locked'),
                        ),
                        children: [
                          _line('Payouts created', '6'),
                          _line('First payday', 'Nov 3'),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 112,
          child: locked > 0
              ? const _PhoneButton(
                  label: 'Payroll locked',
                  color: SwColors.payday,
                  icon: SwIcons.check,
                )
              : _PhoneButton(
                  label: 'Lock payroll on Stellar',
                  icon: SwIcons.locked,
                  tap: lockTap,
                ),
        ),
        Positioned.fill(
          child: _ConfirmSheet(
            visible: sheet,
            approveTap: approveTap,
            title: 'Confirm in Freighter',
            rows: const [
              ('Lock', '1,800 USDC'),
              ('Payouts', '6, monthly'),
              ('Network', 'Testnet'),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _chip(String label, {bool selected = false}) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: selected ? SwColors.stampWash : Colors.white,
      borderRadius: const BorderRadius.all(SwRadius.field),
      border: Border.all(color: selected ? SwColors.stamp : SwColors.rule),
    ),
    child: Text(
      label,
      style: SwType.caption.copyWith(
        color: selected ? SwColors.stampDeep : SwColors.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  static Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        Expanded(child: Text(label, style: SwType.bodySmall)),
        Text(value, style: SwType.figures),
      ],
    ),
  );
}

/// Scenes 4–5: the countdown runs out, then one tap claims the payout.
class WorkerScreen extends StatelessWidget {
  const WorkerScreen({super.key, required this.g});

  final double g;

  @override
  Widget build(BuildContext context) {
    final remaining = (20.0 - math.max(g, 17.0)).clamp(0.0, 3.0);
    final ready = g >= 20.0;
    final claimPop = easeBack(seg(g, 20.0, 20.35));
    final claimTap = seg(g, 21.6, 22.0);
    final sheet = seg(g, 21.9, 22.4) - seg(g, 23.3, 23.8);
    final approveTap = seg(g, 23.0, 23.4);
    final stamp = seg(g, 23.9, 24.5);
    final counted = easeInOut(seg(g, 24.0, 25.2));
    final claimed = stamp > 0;

    final wallet = 300 * counted;
    final lockedTotal = 1800 - 300 * counted;

    return Stack(
      children: [
        _PhoneApp(
          title: 'My pay',
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(SwRadius.panel),
                border: Border.all(color: SwColors.rule),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _figure(
                      'Locked and claimable',
                      '${Amount.format(lockedTotal.round())} USDC',
                    ),
                  ),
                  _figure(
                    'In your wallet',
                    '${Amount.format(wallet.round())} USDC',
                    color: counted > 0 ? SwColors.payday : SwColors.ink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            PayrollPaper(
              children: [
                _row(
                  slot: claimed
                      ? PunchState.punched
                      : ready
                      ? PunchState.ready
                      : PunchState.locked,
                  amount: '300 USDC',
                  caption: claimed
                      ? 'Claimed just now'
                      : ready
                      ? 'Unlocked today at 9:41 AM'
                      : 'Unlocks today at 9:41 AM',
                  trailing: claimed
                      ? _TimedStamp(t: stamp)
                      : ready
                      ? Transform.scale(
                          scale: claimPop,
                          child: SizedBox(
                            width: 96,
                            child: _Tapped(
                              t: claimTap,
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: SwColors.payday,
                                  borderRadius: BorderRadius.all(
                                    SwRadius.field,
                                  ),
                                ),
                                child: Text(
                                  'Claim',
                                  style: SwType.label.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : _countdown(
                          '0m ${remaining.ceil().toString().padLeft(2, '0')}s',
                        ),
                ),
                for (final month in ['Dec 3', 'Jan 3', 'Feb 3'])
                  _row(
                    slot: PunchState.locked,
                    amount: '300 USDC',
                    caption: 'Unlocks $month',
                    trailing: _countdown(
                      month == 'Dec 3'
                          ? '30d 0h'
                          : month == 'Jan 3'
                          ? '61d 0h'
                          : '92d 0h',
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned.fill(
          child: _ConfirmSheet(
            visible: sheet,
            approveTap: approveTap,
            title: 'Confirm in Freighter',
            rows: const [
              ('Claim', '300 USDC'),
              ('To', 'Your wallet'),
              ('Network', 'Testnet'),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _figure(
    String label,
    String value, {
    Color color = SwColors.ink,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: SwType.caption),
      const SizedBox(height: 2),
      Text(value, style: SwType.amount.copyWith(fontSize: 20, color: color)),
    ],
  );

  static Widget _countdown(String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(SwIcons.locked, size: 14, color: SwColors.locked),
      const SizedBox(width: 4),
      Text(label, style: SwType.figures.copyWith(color: SwColors.locked)),
    ],
  );

  static Widget _row({
    required PunchState slot,
    required String amount,
    required String caption,
    required Widget trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    child: Row(
      children: [
        PunchSlot(state: slot),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(amount, style: SwType.figures.copyWith(fontSize: 16)),
              Text(caption, style: SwType.caption),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    ),
  );
}

/// Scene 6: claim-and-convert to PHPT.
class ConvertScreen extends StatelessWidget {
  const ConvertScreen({super.key, required this.g});

  final double g;

  static const _phpt = 17040;

  @override
  Widget build(BuildContext context) {
    final counted = easeOut(seg(g, 27.2, 28.6));
    final quoteLeft = (60 - (g - 27.0) * 1.2).clamp(0, 60).round();
    final tap = seg(g, 29.0, 29.4);
    final stamp = seg(g, 29.6, 30.2);

    return _PhoneApp(
      title: 'Claim as PHPT',
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.all(SwRadius.panel),
            border: Border.all(color: SwColors.rule),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You claim', style: SwType.caption),
              Text('300 test-USDC', style: SwType.amount),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Icon(SwIcons.arrowDown, color: SwColors.stamp),
              ),
              Text('You receive about', style: SwType.caption),
              Text(
                '${Amount.format((_phpt * counted).round())} PHPT',
                style: SwType.amountLarge.copyWith(color: SwColors.payday),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text('At least', style: SwType.bodySmall)),
                  Text('16,869.6 PHPT', style: SwType.figures),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text('Price may move', style: SwType.bodySmall),
                  ),
                  Text('Up to 1%', style: SwType.figures),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text('Quote', style: SwType.bodySmall)),
                  Text('${quoteLeft}s left', style: SwType.figures),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 80,
          child: stamp > 0
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        '17,040 PHPT is in your wallet.',
                        style: SwType.subtitle,
                      ),
                    ),
                    _TimedStamp(
                      t: stamp,
                      label: 'Converted',
                      color: SwColors.payday,
                    ),
                  ],
                )
              : _PhoneButton(
                  label: 'Claim and convert',
                  icon: SwIcons.convert,
                  tap: tap,
                ),
        ),
        Text(
          'Test assets on Stellar Testnet. One transaction claims and '
          'converts, or nothing happens.',
          style: SwType.caption,
        ),
      ],
    );
  }
}

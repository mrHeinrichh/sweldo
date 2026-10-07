import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../utils/format.dart';
import '../theme/sw_icons.dart';

/// A Stellar key or hash in monospace, with a copy action that confirms
/// itself by swapping its icon.
class KeyText extends StatefulWidget {
  const KeyText(
    this.value, {
    super.key,
    this.edge = 6,
    this.copyable = true,
    this.style,
  });

  final String value;
  final int edge;
  final bool copyable;
  final TextStyle? style;

  @override
  State<KeyText> createState() => _KeyTextState();
}

class _KeyTextState extends State<KeyText> {
  bool _copied = false;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.value));
      if (!mounted) return;
      setState(() => _copied = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _copied = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copy is unavailable here. Select the text instead.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      shortKey(widget.value, widget.edge),
      style: widget.style ?? SwType.mono,
      semanticsLabel: widget.value,
    );
    if (!widget.copyable) {
      return Tooltip(message: widget.value, child: text);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Tooltip(message: widget.value, child: text),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: _copied ? 'Copied' : 'Copy',
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          onPressed: _copy,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              _copied ? SwIcons.check : SwIcons.copy,
              key: ValueKey(_copied),
              color: _copied ? SwColors.payday : SwColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

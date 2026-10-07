import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'external_link.dart';
import '../theme/sw_icons.dart';

enum NoticeTone { success, error, caution, info }

/// An inline message tied to the action that produced it.
class NoticeData {
  const NoticeData(this.tone, this.text, {this.link, this.linkLabel});

  const NoticeData.success(this.text, {this.link, this.linkLabel})
    : tone = NoticeTone.success;
  const NoticeData.error(this.text, {this.link, this.linkLabel})
    : tone = NoticeTone.error;

  final NoticeTone tone;
  final String text;
  final Uri? link;
  final String? linkLabel;

  @override
  bool operator ==(Object other) =>
      other is NoticeData &&
      other.tone == tone &&
      other.text == text &&
      other.link == link;

  @override
  int get hashCode => Object.hash(tone, text, link);
}

class Notice extends StatelessWidget {
  const Notice(this.data, {super.key});

  final NoticeData data;

  @override
  Widget build(BuildContext context) {
    final (icon, foreground, background) = switch (data.tone) {
      NoticeTone.success => (
        SwIcons.success,
        SwColors.payday,
        SwColors.paydayWash,
      ),
      NoticeTone.error => (SwIcons.error, SwColors.danger, SwColors.dangerWash),
      NoticeTone.caution => (
        SwIcons.warning,
        SwColors.caution,
        SwColors.cautionWash,
      ),
      NoticeTone.info => (SwIcons.info, SwColors.stamp, SwColors.stampWash),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(SwRadius.field),
          border: Border(left: BorderSide(color: foreground, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SwSpace.md,
            SwSpace.md,
            SwSpace.lg,
            SwSpace.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: SwSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.text,
                      style: SwType.bodySmall.copyWith(color: SwColors.ink),
                    ),
                    if (data.link != null) ...[
                      const SizedBox(height: SwSpace.xs),
                      ExternalLink(
                        label: data.linkLabel ?? 'View transaction',
                        uri: data.link!,
                        color: foreground,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animates a notice in and out by size, so the layout below moves with it
/// instead of jumping.
class AnimatedNotice extends StatelessWidget {
  const AnimatedNotice(this.data, {super.key, this.padding = EdgeInsets.zero});

  final NoticeData? data;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.maybeDisableAnimationsOf(context) == true
        ? Duration.zero
        : const Duration(milliseconds: 260);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: data == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: ValueKey(data),
                padding: padding,
                child: Notice(data!),
              ),
      ),
    );
  }
}

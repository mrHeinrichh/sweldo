import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../theme/sw_icons.dart';

Future<void> openExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// A text link that leaves the app, marked with an "opens elsewhere" glyph.
class ExternalLink extends StatelessWidget {
  const ExternalLink({
    super.key,
    required this.label,
    required this.uri,
    this.color = SwColors.stamp,
    this.style,
  });

  final String label;
  final Uri uri;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textStyle = (style ?? SwType.label).copyWith(color: color);
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => openExternal(uri),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, style: textStyle)),
              const SizedBox(width: 4),
              Icon(SwIcons.external, size: 13, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

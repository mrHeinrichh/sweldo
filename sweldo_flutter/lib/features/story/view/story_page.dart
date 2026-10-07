import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/shell/page_frame.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../domain/story_script.dart';
import 'story_player.dart';

/// The story on its own page, so it can be linked to and presented.
class StoryPage extends StatelessWidget {
  const StoryPage({super.key});

  static const path = '/story';

  @override
  Widget build(BuildContext context) {
    final presenting = context.read<AppConfig>().storyDemo;
    return PageFrame(
      title: 'Ana’s payday on Sweldo',
      // Presentation mode keeps the whole player on one phone screen.
      description: presenting
          ? null
          : 'A ${StoryScript.total.round()}-second story: a locked payroll, a '
                'payday countdown, a one-tap claim, and pay in pesos. Space '
                'plays and pauses; the arrow keys skip scenes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoryPlayer(
            autoplay: presenting,
            finishedLabel: 'Set up payroll',
            onFinishedAction: () => context.go(AppRoute.employer.path),
          ),
          const SizedBox(height: SwSpace.xl),
          Text('In words', style: SwType.title),
          const SizedBox(height: SwSpace.md),
          for (var i = 0; i < StoryScript.scenes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: SwSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${i + 1}.',
                      style: SwType.figures.copyWith(color: SwColors.inkMuted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      StoryScript.scenes[i].caption,
                      style: SwType.body,
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

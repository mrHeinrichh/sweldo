import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/features/story/domain/story_script.dart';
import 'package:sweldo/features/story/view/story_player.dart';
import 'package:sweldo/features/story/view/story_stage.dart';

import '../../helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  test('scenes are contiguous and cover the whole story', () {
    final scenes = StoryScript.scenes;
    expect(scenes.first.start, 0);
    for (var i = 1; i < scenes.length; i++) {
      expect(scenes[i].start, scenes[i - 1].end);
    }
    expect(StoryScript.sceneAt(0), 0);
    expect(StoryScript.sceneAt(4.49), 0);
    expect(StoryScript.sceneAt(4.5), 1);
    expect(StoryScript.sceneAt(999), scenes.length - 1);
  });

  for (final format in StageFormat.values) {
    testWidgets('every frame of the ${format.name} stage lays out cleanly',
        (tester) async {
      // A frame every quarter second across the film; any overflow or
      // exception fails the test.
      for (var g = 0.0; g <= StoryScript.total; g += 0.25) {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: FittedBox(child: StoryStage(g: g, format: format)),
          ),
        ));
        expect(tester.takeException(), isNull, reason: 'frame at ${g}s');
      }
    });
  }

  testWidgets('the player starts on a poster and plays when asked',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: StoryPlayer())),
    ));
    expect(find.text('Watch Ana get paid'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Play the Sweldo story'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Watch Ana get paid'), findsNothing);
    expect(find.text('0:06 / 0:36'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    expect(find.text('Watch again'), findsOneWidget);
  });
}

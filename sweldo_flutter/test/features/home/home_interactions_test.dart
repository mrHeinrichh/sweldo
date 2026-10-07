import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/features/home/view/payout_stack.dart';
import 'package:sweldo/features/home/view/process_explorer.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/fonts.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('the process explorer plays each step it is given',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: ProcessExplorer())),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    for (final title in [
      '3. Payday unlocks',
      '4. Claim in one tap',
      '5. Take it in pesos',
      '1. Add your team',
    ]) {
      await tester.tap(find.text(title));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull, reason: title);
    }
  });

  testWidgets('the payout stack spreads and stacks on tap', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: PayoutStack3D(assetLabel: 'USDC'))),
    ));
    expect(find.text('Hover or tap to spread the payouts'), findsOneWidget);
    await tester.tap(find.byType(PayoutStack3D));
    await tester.pumpAndSettle();
    expect(find.text('Six paydays, each locked until its date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/core/theme/app_theme.dart';
import 'package:sweldo/features/payroll/view/widgets/roster_import.dart';
import 'ledger_roster_test.dart' show worker;

void main() {
  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1440, 900),
  ]) {
    testWidgets('CSV preview fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SwTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const RosterImportDialog(payouts: 3),
                ),
                child: const Text('Import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'wallet,name,amount,cadence\n$worker,Ana Santos,6,minute',
      );
      await tester.tap(find.text('Preview roster'));
      await tester.pumpAndSettle();
      expect(find.text('1 employees / minute cadence'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Use roster'));
      await tester.pumpAndSettle();
      expect(find.byType(RosterImportDialog), findsNothing);
    });
  }
}

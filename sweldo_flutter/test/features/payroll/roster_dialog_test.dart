import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweldo/core/theme/app_theme.dart';
import 'package:sweldo/features/payroll/data/roster_import.dart';
import 'package:sweldo/features/payroll/domain/pay_cadence.dart';
import 'package:sweldo/features/payroll/view/widgets/roster_import.dart';

import '../../helpers/fonts.dart';
import 'ledger_roster_test.dart' show worker;

void main() {
  setUpAll(loadAppFonts);

  ImportedRoster? result;

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: SwTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showRosterImport(
                context,
                payouts: 3,
                cadence: PayCadence.minute,
              ),
              child: const Text('Import'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(375, 812),
    const Size(812, 375),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'roster import fits and previews at ${size.width}x${size.height}',
      (tester) async {
        await open(tester, size);
        expect(find.text('Fill in the template'), findsOneWidget);
        expect(find.text('Download CSV template'), findsOneWidget);
        expect(find.text('REPLACE_WITH_EMPLOYEE_1_G_ADDRESS'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.enterText(
          find.byType(TextField),
          'wallet,name,amount,cadence\n$worker,Ana Santos,6,minute',
        );
        await tester.ensureVisible(find.text('Preview roster'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Preview roster'));
        await tester.pumpAndSettle();
        expect(find.text('1 employee · minute cadence'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Use roster'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use roster'));
        await tester.pumpAndSettle();
        expect(find.byType(RosterImportSheet), findsNothing);
        expect(result?.rows.single.employee, worker);
        expect(result?.cadence, PayCadence.minute);
      },
    );
  }

  testWidgets(
    'Fill it in here selects the first placeholder, and preview lists every row to fix',
    (tester) async {
      await open(tester, const Size(390, 844));
      await tester.ensureVisible(find.text('Fill it in here'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill it in here'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      final value = field.controller!.value;
      expect(
        value.selection.textInside(value.text),
        'REPLACE_WITH_EMPLOYEE_1_G_ADDRESS',
      );
      expect(field.focusNode!.hasFocus, isTrue);

      await tester.ensureVisible(find.text('Preview roster'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview roster'));
      await tester.pumpAndSettle();
      expect(
        find.text('Fix these 2 problems, then preview again'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Row 3: replace REPLACE_WITH_EMPLOYEE_2_G_ADDRESS'),
        findsOneWidget,
      );
      expect(find.text('Use roster'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sweldo/core/theme/app_theme.dart';
import 'package:sweldo/features/wallet/view/wallet_address_qr.dart';

import '../../helpers/fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  const address = 'GB5OYIHNYJKUP6VFZHYCPLFHBF63SWIDZAPBXET4NKEFLEPWPMKIETPL';

  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets(
      'wallet QR holds only the public address at ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: SwTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => WalletQrButton(address: address),
              ),
            ),
          ),
        );
        await tester.tap(find.text('My wallet QR'));
        await tester.pumpAndSettle();
        expect(find.text('My wallet QR code'), findsOneWidget);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            'QR code of your Stellar public wallet address',
          ),
          findsOneWidget,
        );
        // Shown in groups of four, read out whole.
        expect(find.text('GB5O'), findsOneWidget);
        expect(find.bySemanticsLabel(address), findsOneWidget);
        expect(find.text('Copy wallet address'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Close wallet QR code'));
        await tester.pumpAndSettle();
        expect(find.byType(QrImageView), findsNothing);
      },
    );
  }
}

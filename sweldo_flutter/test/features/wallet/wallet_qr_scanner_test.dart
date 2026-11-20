import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:sweldo/core/theme/app_theme.dart';
import 'package:sweldo/features/wallet/domain/wallet_qr.dart';
import 'package:sweldo/features/wallet/view/wallet_qr_scanner.dart';

import '../../helpers/fonts.dart';

const _address = 'GB5OYIHNYJKUP6VFZHYCPLFHBF63SWIDZAPBXET4NKEFLEPWPMKIETPL';

/// A camera that "sees" whatever the test adds to [captures].
class _Camera extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  int starts = 0;
  int stops = 0;
  int disposals = 0;
  bool running = false;
  bool denyPermission = false;

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    expect(options.formats, [BarcodeFormat.qrCode]);
    if (denyPermission) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    running = true;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    running = false;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
}

void main() {
  setUpAll(loadAppFonts);
  late _Camera camera;
  late MobileScannerPlatform previous;
  String? result;
  var manual = 0;

  setUp(() {
    previous = MobileScannerPlatform.instance;
    camera = _Camera();
    MobileScannerPlatform.instance = camera;
    MobileScannerController.resetPlatformSessionOwner();
    result = null;
    manual = 0;
  });
  tearDown(() async {
    await camera.captures.close();
    MobileScannerPlatform.instance = previous;
    MobileScannerController.resetPlatformSessionOwner();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: SwTheme.light(),
        // Reduced motion holds the scan line still so frames can settle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showWalletQrScanner(
                context,
                onManualEntry: () => manual++,
              ),
              child: const Text('Scan'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
  }

  Future<void> see(WidgetTester tester, List<String> codes) async {
    camera.captures.add(
      BarcodeCapture(
        barcodes: [for (final code in codes) Barcode(rawValue: code)],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('choosing Scan starts the camera; closing turns it off', (
    tester,
  ) async {
    await open(tester);
    expect(camera.starts, 1);
    expect(camera.running, isTrue);
    expect(find.text('Stop camera'), findsOneWidget);
    await tester.tap(find.byTooltip('Close wallet scanner'));
    await tester.pumpAndSettle();
    expect(camera.running, isFalse);
    expect(camera.disposals, greaterThan(0));
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a wrong code is explained while scanning continues; the right one is reviewed first',
    (tester) async {
      await open(tester);
      final secret = KeyPair.random().secretSeed;
      await see(tester, [secret]);
      expect(find.text(walletQrSecret), findsOneWidget);
      expect(find.textContaining(secret), findsNothing);
      expect(camera.running, isTrue);

      await see(tester, [_address, 'another-code']);
      expect(find.textContaining('More than one QR code'), findsOneWidget);
      expect(camera.running, isTrue);

      await see(tester, ['web+stellar:pay?destination=$_address&amount=500']);
      expect(camera.running, isFalse);
      expect(find.text('Wallet address found'), findsOneWidget);
      expect(find.bySemanticsLabel(_address), findsOneWidget);
      expect(result, isNull);
      await tester.ensureVisible(find.text('Use this address'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this address'));
      await tester.pumpAndSettle();
      expect(result, _address);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permission denial explains recovery and hands off to typing', (
    tester,
  ) async {
    camera.denyPermission = true;
    await open(tester);
    expect(
      find.textContaining('Camera access was not allowed.'),
      findsOneWidget,
    );
    expect(find.text('Start camera'), findsOneWidget);
    await tester.ensureVisible(find.text('Enter address manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter address manually'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(manual, 1);
    expect(camera.running, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving the app pauses the camera; coming back does not restart it',
    (tester) async {
      await open(tester);
      expect(camera.running, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
      expect(camera.running, isFalse);
      // A hidden app draws no frames; the paused screen shows on return.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Camera paused'), findsOneWidget);
      expect(camera.starts, 1);
      expect(camera.running, isFalse);
      await tester.tap(find.text('Restart camera'));
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      expect(camera.running, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

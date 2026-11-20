import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/sw_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/sw_button.dart';
import '../../../core/widgets/sw_sheet.dart';
import '../domain/wallet_qr.dart';
import 'wallet_qr_parts.dart';

/// Opens the scanner. Resolves with a reviewed public address, or null. When
/// the person picks "Enter address manually", [onManualEntry] runs once the
/// sheet closes so the caller can focus its own field.
Future<String?> showWalletQrScanner(
  BuildContext context, {
  VoidCallback? onManualEntry,
}) async {
  var manual = false;
  final address = await showSwSheet<String>(
    context,
    maxWidth: 500,
    builder: (_) => WalletQrScanner(onManual: () => manual = true),
  );
  if (manual) onManualEntry?.call();
  return address;
}

enum _Camera { idle, starting, scanning, paused }

/// Reads an employee's public address from the QR code their wallet shows.
/// It only fills the address field; it never signs or pays anything.
/// Mirrors the web app's src/features/wallet/ScanWalletSheet.tsx.
class WalletQrScanner extends StatefulWidget {
  const WalletQrScanner({super.key, this.onManual});

  final VoidCallback? onManual;

  @override
  State<WalletQrScanner> createState() => _WalletQrScannerState();
}

class _WalletQrScannerState extends State<WalletQrScanner>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  _Camera _camera = _Camera.idle;
  bool _readingImage = false;
  bool _handling = false;
  int _generation = 0;
  String? _candidate;
  String? _error;

  bool get _supportsImage =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  MobileScannerController get _scanner =>
      _controller ??= MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Choosing Scan is the request for the camera, so it starts straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startCamera());
    });
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back never restarts the camera by itself.
    if (state == AppLifecycleState.resumed) return;
    // A permission prompt makes the app inactive while the camera starts.
    if (state == AppLifecycleState.inactive &&
        !(_controller?.value.isRunning ?? false)) {
      return;
    }
    if (_camera != _Camera.scanning && _camera != _Camera.starting) return;
    _generation++;
    unawaited(_stopCamera());
    if (mounted) {
      setState(() {
        _camera = _Camera.paused;
        _readingImage = false;
      });
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _controller?.stop();
    } catch (_) {
      /* closing still disposes the controller */
    }
  }

  String _cameraError(Object error) {
    final code = error is MobileScannerException ? error.errorCode : null;
    return switch (code) {
      MobileScannerErrorCode.permissionDenied => 'Camera access was not allowed. Allow the camera for Sweldo in your settings, upload a QR image, or enter the address manually.',
      MobileScannerErrorCode.unsupported =>
        'No camera was found. Upload a QR image or enter the address manually.',
      _ => 'The camera could not start. Try again, upload a QR image, or enter the address manually.',
    };
  }

  Future<void> _startCamera() async {
    if (_readingImage) return;
    final generation = ++_generation;
    setState(() {
      _camera = _Camera.starting;
      _candidate = null;
      _error = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || generation != _generation) return;
    try {
      await _scanner.start();
      if (!mounted || generation != _generation) {
        await _stopCamera();
        return;
      }
      // start() reports a refused permission on the controller, not by
      // throwing, so only a running camera counts as scanning.
      final state = _scanner.value;
      if (!state.isRunning) {
        setState(() {
          _camera = _Camera.idle;
          _error = _cameraError(state.error ?? 'not running');
        });
        return;
      }
      setState(() => _camera = _Camera.scanning);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _camera = _Camera.idle;
        _error = _cameraError(error);
      });
    }
  }

  /// True once an address is found. A wrong code leaves the camera scanning,
  /// so the right one can follow.
  Future<bool> _accept(Iterable<String?> payloads) async {
    if (_handling || !mounted) return false;
    _handling = true;
    try {
      final values = payloads
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .toSet();
      if (values.isEmpty) {
        throw const FormatException(
          'No QR code was found. Try a clearer image with the whole QR code visible.',
        );
      }
      if (values.length != 1) {
        throw const FormatException(
          'More than one QR code was found. Scan one wallet at a time.',
        );
      }
      final address = parseWalletQr(values.single);
      _generation++;
      await _stopCamera();
      if (!mounted) return false;
      unawaited(HapticFeedback.lightImpact());
      setState(() {
        _camera = _Camera.idle;
        _readingImage = false;
        _candidate = address;
        _error = null;
      });
      return true;
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _candidate = null;
          _error = error.message;
        });
      }
      return false;
    } finally {
      _handling = false;
    }
  }

  Future<void> _uploadImage() async {
    if (_readingImage) return;
    _generation++;
    await _stopCamera();
    if (!mounted) return;
    setState(() {
      _camera = _Camera.idle;
      _candidate = null;
      _error = null;
      _readingImage = true;
    });
    try {
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
      );
      if (!mounted || files == null) return;
      final file = files.files.single;
      if (file.size > 10000000 || file.path == null) {
        throw const FormatException(
          'Choose a PNG, JPG, WebP, GIF or BMP image under 10 MB.',
        );
      }
      final capture = await _scanner.analyzeImage(
        file.path!,
        formats: const [BarcodeFormat.qrCode],
      );
      await _accept(capture?.barcodes.map((b) => b.rawValue) ?? const []);
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'This image could not be read. Try a clear screenshot of the QR code.',
        );
      }
    } finally {
      if (mounted) setState(() => _readingImage = false);
    }
  }

  void _close([String? address]) {
    _generation++;
    unawaited(_stopCamera());
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final live = _camera == _Camera.scanning;
    final status = _readingImage
        ? 'Reading your QR image…'
        : switch (_camera) {
            _Camera.scanning => 'Hold the QR code inside the frame. Sweldo stops as soon as it reads one.',
            _Camera.starting => 'Allow camera access if you’re asked.',
            _Camera.paused => 'Start the camera again when you’re ready.',
            _Camera.idle =>
              'Start the camera, or upload a screenshot of the QR code.',
          };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced([
        QrSheetHeading(
          title: 'Scan wallet address',
          closeLabel: 'Close wallet scanner',
          onClose: _close,
        ),
        Text(
          'Scan the QR code in your employee’s Stellar wallet, or upload a screenshot of it.',
          style: SwType.bodySmall,
        ),
        if (candidate == null) ...[
          _frame(context, live),
          Semantics(
            liveRegion: true,
            child: Text(status, style: SwType.caption),
          ),
          QrActions([
            if (live || _camera == _Camera.starting)
              SwButton(
                label: 'Stop camera',
                tone: SwButtonTone.secondary,
                expand: true,
                onPressed: () {
                  _generation++;
                  unawaited(_stopCamera());
                  setState(() => _camera = _Camera.idle);
                },
              )
            else
              SwButton(
                label: _camera == _Camera.paused
                    ? 'Restart camera'
                    : 'Start camera',
                icon: SwIcons.camera,
                expand: true,
                onPressed: _readingImage ? null : _startCamera,
              ),
            if (_supportsImage)
              SwButton(
                label: 'Upload QR image',
                icon: SwIcons.uploadImage,
                tone: SwButtonTone.secondary,
                expand: true,
                loading: _readingImage,
                onPressed: _uploadImage,
              ),
          ]),
        ],
        if (_error case final error?)
          Container(
            padding: const EdgeInsets.all(SwSpace.md),
            decoration: const BoxDecoration(
              color: SwColors.dangerWash,
              borderRadius: BorderRadius.all(SwRadius.field),
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: SwType.bodySmall.copyWith(color: SwColors.danger),
              ),
            ),
          ),
        if (candidate != null) _found(candidate),
        if (candidate == null)
          SwButton(
            label: 'Enter address manually',
            tone: SwButtonTone.quiet,
            expand: true,
            onPressed: () {
              widget.onManual?.call();
              _close();
            },
          ),
        const QrPrivacyNote(
          'QR codes are read on this device. Sweldo never asks for a secret key or recovery phrase.',
        ),
      ]),
    );
  }

  /// Viewfinder: corner brackets in stamp ink, white once the camera is live.
  Widget _frame(BuildContext context, bool live) {
    final height = math
        .min(MediaQuery.sizeOf(context).height * 0.42, 280.0)
        .clamp(180.0, 280.0);
    final showCamera = live || _camera == _Camera.starting;
    return AnimatedContainer(
      duration: SwMotion.of(context, SwMotion.standard),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: live ? SwColors.ink : SwColors.paper,
        borderRadius: const BorderRadius.all(SwRadius.panel),
        border: Border.all(color: live ? SwColors.ink : SwColors.rule),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showCamera)
            Opacity(
              opacity: live ? 1 : 0,
              child: MobileScanner(
                controller: _scanner,
                useAppLifecycleState: false,
                onDetect: (capture) =>
                    unawaited(_accept(capture.barcodes.map((b) => b.rawValue))),
                errorBuilder: (context, error) => ColoredBox(
                  color: SwColors.ink,
                  child: Padding(
                    padding: const EdgeInsets.all(SwSpace.lg),
                    child: Center(
                      child: Text(
                        _cameraError(error),
                        textAlign: TextAlign.center,
                        style: SwType.bodySmall.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!live)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(SwIcons.scan, size: 40, color: SwColors.stamp),
                const SizedBox(height: SwSpace.md),
                Text(switch (_camera) {
                  _Camera.starting => 'Starting your camera…',
                  _Camera.paused => 'Camera paused',
                  _ => 'Camera is off',
                }, style: SwType.caption.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          IgnorePointer(
            child: Center(
              child: FractionallySizedBox(
                heightFactor: 0.74,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _Corners(live ? Colors.white : SwColors.stamp),
                  ),
                ),
              ),
            ),
          ),
          if (live) const _ScanLine(),
        ],
      ),
    );
  }

  Widget _found(String address) {
    final mono = SwType.mono.copyWith(
      color: SwColors.ink,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced([
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: SwColors.paydayWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                SwIcons.check,
                size: 18,
                color: SwColors.payday,
              ),
            ),
            const SizedBox(width: SwSpace.sm),
            Text(
              'Wallet address found',
              style: SwType.subtitle.copyWith(color: SwColors.payday),
            ),
          ],
        ),
        AddressGroups(address),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Check it with your employee: it should start with ',
              ),
              TextSpan(text: address.substring(0, 4), style: mono),
              const TextSpan(text: ' and end with '),
              TextSpan(
                text: address.substring(address.length - 4),
                style: mono,
              ),
              const TextSpan(text: '. Only the address is added.'),
            ],
          ),
          style: SwType.bodySmall,
        ),
        QrActions([
          SwButton(
            label: 'Scan again',
            tone: SwButtonTone.secondary,
            expand: true,
            onPressed: _startCamera,
          ),
          SwButton(
            label: 'Use this address',
            icon: SwIcons.check,
            expand: true,
            onPressed: () => _close(address),
          ),
        ]),
      ]),
    );
  }
}

/// The four bracket corners of the viewfinder.
class _Corners extends CustomPainter {
  const _Corners(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 26.0;
    const radius = Radius.circular(12);
    const stroke = 3.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final r = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    canvas
      ..drawPath(
        Path()
          ..moveTo(r.left, r.top + arm)
          ..lineTo(r.left, r.top + radius.y)
          ..arcToPoint(Offset(r.left + radius.x, r.top), radius: radius)
          ..lineTo(r.left + arm, r.top),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(r.right - arm, r.top)
          ..lineTo(r.right - radius.x, r.top)
          ..arcToPoint(Offset(r.right, r.top + radius.y), radius: radius)
          ..lineTo(r.right, r.top + arm),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(r.left, r.bottom - arm)
          ..lineTo(r.left, r.bottom - radius.y)
          ..arcToPoint(
            Offset(r.left + radius.x, r.bottom),
            radius: radius,
            clockwise: false,
          )
          ..lineTo(r.left + arm, r.bottom),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(r.right - arm, r.bottom)
          ..lineTo(r.right - radius.x, r.bottom)
          ..arcToPoint(
            Offset(r.right, r.bottom - radius.y),
            radius: radius,
            clockwise: false,
          )
          ..lineTo(r.right, r.bottom - arm),
        paint,
      );
  }

  @override
  bool shouldRepaint(_Corners old) => old.color != color;
}

/// A glowing line sweeping the frame while the camera looks for a code.
/// It holds still in the middle when reduced motion is on.
class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SwMotion.reduced(context)) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      unawaited(_sweep.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          final width = math.min(
            box.maxWidth * 0.66,
            MediaQuery.sizeOf(context).width * 0.62,
          );
          return AnimatedBuilder(
            animation: _sweep,
            builder: (context, child) => Align(
              alignment: Alignment(
                0,
                -0.68 + 1.36 * SwMotion.move.transform(_sweep.value),
              ),
              child: child,
            ),
            child: Container(
              width: width,
              height: 2,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(1)),
                gradient: LinearGradient(
                  colors: [
                    Color(0x008069EE),
                    Color(0xFF8069EE),
                    Colors.white,
                    Color(0xFF8069EE),
                    Color(0x008069EE),
                  ],
                  stops: [0, 0.2, 0.5, 0.8, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x8C8069EE),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

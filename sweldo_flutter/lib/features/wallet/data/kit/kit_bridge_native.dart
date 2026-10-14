import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/theme/sw_icons.dart';
import 'kit_bridge.dart';
import 'kit_navigation.dart';

KitBridge createBridge() => _NativeBridge();

class _NativeBridge implements KitBridge {
  Route<Map<String, dynamic>>? _route;
  @override
  bool get available => Platform.isAndroid || Platform.isIOS;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request) async {
    if (_route != null) {
      throw const WalletException('Finish the current wallet request first.');
    }
    final navigator = walletNavigatorKey.currentState;
    if (!available || navigator == null) {
      throw const WalletException(
        'Open Sweldo on an Android/iOS phone or in a browser.',
      );
    }
    final route = MaterialPageRoute<Map<String, dynamic>>(
      builder: (_) => _WalletApproval(request: request),
    );
    _route = route;
    try {
      return await navigator.push(route) ??
          (throw const WalletException(
            'Wallet request cancelled. Nothing was submitted.',
          ));
    } finally {
      if (_route == route) _route = null;
    }
  }

  @override
  void cancel() {
    final route = _route;
    final navigator = walletNavigatorKey.currentState;
    if (route != null && navigator != null && route.isActive) {
      navigator.popUntil((current) => current == route);
      navigator.pop();
    }
  }
}

class _WalletApproval extends StatefulWidget {
  const _WalletApproval({required this.request});
  final Map<String, dynamic> request;
  @override
  State<_WalletApproval> createState() => _WalletApprovalState();
}

class _WalletApprovalState extends State<_WalletApproval> {
  final _nonce = const Uuid().v4();
  bool _started = false;
  bool _settingUpWallet = false;
  bool _finished = false;
  Timer? _timeout;

  void _finish(Map<String, dynamic> result) {
    if (!mounted || _finished) return;
    _finished = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    navigator.popUntil((current) => current == route);
    navigator.pop(result);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('xBull approval')),
    body: InAppWebView(
      initialFile: 'assets/wallet_kit/index.html',
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        javaScriptCanOpenWindowsAutomatically: true,
        supportMultipleWindows: true,
      ),
      onWebViewCreated: (controller) {
        // Only the local bridge gets this handler. The wallet popup never does.
        controller.addJavaScriptHandler(
          handlerName: 'sweldoResult',
          callback: (args) async {
            final url = await controller.getUrl();
            if (url?.scheme != 'file' ||
                !url!.path.endsWith('/assets/wallet_kit/index.html') ||
                args.length != 2 ||
                args[0] != _nonce) {
              return null;
            }
            if (_settingUpWallet) return null;
            try {
              _finish(jsonDecode(args[1] as String) as Map<String, dynamic>);
            } catch (_) {
              _finish({'ok': false, 'error': 'Invalid wallet response.'});
            }
            return null;
          },
        );
      },
      onLoadStop: (controller, url) async {
        if (_started) return;
        _started = true;
        _timeout = Timer(
          const Duration(minutes: 5),
          () => _finish({
            'ok': false,
            'error': 'Wallet approval timed out. Nothing was submitted.',
          }),
        );
        final payload = jsonEncode(jsonEncode(widget.request));
        await controller.evaluateJavascript(
          source:
              '''
          window.SweldoWallets.call($payload)
            .then(result => window.flutter_inappwebview.callHandler('sweldoResult', ${jsonEncode(_nonce)}, result))
            .catch(() => window.flutter_inappwebview.callHandler('sweldoResult', ${jsonEncode(_nonce)}, JSON.stringify({ok:false,error:'Wallet bridge could not start.'})));
        ''',
        );
      },
      onCreateWindow: (controller, action) async {
        if (!mounted) return false;
        // A child WebView preserves window.opener for xBull's encrypted bridge.
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => _WalletPopup(
                windowId: action.windowId,
                onSetup: () {
                  _settingUpWallet = true;
                  _timeout?.cancel();
                },
                onCancel: () => _finish({
                  'ok': false,
                  'error': 'Wallet request cancelled. Nothing was submitted.',
                }),
              ),
            ),
          ),
        );
        return true;
      },
    ),
  );
}

class _WalletPopup extends StatefulWidget {
  const _WalletPopup({
    required this.windowId,
    required this.onCancel,
    required this.onSetup,
  });
  final int windowId;
  final VoidCallback onCancel;
  final VoidCallback onSetup;
  @override
  State<_WalletPopup> createState() => _WalletPopupState();
}

class _WalletPopupState extends State<_WalletPopup> {
  InAppWebViewController? _controller;
  bool _settingUp = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(SwIcons.close),
        tooltip: 'Cancel wallet request',
        onPressed: widget.onCancel,
      ),
      title: const Text('wallet.xbull.app'),
      actions: [
        IconButton(
          icon: const Icon(SwIcons.browser),
          tooltip: 'Open xBull wallet',
          onPressed: () {
            _settingUp = true;
            widget.onSetup();
            _controller?.loadUrl(
              urlRequest: URLRequest(url: WebUri('https://wallet.xbull.app/')),
            );
          },
        ),
      ],
    ),
    body: InAppWebView(
      windowId: widget.windowId,
      onWebViewCreated: (controller) => _controller = controller,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
      ),
      shouldOverrideUrlLoading: (controller, action) async {
        final uri = action.request.url;
        return uri?.toString() == 'about:blank' ||
                (uri?.scheme == 'https' && uri?.host == 'wallet.xbull.app')
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onCloseWindow: (_) {
        if (!mounted || _settingUp) return;
        final route = ModalRoute.of(context);
        if (route == null || !route.isActive) return;
        final navigator = Navigator.of(context);
        // A delayed close belongs to this popup, not a newer signing window.
        if (route.isCurrent) {
          navigator.pop();
        } else {
          navigator.removeRoute(route);
        }
      },
    ),
  );
}

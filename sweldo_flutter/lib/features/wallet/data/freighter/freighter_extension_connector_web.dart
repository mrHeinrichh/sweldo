import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/wallet_session.dart';
import '../wallet_connector.dart';
import 'freighter_js.dart';

const _freighterMissing =
    'Freighter is not available. Install it from freighter.app, or open '
    'chrome://extensions, enable Freighter, set Site access to “On all '
    'sites”, unlock it, then reload this tab.';

/// Freighter browser extension, reached through `@stellar/freighter-api`.
///
/// A direct port of `connectWallet` in the React app, including its retries:
/// the extension injects its content script after page load, so one early
/// check can miss it.
class FreighterExtensionConnector extends WalletConnector {
  @override
  WalletKind get kind => WalletKind.freighterExtension;

  /// Phones run no browser extensions; Flutter web reports the device here.
  bool get _phone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get isAvailable => !_phone;

  @override
  String? get unavailableReason => _phone
      ? 'Browser extensions aren’t available on phones. Use the Freighter app.'
      : null;

  FreighterApi get _api {
    final api = freighterApi;
    if (api == null) {
      throw const WalletException(_freighterMissing, walletMissing: true);
    }
    return api;
  }

  Future<FreighterResult> _call(
    JSPromise<FreighterResult> Function(FreighterApi api) call, {
    required Duration timeout,
  }) {
    return call(_api).toDart.timeout(
      timeout,
      onTimeout: () => throw const WalletException(
        'Freighter did not respond. Unlock the extension and try again.',
      ),
    );
  }

  FreighterResult _unwrap(FreighterResult result, String label) {
    final error = result.error;
    if (error != null) throw WalletException('$label: ${error.describe()}');
    return result;
  }

  Future<bool> _detect() async {
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    do {
      try {
        final result = await _call(
          (api) => api.isConnected(),
          timeout: const Duration(milliseconds: 1500),
        );
        if (result.error == null && (result.isConnected ?? false)) return true;
      } catch (_) {
        // Not ready yet; retry.
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } while (DateTime.now().isBefore(deadline));
    return false;
  }

  Future<String> _network() async {
    final result = _unwrap(
      await _call(
        (api) => api.getNetwork(),
        timeout: const Duration(seconds: 5),
      ),
      'Could not read wallet network',
    );
    return result.network ?? '';
  }

  @override
  Future<WalletSession> connect({void Function(Uri uri)? onPairingUri}) async {
    // If detection fails we still call requestAccess: it talks to the
    // extension directly and surfaces a precise error (locked, denied, or
    // missing).
    final detected = await _detect();

    FreighterResult access;
    try {
      access = await _call(
        (api) => api.requestAccess(),
        timeout: const Duration(seconds: 30),
      );
    } on WalletException {
      if (!detected) {
        throw const WalletException(_freighterMissing, walletMissing: true);
      }
      rethrow;
    }
    _unwrap(access, 'Could not connect Freighter');
    var address = access.address ?? '';

    if (address.isEmpty) {
      // Some Freighter builds answer requestAccess without a key until the
      // site is on the allow list. Allow it, then read the active account.
      try {
        final allowed = await _call(
          (api) => api.isAllowed(),
          timeout: const Duration(seconds: 3),
        );
        if (!(allowed.isAllowed ?? false)) {
          await _call(
            (api) => api.setAllowed(),
            timeout: const Duration(seconds: 30),
          );
        }
        final active = await _call(
          (api) => api.getAddress(),
          timeout: const Duration(seconds: 5),
        );
        if (active.error == null) address = active.address ?? '';
      } catch (_) {
        // Fall through to the error below.
      }
    }

    final network = await _network();
    if (address.isEmpty) {
      throw const WalletException(
        'Freighter did not return an account. Open Freighter, unlock it, '
        'select an account, approve this site, then try again.',
      );
    }
    return WalletSession(address: address, network: network, kind: kind);
  }

  @override
  Future<WalletSession?> restore() async {
    if (freighterApi == null || !await _detect()) return null;
    try {
      final allowed = await _call(
        (api) => api.isAllowed(),
        timeout: const Duration(seconds: 3),
      );
      if (!(allowed.isAllowed ?? false)) return null;
      return await currentSession();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<WalletSession> currentSession() async {
    final active = _unwrap(
      await _call(
        (api) => api.getAddress(),
        timeout: const Duration(seconds: 5),
      ),
      'Could not read the Freighter account',
    );
    final address = active.address ?? '';
    if (address.isEmpty) {
      throw const WalletException(
        'Freighter is locked. Unlock it and reconnect.',
      );
    }
    return WalletSession(
      address: address,
      network: await _network(),
      kind: kind,
    );
  }

  @override
  Future<String> signTransaction(
    String envelopeXdr, {
    required String address,
    required String networkPassphrase,
  }) async {
    final result = _unwrap(
      await _call(
        (api) => api.signTransaction(
          envelopeXdr,
          FreighterSignOptions(
            networkPassphrase: networkPassphrase,
            address: address,
          ),
        ),
        timeout: const Duration(minutes: 5),
      ),
      'Freighter could not sign the transaction',
    );
    final signed = result.signedTxXdr;
    if (signed == null || signed.isEmpty) {
      throw const WalletException(
        'Signing was cancelled. Nothing was submitted.',
      );
    }
    return signed;
  }

  /// The extension keeps its own allow list; forgetting the session here is
  /// all a dApp can do.
  @override
  Future<void> disconnect() async {}
}

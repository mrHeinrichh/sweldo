import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Links into the Freighter app, and to its store pages when it isn't
/// installed.
abstract final class FreighterLinks {
  static const scheme = 'freighterwallet';

  /// Freighter's registered WalletConnect link (its `mobile.native` entry in
  /// the WalletConnect registry). The app only pairs when the link contains
  /// it, so the generic `freighterwallet://wc?uri=` is ignored.
  static const nativeLink = '$scheme://wc-redirect';

  static final appStore = Uri.parse(
    'https://apps.apple.com/app/freighter/id6743947720',
  );
  static final playStore = Uri.parse(
    'https://play.google.com/store/apps/details?id=org.stellar.freighterwallet',
  );
  static final website = Uri.parse('https://www.freighter.app/');

  static bool get onPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Opens Freighter in front of the person, without pairing.
  static Uri get app => Uri.parse('$scheme://');

  /// Opens Freighter with a WalletConnect pairing request.
  static Uri pair(Uri pairingUri) =>
      Uri.parse('$nativeLink?uri=${Uri.encodeComponent('$pairingUri')}');

  /// Where to get Freighter on this device.
  static Uri get store => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => appStore,
    TargetPlatform.android => playStore,
    _ => website,
  };

  static String get storeName => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'the App Store',
    TargetPlatform.android => 'Google Play',
    _ => 'freighter.app',
  };

  /// Whether the Freighter app is on this phone. Only the native app can
  /// tell (iOS `LSApplicationQueriesSchemes` and Android `<queries>` list
  /// [scheme]); browsers and computers answer false and keep the store link.
  static Future<bool> isInstalled() async {
    if (kIsWeb || !onPhone) return false;
    try {
      return await canLaunchUrl(app);
    } catch (_) {
      return false;
    }
  }

  /// Opens [link] in Freighter. When Freighter isn't installed and
  /// [storeFallback] is on, opens its store page instead. Returns whether
  /// Freighter opened.
  static Future<bool> open(Uri link, {bool storeFallback = true}) async {
    var opened = false;
    try {
      opened = await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && storeFallback && onPhone) {
      try {
        await launchUrl(store, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Nothing more to try; the sheet still shows the store link.
      }
    }
    return opened;
  }
}

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Archivo — a grotesque drawn for print forms and screens — carries the
/// interface. IBM Plex Mono is reserved for machine strings people compare
/// character by character: wallet keys, balance IDs and transaction hashes.
///
/// Sizes follow the classic typographic scale: 12, 14, 16, 18, 21, 24, 36, 48.
abstract final class SwType {
  static const family = 'Archivo';
  static const monoFamily = 'IBMPlexMono';

  static const _tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontFamily: family,
    fontSize: 48,
    height: 1.02,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.6,
    color: SwColors.ink,
  );

  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 36,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: SwColors.ink,
  );

  static const title = TextStyle(
    fontFamily: family,
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: SwColors.ink,
  );

  static const subtitle = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: SwColors.ink,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: SwColors.ink,
  );

  static const bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: SwColors.inkMuted,
  );

  static const label = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: SwColors.ink,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: SwColors.inkMuted,
  );

  /// Money. Tabular figures so amounts line up in a column.
  static const amount = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: SwColors.ink,
    fontFeatures: _tabular,
  );

  static const amountLarge = TextStyle(
    fontFamily: family,
    fontSize: 36,
    height: 1.05,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: SwColors.ink,
    fontFeatures: _tabular,
  );

  static const figures = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: SwColors.ink,
    fontFeatures: _tabular,
  );

  static const mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: SwColors.inkMuted,
  );
}

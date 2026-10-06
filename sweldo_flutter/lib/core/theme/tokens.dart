import 'package:flutter/material.dart';

/// Sweldo's palette comes from the paperwork of Filipino payday:
/// greenbar payroll printouts, ballpoint ink, and violet rubber-stamp ink.
abstract final class SwColors {
  /// Greenbar continuous-form paper; the app background.
  static const paper = Color(0xFFF2F5F0);

  /// The pale band printed on every other row of a payroll printout.
  static const greenbar = Color(0xFFE1EBDD);

  /// Surfaces that hold forms and lists.
  static const sheet = Color(0xFFFCFDFB);

  /// Hairlines and field outlines.
  static const rule = Color(0xFFD2DBCF);

  /// Ballpoint navy for all text.
  static const ink = Color(0xFF14213A);
  static const inkMuted = Color(0xFF52607A);
  static const inkFaint = Color(0xFF7D8799);

  /// Violet stamp-pad ink: primary actions and the "claimed" stamp.
  static const stamp = Color(0xFF5B3CC4);
  static const stampDeep = Color(0xFF452C9E);
  static const stampWash = Color(0xFFEDE8FB);

  /// Payday green: money that can be claimed now.
  static const payday = Color(0xFF1C7449);
  static const paydayWash = Color(0xFFDCEFE2);

  /// Locked graphite.
  static const locked = Color(0xFF66708A);

  static const danger = Color(0xFFB3261E);
  static const dangerWash = Color(0xFFFBE8E6);
  static const caution = Color(0xFF8F5207);
  static const cautionWash = Color(0xFFFCEFD9);
}

abstract final class SwSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
}

/// Radius follows hierarchy: the bigger and more "held" an object, the softer.
abstract final class SwRadius {
  static const card = Radius.circular(6);
  static const field = Radius.circular(10);
  static const panel = Radius.circular(14);
  static const sheet = Radius.circular(22);
}

abstract final class SwBreakpoints {
  static const wide = 960.0;
  static const medium = 640.0;
  static const maxContent = 1120.0;
}

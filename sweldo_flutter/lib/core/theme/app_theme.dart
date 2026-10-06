import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

abstract final class SwTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: SwColors.stamp,
      onPrimary: Colors.white,
      primaryContainer: SwColors.stampWash,
      onPrimaryContainer: SwColors.stampDeep,
      secondary: SwColors.payday,
      onSecondary: Colors.white,
      secondaryContainer: SwColors.paydayWash,
      onSecondaryContainer: SwColors.payday,
      error: SwColors.danger,
      onError: Colors.white,
      errorContainer: SwColors.dangerWash,
      onErrorContainer: SwColors.danger,
      surface: SwColors.paper,
      onSurface: SwColors.ink,
      onSurfaceVariant: SwColors.inkMuted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: SwColors.sheet,
      surfaceContainer: SwColors.sheet,
      surfaceContainerHigh: SwColors.greenbar,
      outline: SwColors.rule,
      outlineVariant: SwColors.rule,
    );

    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(SwRadius.field),
      borderSide: BorderSide(color: SwColors.rule),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: SwColors.paper,
      fontFamily: SwType.family,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .copyWith(
            displayLarge: SwType.display,
            headlineLarge: SwType.headline,
            titleLarge: SwType.title,
            titleMedium: SwType.subtitle,
            bodyLarge: SwType.body,
            bodyMedium: SwType.body.copyWith(fontSize: 15),
            bodySmall: SwType.bodySmall,
            labelLarge: SwType.label,
            labelSmall: SwType.caption,
          )
          .apply(displayColor: SwColors.ink, bodyColor: SwColors.ink),
      dividerTheme: const DividerThemeData(
        color: SwColors.rule,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SwSpace.md,
          vertical: 14,
        ),
        hintStyle: SwType.body.copyWith(color: SwColors.inkFaint),
        labelStyle: SwType.label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: SwColors.stamp, width: 1.6),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: SwColors.danger),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: SwColors.danger, width: 1.6),
        ),
        errorStyle: SwType.caption.copyWith(color: SwColors.danger),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: SwColors.sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(SwRadius.sheet),
        ),
        titleTextStyle: SwType.title,
        contentTextStyle: SwType.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SwColors.sheet,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: SwColors.rule,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: SwRadius.sheet),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: SwColors.ink,
        contentTextStyle: SwType.label.copyWith(color: Colors.white),
        actionTextColor: const Color(0xFFC9BBFF),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(SwRadius.field),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: SwColors.ink,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: SwType.caption.copyWith(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SwColors.stamp,
        linearTrackColor: SwColors.greenbar,
      ),
      focusColor: SwColors.stamp.withValues(alpha: 0.14),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: SwColors.paper,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: SwColors.paper,
          ),
          TargetPlatform.windows: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: SwColors.paper,
          ),
          TargetPlatform.linux: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: SwColors.paper,
          ),
        },
      ),
    );
  }
}

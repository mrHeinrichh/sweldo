import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'layout.dart';

/// A dialog on wide screens and a bottom sheet with a drag handle on phones,
/// like the web app's `Sheet`. [builder] gets the sheet's own context, so
/// `Navigator.pop(context, value)` resolves the returned future.
Future<T?> showSwSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 460,
}) {
  if (isWide(context)) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(SwSpace.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SwSpace.xl),
            child: builder(dialogContext),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    // Above the bottom navigation, as the web sheet covers the whole page.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      // Lift the sheet above the keyboard while someone types in it.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              SwSpace.xl,
              0,
              SwSpace.xl,
              SwSpace.xl,
            ),
            child: builder(sheetContext),
          ),
        ),
      ),
    ),
  );
}

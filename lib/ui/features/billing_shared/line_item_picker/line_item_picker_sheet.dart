import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_body.dart';
import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_result.dart';
import 'package:admin/utils/formatting.dart';

/// Tabbed multi-select picker for adding many products / tasks / expenses to
/// a billing-doc draft in one go. Returns the converted line items + an
/// optional `projectIdHint` from the first picked task that carries one, or
/// `null` when the user cancels.
///
/// Responsive chrome: a centered `Dialog` at ≥720 px, a `showModalBottomSheet`
/// below. Same body widget in both — the chrome difference is purely visual.
/// The wide-window dialog matches admin-portal's pattern; the narrow-window
/// bottom sheet matches v2's modal idiom.
Future<LineItemPickerResult?> showLineItemPickerSheet(
  BuildContext context, {
  required String companyId,
  required String clientId,
  required bool showTasksAndExpenses,
  required bool invoiceInclusive,
  Set<String> excludedTaskIds = const {},
  Set<String> excludedExpenseIds = const {},
  Set<String> headedProjectIds = const {},
  Formatter? formatter,
  bool showStockQuantity = false,
}) {
  final size = MediaQuery.of(context).size;
  final wide = size.width >= 720;
  if (wide) {
    final tokens = context.inTheme;
    final dialogWidth = math.min<double>(720, size.width - 48);
    // Cap, not target: the body sizes to the active tab's content and
    // grows only as needed up to this height; short lists produce a
    // compact dialog instead of ⅔ of empty space.
    final maxDialogHeight = math.min<double>(700, size.height * 0.85);
    return showDialog<LineItemPickerResult>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: tokens.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r3),
        ),
        // No fixed `height:` — width stays pinned at 720, height is
        // driven by `LineItemPickerBody`'s `maxHeight` constraint.
        child: SizedBox(
          width: dialogWidth,
          child: LineItemPickerBody(
            companyId: companyId,
            clientId: clientId,
            showTasksAndExpenses: showTasksAndExpenses,
            invoiceInclusive: invoiceInclusive,
            excludedTaskIds: excludedTaskIds,
            excludedExpenseIds: excludedExpenseIds,
            headedProjectIds: headedProjectIds,
            formatter: formatter,
            showStockQuantity: showStockQuantity,
            maxHeight: maxDialogHeight,
          ),
        ),
      ),
    );
  }
  // Narrow window — slide up from the bottom; cap at 0.85·screen so the
  // sheet leaves a comfortable peek above it. `showDragHandle: true`
  // surfaces the Material 3 indicator at the top of the sheet so the
  // swipe-down affordance is visible — matches `multi_pick_sheet.dart`
  // and `entity_list_app_bar.dart` v2 conventions.
  return showModalBottomSheet<LineItemPickerResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final tokens = ctx.inTheme;
      // Keyboard-aware, in both directions. The sheet is bottom-anchored and
      // sizes to its content, so as soon as the filter matched nothing the
      // body shrank to the empty-state message — and the whole picker slid in
      // behind the on-screen keyboard, looking like it had vanished
      // (invoiceninja/flutter#86). `showModalBottomSheet` applies no
      // `viewInsets` padding of its own, and `SafeArea` covers system chrome,
      // not the keyboard. Lifting the sheet by the inset keeps it visible;
      // subtracting the inset from the cap stops the 85 % ceiling being
      // measured against a screen height the keyboard has already taken half
      // of, which would push the header off the top.
      final insets = MediaQuery.viewInsetsOf(ctx).bottom;
      final maxHeight = (MediaQuery.of(ctx).size.height - insets) * 0.85;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: Material(
          color: tokens.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(InRadii.r3)),
          child: SafeArea(
            top: false,
            child: LineItemPickerBody(
              companyId: companyId,
              clientId: clientId,
              showTasksAndExpenses: showTasksAndExpenses,
              invoiceInclusive: invoiceInclusive,
              excludedTaskIds: excludedTaskIds,
              excludedExpenseIds: excludedExpenseIds,
              headedProjectIds: headedProjectIds,
              formatter: formatter,
              showStockQuantity: showStockQuantity,
              maxHeight: maxHeight,
            ),
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/shortcut_hint_scope.dart';

/// Items-section "Add items" FAB shared across the five billing-doc edit
/// layouts (Invoice / Quote / Credit / RecurringInvoice / PurchaseOrder).
/// Opens the products/tasks/expenses multi-select picker.
///
/// Renders identically on desktop and mobile — its placement (always-visible
/// page overlay on desktop; Items-tab-only overlay on mobile) is each
/// layout's responsibility, so the FAB widget itself stays chrome-agnostic.
class BillingDocEditFab extends StatelessWidget {
  const BillingDocEditFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
  });

  /// Distinct per entity (`'invoice_picker_fab'`, …) so multiple edit
  /// screens stacked in master-detail don't share a Hero.
  final String heroTag;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      tooltip: context.tr('add_items'),
      onPressed: onPressed,
      child: const Icon(Icons.add),
    );
  }
}

/// Cmd-N (macOS) / Ctrl-N (Linux/Windows/web) → invoke [onPickItems].
/// Matches v2's "n = new" list-screen convention, lifted into the
/// edit-screen context where it means "add line items via the picker."
///
/// Wrap any portion of the edit screen with this — Shortcuts only fire when
/// the wrapped subtree owns focus. On desktop the whole page should wrap;
/// on the mobile tabbed layout, wrap only the Items tab so the shortcut
/// stays contextual.
class BillingDocEditPickerShortcuts extends StatelessWidget {
  const BillingDocEditPickerShortcuts({
    super.key,
    required this.onPickItems,
    required this.child,
  });

  final VoidCallback onPickItems;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShortcutHintScope(
      hints: [
        ShortcutHint(
          keys: [platformModifierLabel(), 'N'],
          labelKey: 'add_items',
        ),
      ],
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              const _PickItemsIntent(),
          const SingleActivator(LogicalKeyboardKey.keyN, control: true):
              const _PickItemsIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PickItemsIntent: CallbackAction<_PickItemsIntent>(
              onInvoke: (_) {
                onPickItems();
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }
}

class _PickItemsIntent extends Intent {
  const _PickItemsIntent();
}

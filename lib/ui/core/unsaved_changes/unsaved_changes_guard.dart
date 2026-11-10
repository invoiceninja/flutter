import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Tracks every visible editor that has unsaved in-memory edits, and gates
/// navigation that would discard them.
///
/// Each editor calls [register] when it mounts, passing an `isDirty` getter,
/// a `Listenable` to subscribe to for change notifications, and an optional
/// `onDiscard` callback that resets the editor's draft. The returned function
/// is called by the editor on dispose to unregister.
///
/// Navigation entry points (PopScope, branch switch, settings sidebar tile,
/// company picker) call [confirmIfDirty] before navigating. If any registered
/// editor reports dirty, the user is prompted; on Discard, each dirty entry's
/// `onDiscard` runs so the editor's state is cleared.
///
/// This sits in the [Services] bag (`services.unsavedChangesGuard`) and is
/// app-wide — multiple editors can be registered simultaneously (e.g. the
/// company-details shell preserved in one branch and a brand-new client edit
/// screen in another).
class UnsavedChangesGuard extends ChangeNotifier {
  final List<_Entry> _entries = [];

  /// True when any registered editor reports dirty right now.
  bool get hasUnsaved => _entries.any((e) => e.isDirty());

  /// Register an editor. Returns the dispose callback — the caller must
  /// invoke it on unmount so the entry doesn't outlive the widget.
  ///
  /// [blockedMessage] makes the entry one that can't be discarded at all —
  /// a card payment under way, whose server calls are bound to this
  /// company: while it is dirty, leaving is refused with that message.
  VoidCallback register({
    required bool Function() isDirty,
    required Listenable source,
    VoidCallback? onDiscard,
    String Function(BuildContext context)? blockedMessage,
  }) {
    final entry = _Entry(
      isDirty: isDirty,
      source: source,
      onDiscard: onDiscard,
      blockedMessage: blockedMessage,
    );
    source.addListener(_bump);
    _entries.add(entry);
    _bump();
    return () {
      source.removeListener(_bump);
      _entries.remove(entry);
      _bump();
    };
  }

  /// Returns `true` if navigation may proceed (nothing dirty, or the user
  /// picked Discard). On Discard, every currently-dirty entry's `onDiscard`
  /// is invoked so the editor resets to its last-saved state — without this
  /// a user who picked Discard but stayed in the shell would see their edits
  /// re-appear the next time the screen rebuilds.
  Future<bool> confirmIfDirty(BuildContext context) async {
    if (!hasUnsaved) return true;
    final blocked = _entries
        .where((e) => e.blockedMessage != null && e.isDirty())
        .firstOrNull;
    if (blocked != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(blocked.blockedMessage!(ctx)),
          actions: [
            PrimaryDialogAction(
              label: ctx.tr('ok'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return false;
    }
    final discard = await showDiscardChangesDialog(context);
    if (!discard) return false;
    for (final entry in _entries.toList()) {
      if (entry.isDirty()) entry.onDiscard?.call();
    }
    return true;
  }

  void _bump() {
    notifyListeners();
  }

  @visibleForTesting
  int get registeredCount => _entries.length;
}

class _Entry {
  _Entry({
    required this.isDirty,
    required this.source,
    this.onDiscard,
    this.blockedMessage,
  });
  final bool Function() isDirty;
  final Listenable source;
  final VoidCallback? onDiscard;
  final String Function(BuildContext context)? blockedMessage;
}

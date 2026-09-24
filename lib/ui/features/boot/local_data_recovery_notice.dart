import 'package:flutter/material.dart';

import 'package:admin/data/db/salvage.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

/// What the user is told after a reset of their local data.
enum LocalDataNoticeKind {
  /// Everything the store held that the server doesn't was carried across;
  /// only the cache downloads again. A toast.
  rebuilt,

  /// The store was rebuilt, but some of what it held did not come across. The
  /// old copy is kept. A dialog.
  partlyRecovered,

  /// Nothing could be read out of the old store. The copy is kept. A dialog.
  notRecovered,

  /// The store was reset with nothing to carry across — on web, which has no
  /// reader for an abandoned store yet. A dialog.
  reset,
}

/// What to tell the user about a reset of their local data, or null when
/// there was none. [recovery] is what `openAppDatabase` carried across (or
/// failed to); [wasReset] with no [recovery] is a reset nothing was read out
/// of. A recovery arriving without [wasReset] is an earlier launch's reset,
/// salvaged on this open — still news to the user.
({LocalDataNoticeKind kind, int unsynced})? localDataNoticeFor({
  required bool wasReset,
  required LocalDataRecovery? recovery,
}) => switch (recovery) {
  LocalDataSalvaged(incompleteTables: [], :final unsyncedChanges) => (
    kind: LocalDataNoticeKind.rebuilt,
    unsynced: unsyncedChanges,
  ),
  LocalDataSalvaged(:final unsyncedChanges) => (
    kind: LocalDataNoticeKind.partlyRecovered,
    unsynced: unsyncedChanges,
  ),
  LocalDataUnrecoverable() => (
    kind: LocalDataNoticeKind.notRecovered,
    unsynced: 0,
  ),
  null => wasReset ? (kind: LocalDataNoticeKind.reset, unsynced: 0) : null,
};

/// Tells the user, once, what a reset of their local data did. Before this
/// the outcome reached only the diagnostics log, so a user whose unsynced
/// changes could not be recovered was never told — and one whose changes all
/// came across watched their lists empty and refill with no explanation.
///
/// Paints nothing. Mounted in `MaterialApp.router`'s builder beside
/// `CallLogPrompter`, so — like it — it needs [contextOf] for a context
/// **inside** the router's `Navigator`: its own sits above it. The dialog
/// cases are the ones where the user may have lost work, which a toast could
/// scroll past unread.
class LocalDataRecoveryNotice extends StatefulWidget {
  const LocalDataRecoveryNotice({
    required this.wasReset,
    required this.recovery,
    required this.toasts,
    this.contextOf,
    super.key,
  });

  final bool wasReset;
  final LocalDataRecovery? recovery;
  final ToastController toasts;

  /// Supplies a context inside the router's `Navigator`. Null falls back to
  /// this widget's own context, which is what a test pumping it under a
  /// `MaterialApp` wants.
  final BuildContext? Function()? contextOf;

  @override
  State<LocalDataRecoveryNotice> createState() =>
      _LocalDataRecoveryNoticeState();
}

class _LocalDataRecoveryNoticeState extends State<LocalDataRecoveryNotice> {
  /// The router's `Navigator` exists only after the first frame; a few more
  /// frames covers the boot redirect chain without ever spinning forever.
  static const _kMaxFramesToWait = 10;

  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (localDataNoticeFor(
          wasReset: widget.wasReset,
          recovery: widget.recovery,
        ) !=
        null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(0));
    }
  }

  void _show(int framesWaited) {
    if (!mounted || _shown) return;
    final notice = localDataNoticeFor(
      wasReset: widget.wasReset,
      recovery: widget.recovery,
    );
    if (notice == null) return;
    final target = widget.contextOf?.call() ?? context;
    if (!target.mounted || Navigator.maybeOf(target) == null) {
      if (framesWaited < _kMaxFramesToWait) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _show(framesWaited + 1),
        );
      }
      return;
    }
    _shown = true;
    final dialog = switch (notice.kind) {
      LocalDataNoticeKind.rebuilt => null,
      LocalDataNoticeKind.partlyRecovered => (
        'local_data_partly_recovered',
        'local_data_partly_recovered_body',
      ),
      LocalDataNoticeKind.notRecovered => (
        'local_data_not_recovered',
        'local_data_not_recovered_body',
      ),
      LocalDataNoticeKind.reset => (
        'local_data_reset',
        'local_data_reset_body',
      ),
    };
    if (dialog == null) {
      widget.toasts.info(
        target.tr('local_data_rebuilt'),
        detail: switch (notice.unsynced) {
          0 => target.tr('local_data_rebuilt_nothing_pending'),
          1 => target.tr('local_data_rebuilt_kept_singular'),
          final n => target.tr('local_data_rebuilt_kept_plural', {
            'count': '$n',
          }),
        },
      );
      return;
    }
    final (titleKey, bodyKey) = dialog;
    showDialog<void>(
      context: target,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr(titleKey)),
        content: Text(dialogContext.tr(bodyKey)),
        actions: [
          PrimaryDialogAction(
            label: dialogContext.tr('close'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

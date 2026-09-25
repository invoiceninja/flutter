import 'package:flutter/foundation.dart';
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

/// What to tell the user about this launch's reset, taken at most once — the
/// once-only guard, kept above the widget that shows it. Create it once, in
/// the app's State, never in a build method: a remount of the notice then
/// finds it taken and says nothing more. In the notice's own State, the guard
/// went with a remount, and the user was told twice.
class LocalDataNoticeSlot {
  LocalDataNoticeSlot({
    required bool wasReset,
    required LocalDataRecovery? recovery,
  }) : _notice = localDataNoticeFor(wasReset: wasReset, recovery: recovery);

  ({LocalDataNoticeKind kind, int unsynced})? _notice;

  /// Whether there is still something to tell.
  bool get isPending => _notice != null;

  /// The notice, once; null ever after.
  ({LocalDataNoticeKind kind, int unsynced})? take() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  /// A wipe of the local data — a sign-out, or a sign-in by someone else —
  /// makes the toast untrue: it counts unsynced changes as kept. A dialog
  /// stays true, wipe or not: the work it says was lost stays lost, and the
  /// copy it points to is kept.
  void forgetKeptChanges() {
    if (_notice?.kind == LocalDataNoticeKind.rebuilt) _notice = null;
  }
}

/// When the reset notice waits: behind the biometric lock, and while no one
/// is signed in. Released on the lock alone, the lock screen's Sign out let it
/// show on `/login`, saying changes were kept that the sign-out had just
/// wiped. Held through a sign-out instead, it is told after the next sign-in —
/// less a toast the wipe made untrue ([LocalDataNoticeSlot.forgetKeptChanges],
/// through `AuthRepository.onBeforeDataWipe`).
class LocalDataNoticeHold extends ValueNotifier<bool> {
  LocalDataNoticeHold({
    required Listenable triggers,
    required bool Function() held,
  }) : _triggers = triggers,
       _held = held,
       super(held()) {
    _triggers.addListener(_update);
  }

  final Listenable _triggers;
  final bool Function() _held;

  void _update() => value = _held();

  @override
  void dispose() {
    _triggers.removeListener(_update);
    super.dispose();
  }
}

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
    required this.slot,
    required this.holdWhile,
    required this.toasts,
    this.contextOf,
    super.key,
  });

  final LocalDataNoticeSlot slot;

  /// While true — the biometric lock screen is up, or no one is signed in
  /// ([LocalDataNoticeHold]) — nothing is shown. A dialog pushed over `/lock`
  /// went with its page when unlocking replaced it, and the user was never
  /// told; a toast expired behind the unlock prompt.
  final ValueListenable<bool> holdWhile;
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
  /// Waiting out the lock is a listener instead: unlocking takes as long as
  /// the user does, and an idle lock screen draws no frames.
  static const _kMaxFramesToWait = 10;

  bool _holding = false;

  @override
  void initState() {
    super.initState();
    if (widget.slot.isPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(0));
    }
  }

  @override
  void didUpdateWidget(LocalDataRecoveryNotice old) {
    super.didUpdateWidget(old);
    if (_holding && old.holdWhile != widget.holdWhile) {
      old.holdWhile.removeListener(_onHoldChanged);
      widget.holdWhile.addListener(_onHoldChanged);
      // One that has already let go says so to no listener.
      _onHoldChanged();
    }
  }

  @override
  void dispose() {
    if (_holding) widget.holdWhile.removeListener(_onHoldChanged);
    super.dispose();
  }

  void _onHoldChanged() {
    if (widget.holdWhile.value) return;
    widget.holdWhile.removeListener(_onHoldChanged);
    _holding = false;
    // The router swaps the lock screen's page out on the next frame: show
    // above whatever replaces it. That swap is what asks for the frame in the
    // app; ask here too, so the notice never depends on it.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _show(0))
      ..ensureVisualUpdate();
  }

  void _show(int framesWaited) {
    if (!mounted || !widget.slot.isPending) return;
    if (widget.holdWhile.value) {
      if (!_holding) {
        _holding = true;
        widget.holdWhile.addListener(_onHoldChanged);
      }
      return;
    }
    final target = widget.contextOf?.call() ?? context;
    if (!target.mounted || Navigator.maybeOf(target) == null) {
      if (framesWaited < _kMaxFramesToWait) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _show(framesWaited + 1),
        );
      }
      return;
    }
    final notice = widget.slot.take();
    if (notice == null) return;
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

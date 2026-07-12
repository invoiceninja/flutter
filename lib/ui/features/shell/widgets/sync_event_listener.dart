import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';
import 'package:admin/ui/core/widgets/conflict_resolution_sheet.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/tokens/widgets/token_created_dialog.dart';

final _log = Logger('SyncEventListener');

/// Wraps the shell's subtree and listens to `services.sync.events`. When a
/// [PasswordRequiredEvent] arrives, opens [ConfirmPasswordSheet]; when a
/// [ConflictEvent] arrives, opens [ConflictResolutionSheet] and routes the
/// user's choice to the appropriate repo action. Also surfaces one-time API
/// token secrets ([TokenCreatedDialog]) app-wide, so a create that drains
/// while the user is off the Tokens screen still shows its raw secret.
///
/// One listener per app — install once at the top of the authenticated
/// shell. Multiple instances would race to show duplicate dialogs.
class SyncEventListener extends StatefulWidget {
  const SyncEventListener({required this.child, super.key});

  final Widget child;

  @override
  State<SyncEventListener> createState() => _SyncEventListenerState();
}

class _SyncEventListenerState extends State<SyncEventListener> {
  StreamSubscription<SyncEvent>? _sub;
  StreamSubscription<FreshTokenSecret>? _secretSub;
  bool _dialogOpen = false;
  bool _secretDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // Subscribe in `didChangeDependencies` so `context.read<Services>()` is
    // available. `initState` runs before the Provider lookup is safe.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = context.read<Services>();
    _sub ??= services.sync.events.listen(_onEvent);
    // Newly-minted API token secrets are shown app-wide (not tied to the
    // Tokens list screen) so they survive an offline create that drains while
    // the user is elsewhere. The broadcast is just a wake signal; the repo's
    // buffer is the source of truth. Drain once on mount to catch any secret
    // emitted before this listener subscribed (cold-start drain).
    if (_secretSub == null) {
      _secretSub = services.tokens.newSecrets.listen(
        (_) => _drainTokenSecrets(),
      );
      unawaited(_drainTokenSecrets());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _secretSub?.cancel();
    super.dispose();
  }

  Future<void> _onEvent(SyncEvent event) async {
    if (!mounted) return;

    // 422 always surfaces as a toast that routes to the edit form ("shown in
    // the form"). Surfaced *before* the `_dialogOpen` guard so an open
    // password/conflict sheet can't silently swallow the rejection.
    if (event is ValidationFailedEvent) {
      _showFailureToast(event);
      return;
    }

    // A dead row whose caller is already surfacing the failure (an open edit
    // form, or a confirm-after-server action) keeps the toast — no duplicate
    // modal. An *unhandled* death is a silent background failure: while the
    // user is online, escalate to a modal so they can't miss it; offline (or
    // when a modal is already up) fall back to the toast so it's never dropped.
    if (event is DeadEvent) {
      if (event.handledByCaller) {
        _showFailureToast(event);
        return;
      }
      final services = context.read<Services>();
      final online = await services.connectivity.isOnline;
      if (!mounted) return;
      if (online && !_dialogOpen) {
        await _showFailureModal(event);
      } else {
        _showFailureToast(event);
      }
      return;
    }

    // Suppress overlapping dialogs — the sync engine will re-emit on the
    // next attempt if the user dismisses without resolving. Without this
    // a flurry of failed rows would stack N dialogs.
    if (_dialogOpen) return;

    switch (event) {
      case PasswordRequiredEvent():
        await _handlePasswordRequired();
      case ConflictEvent():
        await _handleConflict(event);
      case ValidationFailedEvent():
      case DeadEvent():
        break; // handled above
    }
  }

  /// Non-blocking toast for a permanently-rejected (422) or dead outbox
  /// row, with a "View" action. A 422 carrying per-field errors routes to
  /// the entity's edit screen — opening it triggers the scaffold's
  /// dead-row hydration, which replays the errors inline + in the banner.
  /// Anything without per-field detail (network/5xx death) routes to the
  /// Outbox screen, which shows the failure reason.
  void _showFailureToast(SyncEvent event) {
    final services = context.read<Services>();
    final message = switch (event) {
      ValidationFailedEvent(:final message) => message,
      DeadEvent(:final message) => message,
      _ => '',
    };
    final hasFieldErrors =
        event is ValidationFailedEvent && event.fieldErrors.isNotEmpty;
    Notify.error(
      context,
      context.tr('could_not_save'),
      detail: message.isEmpty ? null : message,
      action: NotifyAction(context.tr('view'), () {
        if (!mounted) return;
        // Reuse the proven `_handleConflict` routing pattern verbatim —
        // registry keyed by EntityType, append the id. A 422 with per-field
        // errors goes to the edit screen (the scaffold hydrates them inline);
        // anything else — or an unregistered entity type — falls back to the
        // Outbox screen so "View" is never a dead end.
        final handlers = hasFieldErrors
            ? services.entityRegistry[event.entityType]
            : null;
        if (handlers != null) {
          context.go('${handlers.routePath}/${event.entityId}/edit');
        } else {
          context.go('/sync/outbox');
        }
      }),
    );
  }

  /// Modal escalation for a silent background failure — a dead outbox row the
  /// user isn't otherwise watching (e.g. a reactivate-email that 400'd, or a
  /// save that failed after the form popped on its online-save timeout), while
  /// online. Mirrors [_handlePasswordRequired]'s `showDialog` + `_dialogOpen`
  /// guarding. "View" routes to the Outbox screen (the row, its status, and
  /// retry/discard live there); "Dismiss" closes.
  Future<void> _showFailureModal(DeadEvent event) async {
    _dialogOpen = true;
    try {
      final view = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('could_not_save')),
          content: event.message.isEmpty ? null : Text(event.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('dismiss')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('view'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (view == true) context.go('/sync/outbox');
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _handlePasswordRequired() async {
    _dialogOpen = true;
    try {
      final services = context.read<Services>();
      final ok = await showConfirmPasswordSheet(
        context,
        cache: services.passwordCache,
      );
      if (!ok || !mounted) return;
      // Re-arm the parked password-required rows (the cache is now warm) and
      // kick a drain so they retry immediately instead of waiting out their
      // +1 min park.
      final companyId = services.auth.session.value?.currentCompanyId;
      if (companyId != null) {
        unawaited(services.sync.retryPasswordRows(companyId: companyId));
      }
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _handleConflict(ConflictEvent event) async {
    _dialogOpen = true;
    try {
      final services = context.read<Services>();
      final companyId = services.auth.session.value?.currentCompanyId;
      final choice = await showConflictResolutionSheet(context, event: event);
      if (!mounted) return;
      switch (choice) {
        case ConflictResolution.openEntity:
          // Route to the entity's detail screen. The registry knows the
          // base path; we append the id.
          final handlers = services.entityRegistry[event.entityType];
          if (handlers != null) {
            context.go('${handlers.routePath}/${event.entityId}');
          }
        case ConflictResolution.discardMine:
          if (companyId == null) return;
          // Scoped to the conflicted record: the parked row plus any queued
          // follow-up mutations for the same entity. The user asked to
          // discard *this record's* changes — dropping the company-wide
          // queue here destroyed unrelated offline work (and ghost-deleted
          // unrelated offline creates).
          final handlers = services.entityRegistry[event.entityType];
          if (handlers != null) {
            await services.sync.discardPendingForEntity(
              companyId: companyId,
              // The ROW's wire entity_type, not handlers.wireName — a
              // registry slot can serve several wire names (user rows carry
              // 'user' while the slot's primary wireName is 'user_settings'),
              // and an exact-match on the wrong one silently discarded
              // nothing.
              entityType: event.wireEntityType,
              entityId: event.entityId,
            );
            // 404: the record is gone server-side, so its now-orphaned local
            // row should disappear too — `discardPendingForEntity` only drops
            // the outbox row(s) and clears the dirty flag (right for a 409,
            // where the next pull reconciles), but here there's nothing left
            // on the server to pull, so the stale local copy would linger.
            if (event.isDeletedServerSide) {
              await handlers.dispatcher.deleteLocalRecord(
                companyId: companyId,
                id: event.entityId,
              );
            }
          }
        case ConflictResolution.useMine:
          // Re-enqueue happens implicitly: a subsequent `repo.save(...)`
          // from the detail screen will write a fresh outbox row. We
          // route the user there so they can hit Save.
          final handlers = services.entityRegistry[event.entityType];
          if (handlers != null) {
            context.go('${handlers.routePath}/${event.entityId}/edit');
          }
        case ConflictResolution.none:
          // Dismissed — leave the row parked.
          break;
      }
    } catch (e, st) {
      _log.warning('Conflict resolution failed', e, st);
    } finally {
      _dialogOpen = false;
    }
  }

  /// Show a one-time copy dialog for every freshly-minted token secret the
  /// repo has buffered, in order, re-checking after each (a secret can arrive
  /// while a dialog is open). The `_secretDialogShowing` guard keeps the
  /// broadcast listener and the mount-time drain from overlapping.
  Future<void> _drainTokenSecrets() async {
    if (_secretDialogShowing || !mounted) return;
    _secretDialogShowing = true;
    try {
      final tokens = context.read<Services>().tokens;
      var pending = tokens.takePendingSecrets();
      while (pending.isNotEmpty && mounted) {
        for (final secret in pending) {
          if (!mounted) break;
          await TokenCreatedDialog.show(context, secret.secret);
        }
        pending = mounted ? tokens.takePendingSecrets() : const [];
      }
    } finally {
      _secretDialogShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

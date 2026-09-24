import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/sync/unconfirmed_change_actions.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Top-of-form banner that surfaces when a save was rejected — either by
/// the server (a 422 / dead outbox row) or by client-side [validate]
/// (`vm.localValidationOnly`, no row ever written). Renders nothing when the
/// VM has neither pending field errors nor a submit error. Pair with
/// `EntityEditField` (or any field that reads `vm.fieldErrorFor(apiKey)`)
/// which already surfaces the per-field text. The local-only case shows
/// softer copy and hides the actions (there is no outbox row to act on).
///
/// **It must never be a dead end.** The old version rendered only when
/// `fieldErrors` was non-empty, said "fix the errors below and try again", and
/// offered nothing but "Discard failed save" — so a rejection naming keys this
/// form doesn't render (`invitations.*.client_contact_id`, `location_id`,
/// `tags.*`, `number`), or carrying no field errors at all, left the user with
/// no stated reason, nothing to fix, and discard as the only exit. That is the
/// symptom behind invoiceninja/flutter#36. Three things prevent it now:
///
///   * the reason is always shown (`vm.submitError`, plus every field-error
///     message, whether or not a field claimed it);
///   * **Retry** re-submits, for the many rejections that are transient or that
///     the user has since fixed elsewhere;
///   * except on a record-deleted rejection, where a retry would fail forever
///     — there the reason is the server's own instruction ("Restore the record
///     to enable editing"), so offering Retry would just be a lie.
///
/// The actions call back out so the screen layer (where the DAO and the save
/// path are in scope) can delete the dead outbox row + [
/// GenericEditViewModel.clearFailedSync] or re-run the save.
///
/// A save held on an `unconfirmed` row ([GenericEditViewModel.
/// unconfirmedRowId] — a change that may already have reached the server)
/// renders a second variant: no Retry, since a re-save is exactly what could
/// do it twice. For the record's own create / update it offers Check, Resend
/// and Discard (`unconfirmed_change_actions.dart`); for another change the
/// save would queue behind, View opens the Outbox where that row lives.
class SaveFailedBanner extends StatelessWidget {
  const SaveFailedBanner({
    required this.vm,
    required this.onDiscard,
    this.onRetry,
    super.key,
  });

  final GenericEditViewModel<dynamic> vm;

  /// Invoked when the user taps "Discard failed save". Should delete the
  /// dead outbox row (`vm.deadOutboxRowId`) and call [vm.clearFailedSync].
  final Future<void> Function() onDiscard;

  /// Re-run the same save. Omit to hide the action (e.g. a host with no save
  /// path of its own). Suppressed for a record-deleted rejection regardless.
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.unconfirmedRowId != null) return _unconfirmed(context);
        final detail = _detail(context);
        if (detail == null) return const SizedBox.shrink();
        final tokens = context.inTheme;
        // A client-side validation block never wrote a local row or an
        // outbox mutation, so the server-rejection framing + the actions
        // (which act on a dead outbox row) make no sense. Use softer copy
        // and drop them. A real server rejection — including a fresh
        // in-session one with no dead-row id yet — keeps both; the screen's
        // discard handler does the fallback dao lookup.
        final localOnly = vm.localValidationOnly;
        final recordDeleted = vm.failedSaveIsRecordDeleted;
        return Material(
          color: tokens.overdueSoft,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: InSpacing.lg(context),
              vertical: InSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Keep the icon aligned to the first line now that the text
                  // can wrap to several.
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 18,
                    color: tokens.overdue,
                  ),
                ),
                const SizedBox(width: InSpacing.sm),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr(
                            localOnly
                                ? 'please_fix_highlighted_fields'
                                : 'save_rejected_banner',
                          ),
                          style: TextStyle(color: tokens.ink2, fontSize: 13),
                        ),
                        if (!localOnly && detail.isNotEmpty)
                          Text(
                            detail,
                            style: TextStyle(color: tokens.ink3, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!localOnly) ...[
                  const SizedBox(width: InSpacing.sm),
                  if (onRetry != null && !recordDeleted)
                    _action(context, tokens, 'retry', onRetry!),
                  _action(context, tokens, 'discard_failed_save', onDiscard),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _action(
    BuildContext context,
    InTheme tokens,
    String labelKey,
    Future<void> Function() onPressed, {
    Color? color,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 36),
        foregroundColor: color ?? tokens.overdue,
      ),
      child: Text(context.tr(labelKey)),
    );
  }

  /// The variant for a save held on an `unconfirmed` row. Actions sit on
  /// their own wrapping line — three of them beside the text would crowd a
  /// phone.
  Widget _unconfirmed(BuildContext context) {
    final tokens = context.inTheme;
    final isSave = vm.unconfirmedIsSave;
    return Material(
      color: tokens.warningSoft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.sync_problem_outlined,
                    size: 18,
                    color: tokens.warning,
                  ),
                ),
                const SizedBox(width: InSpacing.sm),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr(
                            isSave
                                ? 'may_have_been_sent_title'
                                : 'waiting_on_unconfirmed_change',
                          ),
                          style: TextStyle(color: tokens.ink2, fontSize: 13),
                        ),
                        Text(
                          context.tr('may_have_been_sent_help'),
                          style: TextStyle(color: tokens.ink3, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (isSave) ...[
                  _action(
                    context,
                    tokens,
                    'check',
                    () => _withRow(
                      context,
                      (row) => checkUnconfirmedRow(context, row),
                    ),
                    color: tokens.warning,
                  ),
                  _action(
                    context,
                    tokens,
                    'resend',
                    () => _withRow(context, (row) => _resend(context, row)),
                    color: tokens.warning,
                  ),
                  _action(
                    context,
                    tokens,
                    'discard',
                    onDiscard,
                    color: tokens.warning,
                  ),
                ] else
                  _action(
                    context,
                    tokens,
                    'view',
                    () async => context.go('/sync/outbox'),
                    color: tokens.warning,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Run [action] on the row the banner names — or, when it has been dealt
  /// with elsewhere meanwhile (the Outbox screen, a drain), just drop the
  /// banner.
  Future<void> _withRow(
    BuildContext context,
    Future<void> Function(OutboxRow row) action,
  ) async {
    final id = vm.unconfirmedRowId;
    if (id == null) return;
    final row = await context.read<Services>().db.outboxDao.byId(id);
    if (!context.mounted) return;
    if (row == null || row.state != 'unconfirmed') {
      vm.clearUnconfirmed();
      return;
    }
    await action(row);
  }

  /// A resent **create** leaves its form, for where Check would have gone.
  /// Left open, the form invites another Save — which queues a second
  /// create while this one is in flight, or after it has landed under an id
  /// the form never learns: two records on the server. An update resent is
  /// the same record either way, so its form stays.
  Future<void> _resend(BuildContext context, OutboxRow row) async {
    if (!await resendUnconfirmedRow(context, row) || !context.mounted) return;
    vm.clearUnconfirmed();
    Notify.success(context, context.tr('sync_started'));
    if (row.mutationKind == MutationKind.create.wireName) {
      // What the form held is what was just sent: leaving must not ask to
      // discard it — nor offer "Keep editing" back into the form.
      vm.markSaved();
      context.go(unconfirmedRowDestination(context.read<Services>(), row));
    }
  }

  /// The rejection's reason, or null when there's nothing to show at all.
  /// Returns an empty string when there IS a rejection but no readable
  /// message — the headline still renders, just without a detail line.
  ///
  /// Every field-error message is included, not only the ones a field claimed:
  /// a key with no matching widget is exactly the case that used to render as
  /// silence.
  String? _detail(BuildContext context) {
    final hasErrors = vm.fieldErrors.isNotEmpty;
    final message = vm.submitError;
    if (!hasErrors && (message == null || message.isEmpty)) return null;
    if (vm.localValidationOnly) return '';
    // With field errors present the top-level message is Laravel's generic
    // "The given data was invalid." — the per-field strings are the specifics,
    // so they win. Without them the message is all there is.
    final parts = hasErrors
        ? [for (final entry in vm.fieldErrors.entries) ...entry.value]
        : <String>[message!];
    // ' · ' rather than newlines: the same single-line-joining convention the
    // toast host enforces, and it keeps the banner from growing unbounded.
    return parts.where((p) => p.trim().isNotEmpty).join(' · ');
  }
}

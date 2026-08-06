import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

/// Lists every outbox row for the current company so the user can inspect
/// queued mutations, retry dead ones, or discard them.
///
/// Driven by [OutboxDao.watchAll]. Rows render the entity icon (from
/// [EntityRegistry]), a state pill, the mutation kind, retry count, the
/// last server error, and — for 422s — the per-field validation messages
/// the dead row carries in `field_errors_json`.
class OutboxScreen extends StatelessWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: services.auth.session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        final companyId = session.currentCompanyId;
        final globalNav = Breakpoints.isGlobalNavVisible(context);
        return Scaffold(
          backgroundColor: context.inTheme.bg,
          drawer: globalNav ? null : const AppDrawer(),
          appBar: AppBar(
            leading: globalNav ? null : const DrawerHamburger(),
            title: Text(context.tr('outbox')),
          ),
          body: StreamBuilder<List<OutboxRow>>(
            stream: services.db.outboxDao.watchAll(companyId),
            builder: (context, snap) {
              final rows = snap.data ?? const <OutboxRow>[];
              if (rows.isEmpty) {
                return EmptyState(
                  icon: Icons.outbox_outlined,
                  title: context.tr('sync_queue_empty'),
                  subtitle: context.tr('sync_queue_empty_subtitle'),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: InSpacing.lg(context),
                  vertical: InSpacing.md(context),
                ),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: InSpacing.sm),
                itemBuilder: (context, i) => _OutboxTile(row: rows[i]),
              );
            },
          ),
        );
      },
    );
  }
}

class _OutboxTile extends StatelessWidget {
  const _OutboxTile({required this.row});

  final OutboxRow row;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final handlers = services.entityRegistry.byWireName(row.entityType);
    final icon = handlers?.icon ?? Icons.help_outline;
    final fieldErrors = _decodeFieldErrors(row.fieldErrorsJson);

    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: InkWell(
        borderRadius: BorderRadius.circular(InRadii.r2),
        // Tap opens the inspector sheet — the full row state (payload,
        // last_error, idempotency key, …) is what's actionable for a stuck
        // row. "Open entity" stays available in the row menu for entities
        // where their detail/edit route is registered.
        onTap: () => _openInspector(context, row),
        child: Padding(
          padding: EdgeInsets.all(InSpacing.md(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: tokens.ink2),
                  SizedBox(width: InSpacing.md(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rowTitle(context, row),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: tokens.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!_isReorderRow(row)) ...[
                          const SizedBox(height: 2),
                          Text(
                            row.entityId,
                            style: TextStyle(color: tokens.ink3, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatePill(state: row.state),
                ],
              ),
              const SizedBox(height: InSpacing.sm),
              Row(
                children: [
                  Text(
                    _humanizeKind(context, row.mutationKind),
                    style: TextStyle(
                      color: tokens.ink2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (row.attempts > 0) ...[
                    const SizedBox(width: InSpacing.sm),
                    Text(
                      _attemptsLabel(context, row.attempts),
                      style: TextStyle(color: tokens.ink3, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  _RowMenu(row: row, handlers: handlers),
                ],
              ),
              if (row.lastError != null && row.lastError!.isNotEmpty) ...[
                const SizedBox(height: InSpacing.sm),
                Text(
                  row.lastError!,
                  style: TextStyle(color: tokens.overdue, fontSize: 12),
                ),
              ],
              if (fieldErrors.isNotEmpty) ...[
                const SizedBox(height: InSpacing.sm),
                _FieldErrors(errors: fieldErrors),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Map<String, List<String>> _decodeFieldErrors(String? json) {
    if (json == null || json.isEmpty) return const {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(
          k,
          (v as List).map((e) => e.toString()).toList(growable: false),
        ),
      );
    } catch (_) {
      return const {};
    }
  }

  static String _humanizeEntity(String wireName) => _titleCaseSnake(wireName);

  static String _humanizeKind(BuildContext context, String kind) {
    // Known kinds reuse localized labels; future `action:*` values pass
    // through as-is so we never block sync on a missing translation.
    const known = {
      'create',
      'update',
      'delete',
      'archive',
      'restore',
      'purge',
      'add_comment',
      'document_upload',
      'document_delete',
      'document_visibility',
      'reorder',
      'start',
      'stop',
      'mark_sent',
      'mark_paid',
      'email_entity',
      'schedule_email',
      'clone_to_invoice',
      'clone_to_quote',
      'clone_to_credit',
      'clone_to_recurring',
      'clone_to_purchase_order',
      'auto_bill',
      'cancel_entity',
      'run_template',
      'approve',
      'convert_to_invoice',
      'convert_to_project',
      'accept_order',
      'convert_to_expense',
      'send_now',
      'refresh_accounts',
      'match_to_payment',
      'link_to_payment',
      'match_to_expense',
      'link_to_expense',
      'convert_matched',
      'unlink_transaction',
    };
    if (known.contains(kind)) return context.tr(kind);
    return kind;
  }

  /// Bulk reorder rows aren't keyed to a single entity — they carry the
  /// synthetic `kReorderEntityId` (`_sort`). Surface them as
  /// `Reorder &lt;entity&gt;s` with no `#&lt;id&gt;` suffix; everything else
  /// uses the entity label.
  static bool _isReorderRow(OutboxRow row) => row.mutationKind == 'reorder';

  static String _rowTitle(BuildContext context, OutboxRow row) {
    if (_isReorderRow(row)) {
      // `clients`, `tasks`, etc. — pluralized label for the entity type.
      // `context.tr` returns the raw key when no translation exists, which
      // is already readable ("tasks" → "tasks") so the missing-key fallback
      // is harmless.
      final plural = '${row.entityType}s';
      return context.tr('reorder_entities', {'entities': context.tr(plural)});
    }
    return _humanizeEntity(row.entityType);
  }

  static String _attemptsLabel(BuildContext context, int attempts) {
    final key = attempts == 1
        ? 'attempts_count_singular'
        : 'attempts_count_plural';
    return context.tr(key, {'count': attempts.toString()});
  }

  static void _openInspector(BuildContext context, OutboxRow row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OutboxRowInspectorSheet(row: row),
    );
  }
}

/// Route to navigate to when the user "Open"s an outbox row. Dead rows
/// land on the edit form so the user can fix the rejected fields directly;
/// pending / in-flight rows land on the detail screen since the local
/// state already reflects the in-progress mutation.
String _destinationFor(EntityHandlers handlers, OutboxRow row) {
  // Some entities aren't an addressable record at all — point those rows at
  // the screen the change actually belongs to:
  //   * `user_settings` / `user` — the user handler's routePath
  //     (`/settings/account`) has no route.
  //   * `design` — custom designs are created / edited in a modal
  //     (`showDesignEditScreen`), so `custom_designs` exists only as an
  //     Invoice Design tab slug; there is no `<root>/<id>` route.
  if (handlers.type == EntityType.user) return '/settings/user_details';
  if (handlers.type == EntityType.design) {
    return '/settings/invoice_design/custom_designs';
  }
  final isDead = row.state == 'dead';
  final suffix = isDead ? '/edit' : '';
  return '${handlers.routePath}/${row.entityId}$suffix';
}

/// Split a `snake_case` key into title-cased words. Used for both entity
/// wire names (`user_settings` → `User Settings`) and API field keys
/// (`vat_number` → `Vat Number`). Server keys are stable English, so no
/// localization is required.
String _titleCaseSnake(String key) {
  if (key.isEmpty) return key;
  return key
      .split('_')
      .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
      .join(' ');
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.state});
  final String state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (label, fg, bg) = switch (state) {
      'pending' => (
        context.tr('pending_sync'),
        tokens.partial,
        tokens.partialSoft,
      ),
      'in_flight' => (context.tr('in_flight'), tokens.sent, tokens.sentSoft),
      'dead' => (context.tr('sync_failed'), tokens.overdue, tokens.overdueSoft),
      _ => (state, tokens.draft, tokens.draftSoft),
    };
    return StatusPill(label: label, fgColor: fg, bgColor: bg);
  }
}

class _FieldErrors extends StatelessWidget {
  const _FieldErrors({required this.errors});
  final Map<String, List<String>> errors;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final flat = <(String, String)>[];
    for (final entry in errors.entries) {
      for (final msg in entry.value) {
        flat.add((entry.key, msg));
      }
    }
    final visible = flat.take(3).toList();
    final overflow = flat.length - visible.length;
    return Container(
      padding: const EdgeInsets.all(InSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.overdueSoft,
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (field, message) in visible)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.ink2,
                  ),
                  children: [
                    TextSpan(
                      text: '${_humanizeFieldKey(field)}: ',
                      style: TextStyle(
                        color: tokens.overdue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: message),
                  ],
                ),
              ),
            ),
          if (overflow > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                context.tr('plus_n_more', {'count': overflow.toString()}),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ),
        ],
      ),
    );
  }

  static String _humanizeFieldKey(String key) => _titleCaseSnake(key);
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.row, required this.handlers});
  final OutboxRow row;
  final EntityHandlers? handlers;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return PopupMenuButton<String>(
      tooltip: '',
      iconSize: 18,
      onSelected: (action) async {
        switch (action) {
          case 'retry':
            await services.db.outboxDao.retryDead(
              id: row.id,
              now: DateTime.now().millisecondsSinceEpoch,
            );
            unawaited(services.sync.drainOnce(companyId: row.companyId));
          case 'discard':
            await services.sync.discardOutboxRow(row.id);
          case 'open':
            if (handlers != null && context.mounted) {
              context.go(_destinationFor(handlers!, row));
            }
          case 'copy':
            await _OutboxRowInspectorSheet._copy(
              context,
              _OutboxRowInspectorSheet._flatDump(
                row,
                _OutboxRowInspectorSheet._prettyJson(row.payload),
              ),
            );
        }
      },
      itemBuilder: (context) => [
        // Retry on anything that isn't actively in-flight: `dead` rows
        // (the normal case) and `pending` rows that are sitting on a
        // backoff timer (or that, in a bygone-bug scenario, never had
        // their drain kicked). `retryDead` resets attempts/nextAttemptAt
        // for both — followed by an explicit drainOnce kick.
        if (row.state != 'in_flight')
          PopupMenuItem<String>(
            value: 'retry',
            child: Row(
              children: [
                const Icon(Icons.refresh, size: 16),
                const SizedBox(width: InSpacing.sm),
                Text(context.tr('retry')),
              ],
            ),
          ),
        if (handlers != null)
          PopupMenuItem<String>(
            value: 'open',
            child: Row(
              children: [
                const Icon(Icons.open_in_new, size: 16),
                const SizedBox(width: InSpacing.sm),
                Text(context.tr('open_entity')),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy_all, size: 16),
              const SizedBox(width: InSpacing.sm),
              Text(context.tr('copy')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'discard',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 16),
              const SizedBox(width: InSpacing.sm),
              Text(context.tr('discard')),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet showing every column on an outbox row in human-readable form.
/// Opened from the row's tap action — the place to debug a stuck mutation:
/// you can see the exact payload that was POST/PUT'd, the server's last
/// error message + status code, and the idempotency key for log-side
/// correlation. Copy-to-clipboard for the payload alone and for a flat
/// diagnostic dump.
class _OutboxRowInspectorSheet extends StatelessWidget {
  const _OutboxRowInspectorSheet({required this.row});

  final OutboxRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final payloadPretty = _prettyJson(row.payload);
    final fieldErrors = _OutboxTile._decodeFieldErrors(row.fieldErrorsJson);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(InRadii.r3),
          ),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            InSpacing.lg(context),
            InSpacing.md(context),
            InSpacing.lg(context),
            InSpacing.lg(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: InSpacing.md(context)),
                  decoration: BoxDecoration(
                    color: tokens.ink4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      context.tr('outbox_row_details'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _StatePill(state: row.state),
                ],
              ),
              SizedBox(height: InSpacing.md(context)),
              _InspectorRow(
                label: context.tr('entity_type_label'),
                value: row.entityType,
              ),
              _InspectorRow(
                label: context.tr('entity_id_label'),
                value: row.entityId,
              ),
              _InspectorRow(
                label: context.tr('mutation_kind_label'),
                value: row.mutationKind,
              ),
              _InspectorRow(
                label: context.tr('attempts_label'),
                value: '${row.attempts}',
              ),
              _InspectorRow(
                label: context.tr('idempotency_key_label'),
                value: row.idempotencyKey,
              ),
              if (row.lastStatusCode != null)
                _InspectorRow(
                  label: context.tr('status_code_label'),
                  value: '${row.lastStatusCode}',
                ),
              _InspectorRow(
                label: context.tr('requires_password_label'),
                value: row.requiresPassword ? '✓' : '—',
              ),
              if (row.lastError != null && row.lastError!.isNotEmpty) ...[
                SizedBox(height: InSpacing.md(context)),
                _SectionLabel(label: context.tr('last_error_label')),
                const SizedBox(height: InSpacing.xs),
                _CodeBlock(text: row.lastError!, isError: true),
              ],
              if (fieldErrors.isNotEmpty) ...[
                SizedBox(height: InSpacing.md(context)),
                _SectionLabel(label: context.tr('field_errors_label')),
                const SizedBox(height: InSpacing.xs),
                _FieldErrors(errors: fieldErrors),
              ],
              SizedBox(height: InSpacing.md(context)),
              _SectionLabel(label: context.tr('payload')),
              const SizedBox(height: InSpacing.xs),
              _CodeBlock(text: payloadPretty),
              SizedBox(height: InSpacing.lg(context)),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(context.tr('copy_payload')),
                    onPressed: () => _copy(context, payloadPretty),
                  ),
                  SizedBox(width: InSpacing.md(context)),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    icon: const Icon(Icons.copy_all, size: 16),
                    label: Text(context.tr('copy_diagnostics')),
                    onPressed: () =>
                        _copy(context, _flatDump(row, payloadPretty)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _prettyJson(String raw) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  static String _flatDump(OutboxRow row, String payloadPretty) {
    final lines = <String>[
      'entity_type: ${row.entityType}',
      'entity_id: ${row.entityId}',
      'mutation_kind: ${row.mutationKind}',
      'state: ${row.state}',
      'attempts: ${row.attempts}',
      'idempotency_key: ${row.idempotencyKey}',
      'requires_password: ${row.requiresPassword}',
      if (row.lastStatusCode != null) 'status_code: ${row.lastStatusCode}',
      if (row.lastError != null) 'last_error: ${row.lastError}',
      'payload:',
      payloadPretty,
    ];
    return lines.join('\n');
  }

  static Future<void> _copy(BuildContext context, String text) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    Notify.success(
      context,
      context.tr('copied_to_clipboard', {'value': ''}),
      messenger: messenger,
    );
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: tokens.ink3,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: tokens.ink,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Text(
      label,
      style: TextStyle(
        color: tokens.ink3,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: isError ? tokens.overdueSoft : tokens.bg,
        borderRadius: BorderRadius.circular(InRadii.r1),
        border: Border.all(color: tokens.border, width: 1),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          color: isError ? tokens.overdue : tokens.ink,
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}

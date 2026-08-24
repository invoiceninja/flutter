import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/diagnostics_log.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/system_log_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/system_log_row.dart';
import 'package:admin/utils/formatting.dart';

/// Settings → System Logs. Admin/owner only (matches React's `Guard` on
/// `/settings/system_logs`) — non-admins get a restricted state and the
/// sidebar entry + search hit are hidden. Hosts two distinct things:
/// 1. The server-side System Logs feed (`/api/v1/system_logs`) — surfaces
///    gateway / email / webhook / PDF / security events with collapsible
///    JSON payloads.
/// 2. Local diagnostics — app version, server URL, outbox state, and the
///    `claude-diagnostics.log` file path — handy for support reports.
class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  late final Services _services;
  PackageInfo? _packageInfo;
  SystemLogRefreshResult? _lastRefresh;
  bool _refreshing = false;
  DateTime? _lastFetchedAt;
  // Tracks whether _maybeAutoRefresh has run yet. Without this we'd flash
  // the `no_system_logs` empty state for one frame before the postFrame
  // callback flips `_refreshing`.
  bool _initialFetchAttempted = false;
  // The company this screen's local refresh-state belongs to. The settings
  // route is NOT remounted on a plain company switch (its KeyedSubtree key is
  // `level:targetId`, unchanged), so we reset that state ourselves when the
  // active company changes — mirroring SettingsCompanyScopedHost.
  String _scopedCompanyId = '';

  /// System Logs filters (invoiceninja/flutter#60). Null = "All". Both are
  /// view-only — the feed is a cached read model, so filtering is a local
  /// `where` over what `watch` already emitted, with no refetch.
  int? _categoryFilter;
  SystemLogTone? _toneFilter;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _scopedCompanyId = _services.auth.session.value?.currentCompanyId ?? '';
    _services.auth.session.addListener(_onSession);
    _loadPackage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoRefresh());
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSession);
    super.dispose();
  }

  // Reset the per-company refresh state and re-run the stale check when the
  // user switches company while this screen stays mounted. The session
  // notifier also fires on unrelated companies-table writes, so guard on the
  // id to make those no-ops.
  void _onSession() {
    if (!mounted) return;
    final id = _services.auth.session.value?.currentCompanyId ?? '';
    if (id == _scopedCompanyId) return;
    _scopedCompanyId = id;
    setState(() {
      _initialFetchAttempted = false;
      _lastRefresh = null;
      _lastFetchedAt = null;
      _refreshing = false;
      // The other company's categories may not exist here; a stale filter
      // would render an empty feed that looks like a load failure.
      _categoryFilter = null;
      _toneFilter = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoRefresh());
  }

  Future<void> _loadPackage() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  /// Fire a refresh on first open OR when the cache is > 1 h old. Matches
  /// React's `staleTime: 3600000` semantics.
  Future<void> _maybeAutoRefresh() async {
    if (!mounted) return;
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId ?? '';
    if (companyId.isEmpty) return;
    if (!_canViewServerLogs(session)) return;
    final last = await services.systemLogs.lastFetchedAt(companyId);
    if (!mounted) return;
    setState(() {
      _lastFetchedAt = last;
      _initialFetchAttempted = true;
    });
    final now = DateTime.now().toUtc();
    final stale =
        last == null || now.difference(last) > const Duration(hours: 1);
    if (stale) {
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) return;
    setState(() {
      _refreshing = true;
      _initialFetchAttempted = true;
    });
    final result = await services.systemLogs.refresh(companyId);
    final last = await services.systemLogs.lastFetchedAt(companyId);
    if (!mounted) return;
    // If the user switched companies mid-await, don't apply this refresh's
    // result to the new company's screen state — bail.
    final currentCompanyId =
        services.auth.session.value?.currentCompanyId ?? '';
    if (currentCompanyId != companyId) {
      setState(() => _refreshing = false);
      return;
    }
    setState(() {
      _refreshing = false;
      _lastRefresh = result;
      _lastFetchedAt = last;
    });
  }

  bool _canViewServerLogs(AuthSession? session) {
    final me = session?.currentCompany;
    if (me == null) return false;
    return me.isAdmin || me.isOwner;
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Admin/owner-only page — matches React's Guard on /settings/system_logs.
    // The session VLB keeps the gate reactive; the restricted branch blocks
    // deep-links and restored routes too, not just the hidden sidebar entry.
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: services.auth.session,
      builder: (context, session, _) {
        if (!_canViewServerLogs(session)) {
          return SettingsScreenScaffold(
            titleKey: 'system_logs',
            body: Center(
              child: EmptyState(
                icon: Icons.lock_outline,
                title: context.tr('restricted'),
                subtitle: context.tr('only_admins_can_access'),
              ),
            ),
          );
        }
        return ValueListenableBuilder<String?>(
          valueListenable: services.serverVersion,
          builder: (context, serverVersion, _) {
            final companyId = session?.currentCompanyId ?? '';
            return StreamBuilder<int>(
              stream: services.db.outboxDao.watchPendingCount(
                companyId: companyId,
              ),
              builder: (context, pendingSnap) {
                return StreamBuilder<int>(
                  stream: services.db.outboxDao.watchDeadCount(
                    companyId: companyId,
                  ),
                  builder: (context, deadSnap) {
                    final pending = pendingSnap.data ?? 0;
                    final dead = deadSnap.data ?? 0;
                    final appRows = <(String, String)>[
                      (
                        context.tr('app_version'),
                        '${_packageInfo?.version ?? '?'} (${_packageInfo?.buildNumber ?? '?'})',
                      ),
                      (
                        context.tr('client_version_constant'),
                        AppVersion.kClientVersion,
                      ),
                      (
                        context.tr('min_server_version'),
                        AppVersion.kMinServerVersion,
                      ),
                    ];
                    final serverRows = <(String, String)>[
                      (context.tr('server_url'), session?.baseUrl ?? '—'),
                      (
                        context.tr('server_version_label'),
                        serverVersion ?? context.tr('not_yet_seen'),
                      ),
                      (
                        context.tr('hosted'),
                        (session?.isHosted ?? false)
                            ? context.tr('yes')
                            : context.tr('no'),
                      ),
                      (context.tr('account_id'), session?.accountId ?? '—'),
                      (
                        context.tr('company'),
                        session?.currentCompany?.displayName ?? '—',
                      ),
                      (
                        context.tr('company_id_label'),
                        session?.currentCompanyId ?? '—',
                      ),
                    ];
                    final outboxRows = <(String, String)>[
                      (context.tr('pending_outbox_rows'), '$pending'),
                      (context.tr('dead_outbox_rows'), '$dead'),
                    ];
                    final allRows = [...appRows, ...serverRows, ...outboxRows];
                    final diag = services.diagnosticsLog;

                    return SettingsScreenScaffold(
                      titleKey: 'system_logs',
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: context.tr('copy_diagnostics'),
                          onPressed: () => _copy(
                            rows: allRows,
                            services: services,
                            companyId: companyId,
                            diag: diag,
                          ),
                        ),
                      ],
                      body: SettingsFormShell(
                        sections: _buildSections(
                          services: services,
                          companyId: companyId,
                          appRows: appRows,
                          serverRows: serverRows,
                          outboxRows: outboxRows,
                          diag: diag,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Builds the list of FormSection cards rendered in the top-of-screen
  /// scroll area. Pulled out of [build] so the body Column can split into a
  /// top scroll region + a pinned bottom band cleanly.
  List<Widget> _buildSections({
    required Services services,
    required String companyId,
    required List<(String, String)> appRows,
    required List<(String, String)> serverRows,
    required List<(String, String)> outboxRows,
    required DiagnosticsLog? diag,
  }) {
    return [
      if (companyId.isNotEmpty)
        _buildSystemLogsSection(services: services, companyId: companyId),
      FormSection(
        title: context.tr('application'),
        children: [
          for (final row in appRows)
            _DiagnosticRow(label: row.$1, value: row.$2),
        ],
      ),
      FormSection(
        title: context.tr('server'),
        children: [
          for (final row in serverRows)
            _DiagnosticRow(label: row.$1, value: row.$2),
        ],
      ),
      FormSection(
        title: context.tr('outbox'),
        children: [
          for (final row in outboxRows)
            _DiagnosticRow(label: row.$1, value: row.$2),
        ],
      ),
      if (diag != null)
        FormSection(
          title: context.tr('diagnostics_log'),
          children: [
            _DiagnosticRow(
              label: context.tr('diagnostics_log_path'),
              value: diag.path,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.note_add_outlined),
                label: Text(context.tr('append_outbox_snapshot')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: companyId.isEmpty
                    ? null
                    : () => _appendSnapshot(
                        services: services,
                        diag: diag,
                        companyId: companyId,
                      ),
              ),
            ),
          ],
        ),
    ];
  }

  Widget _buildSystemLogsSection({
    required Services services,
    required String companyId,
  }) {
    final tokens = context.inTheme;
    return FormSection(
      title: context.tr('system_logs'),
      // Trailing stays icon-only so the header can't overflow on a narrow
      // viewport; the "last refreshed" caption lives in the body above the
      // rows (see _buildSectionBody).
      trailing: IconButton(
        icon: _refreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        tooltip: context.tr('refresh'),
        onPressed: _refreshing ? null : _refresh,
      ),
      children: [
        StreamBuilder<List<SystemLog>>(
          stream: services.systemLogs.watch(companyId),
          builder: (context, snap) {
            final rows = snap.data ?? const <SystemLog>[];
            return _buildSectionBody(rows: rows, tokens: tokens);
          },
        ),
      ],
    );
  }

  void _clearFilters() => setState(() {
    _categoryFilter = null;
    _toneFilter = null;
  });

  List<SystemLog> _applyFilters(List<SystemLog> rows) => rows
      .where(
        (l) =>
            (_categoryFilter == null || l.categoryId == _categoryFilter) &&
            (_toneFilter == null || l.tone == _toneFilter),
      )
      .toList(growable: false);

  Widget _buildSectionBody({
    required List<SystemLog> rows,
    required InTheme tokens,
  }) {
    if (rows.isEmpty) {
      if (_lastRefresh == SystemLogRefreshResult.forbidden ||
          _lastRefresh == SystemLogRefreshResult.notFound) {
        return EmptyState(
          icon: Icons.lock_outline,
          title: context.tr('system_logs_unavailable'),
          subtitle: context.tr('system_logs_unavailable_help'),
        );
      }
      if (_lastRefresh == SystemLogRefreshResult.networkError) {
        return ErrorView(
          message: context.tr('system_logs_load_failed'),
          onRetry: _refresh,
        );
      }
      if (_refreshing || !_initialFetchAttempted) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return EmptyState(
        icon: Icons.terminal_outlined,
        title: context.tr('no_system_logs'),
      );
    }
    final visible = _applyFilters(rows);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = Breakpoints.isWide(constraints);
        final lastFetchedLabel = _lastFetchedAt == null
            ? null
            : formatRelativeTime(
                context,
                DateTime.now().toUtc().difference(_lastFetchedAt!.toUtc()),
              );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lastFetchedLabel != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${context.tr('last_refreshed')}: $lastFetchedLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.ink3),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _SystemLogFilterBar(
              rows: rows,
              category: _categoryFilter,
              tone: _toneFilter,
              onCategory: (v) => setState(() => _categoryFilter = v),
              onTone: (v) => setState(() => _toneFilter = v),
            ),
            if (visible.isEmpty)
              EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: context.tr('no_records_found'),
                action: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.close),
                  label: Text(context.tr('clear_filters')),
                ),
              ),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: tokens.border),
              SystemLogRow(log: visible[i], isWide: isWide),
            ],
          ],
        );
      },
    );
  }

  /// Assembles a support bundle: the metadata rows, a compact server-log
  /// summary (no JSON payloads — they can carry unredacted PII / payment
  /// data), and the recent local diagnostics tail (already redacted at
  /// capture time). Translation goes through a captured [Localization] so we
  /// don't touch `context` across the `await`.
  Future<void> _copy({
    required List<(String, String)> rows,
    required Services services,
    required String companyId,
    required DiagnosticsLog? diag,
  }) async {
    final l10n = Localization.of(context);
    String tr(String key) => l10n?.lookup(key) ?? key;

    final buffer = StringBuffer(rows.map((r) => '${r.$1}: ${r.$2}').join('\n'));

    if (companyId.isNotEmpty) {
      try {
        final logs = await services.systemLogs.watch(companyId).first;
        if (logs.isNotEmpty) {
          buffer
            ..writeln()
            ..writeln()
            ..writeln('--- ${tr('system_logs')} ---');
          for (final l in logs) {
            final type = l.typeDisplay();
            final typeText = type.isKey ? tr(type.value) : type.value;
            buffer.writeln(
              '${tr(l.categoryKey)} · ${tr(l.eventKey)} · $typeText · '
              '${l.createdAt.toUtc().toIso8601String()}',
            );
          }
        }
      } catch (_) {
        // Best-effort — omit the server-log section if the cache read fails.
      }
    }

    final recent = diag?.recent() ?? const <String>[];
    if (recent.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln()
        ..writeln('--- ${tr('diagnostics_log')} ---')
        ..writeln(recent.join('\n'));
    }

    if (!mounted) return;
    try {
      // Label rather than payload: the buffer is the whole diagnostics log.
      await copyToClipboard(
        context,
        buffer.toString(),
        label: context.tr('system_logs'),
      );
    } catch (_) {
      if (!mounted) return;
      Notify.error(context, context.tr('error'));
    }
  }

  Future<void> _appendSnapshot({
    required Services services,
    required DiagnosticsLog diag,
    required String companyId,
  }) async {
    final int count;
    try {
      count = await diag.appendOutboxSnapshot(
        db: services.db,
        companyId: companyId,
      );
    } catch (_) {
      if (!mounted) return;
      Notify.error(context, context.tr('error'));
      return;
    }
    if (!mounted) return;
    Notify.success(
      context,
      context.tr('wrote_stale_rows', {'count': '$count'}),
    );
  }
}

/// Category + outcome filters for the System Logs feed
/// (invoiceninja/flutter#60).
///
/// Both dropdowns are built from the rows actually loaded, so the account
/// never gets to pick a filter that can only return nothing — and the bar
/// hides itself entirely when neither axis has more than one value, which is
/// the common case on a quiet account.
class _SystemLogFilterBar extends StatelessWidget {
  const _SystemLogFilterBar({
    required this.rows,
    required this.category,
    required this.tone,
    required this.onCategory,
    required this.onTone,
  });

  final List<SystemLog> rows;
  final int? category;
  final SystemLogTone? tone;
  final ValueChanged<int?> onCategory;
  final ValueChanged<SystemLogTone?> onTone;

  @override
  Widget build(BuildContext context) {
    // Sorted so the order can't shuffle between refreshes.
    final categories = rows.map((l) => l.categoryId).toSet().toList()..sort();
    final tones = SystemLogTone.values
        .where((t) => rows.any((l) => l.tone == t))
        .toList();

    final showCategory = categories.length > 1;
    // `neutral` is not a user-facing outcome, so a feed that is only
    // success + neutral has just one thing worth filtering on.
    final toneOptions = tones.where((t) => t != SystemLogTone.neutral).toList();
    final showTone = toneOptions.length > 1;
    if (!showCategory && !showTone) return const SizedBox.shrink();

    final all = context.tr('all');
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.md(context)),
      child: Wrap(
        spacing: InSpacing.md(context),
        runSpacing: InSpacing.sm,
        children: [
          if (showCategory)
            _FilterDropdown<int?>(
              labelKey: 'category',
              value: category,
              onChanged: onCategory,
              items: [
                DropdownMenuItem<int?>(child: Text(all)),
                for (final id in categories)
                  DropdownMenuItem<int?>(
                    value: id,
                    child: Text(
                      context.tr(_categoryKeyFor(rows, id)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          if (showTone)
            _FilterDropdown<SystemLogTone?>(
              labelKey: 'status',
              value: tone,
              onChanged: onTone,
              items: [
                DropdownMenuItem<SystemLogTone?>(child: Text(all)),
                for (final t in toneOptions)
                  DropdownMenuItem<SystemLogTone?>(
                    value: t,
                    child: Text(context.tr(_toneKey(t))),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// The category label comes off a row rather than a second copy of the
  /// id → key table, so `SystemLog.categoryKey` stays the single source.
  static String _categoryKeyFor(List<SystemLog> rows, int id) =>
      rows.firstWhere((l) => l.categoryId == id).categoryKey;

  static String _toneKey(SystemLogTone tone) => switch (tone) {
    SystemLogTone.success => 'success',
    SystemLogTone.failure => 'failure',
    SystemLogTone.warning => 'warning',
    SystemLogTone.neutral => 'other',
  };
}

/// Compact bordered dropdown sized to its content — a plain
/// `DropdownButtonFormField` would stretch to the section width and stack the
/// two filters into a full-width column. Short fixed enums, so a searchable
/// picker would be overkill (CLAUDE.md § Searchable pickers).
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.labelKey,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String labelKey;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: IntrinsicWidth(
        child: DropdownButtonFormField<T>(
          // `FormField` seeds its state from `initialValue` once and never
          // re-reads it (`didUpdateWidget` only tracks `forceErrorText`), so
          // without a value-derived key the Clear Filters button would empty
          // the feed's filter while both dropdowns still displayed the old
          // selection.
          key: ValueKey<T>(value),
          initialValue: value,
          isDense: true,
          decoration: InputDecoration(
            labelText: context.tr(labelKey),
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          items: items,
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final labelWidget = Text(
      label,
      style: TextStyle(
        color: tokens.ink3,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
    final valueWidget = SelectableText(
      value,
      style: TextStyle(color: tokens.ink, fontSize: 13),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Side-by-side on wide; stacked label-over-value on narrow so long
        // values (server URL, account id, diagnostics path) aren't squeezed
        // into a sliver on mobile.
        if (Breakpoints.isWide(constraints)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 180, child: labelWidget),
              Expanded(child: valueWidget),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelWidget, const SizedBox(height: 2), valueWidget],
        );
      },
    );
  }
}

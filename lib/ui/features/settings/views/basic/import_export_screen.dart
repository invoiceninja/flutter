import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/data/models/domain/import_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/import_api.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Search keys for the settings search catalog. Every entry must be rendered
/// as a `context.tr('<key>')` label somewhere in this screen — enforced by
/// `search_catalog_consistency_test`.
const kImportExportSearchKeys = <String>[
  'import',
  'export',
  'import_type',
  'company_migration',
  'column_mapping',
  'import_settings',
];

enum _Step { pick, map, done }

/// CSV-export entity → the `date_key`s the server accepts for date filtering
/// (empty = no date filter offered). Ported from React `Export.tsx`.
const _kExportDates = <String, List<String>>{
  'clients': ['created_at'],
  'client_contacts': ['created_at'],
  'invoices': ['date', 'due_date', 'partial_due_date'],
  'invoice_items': ['date', 'due_date', 'partial_due_date'],
  'quotes': ['date', 'due_date', 'partial_due_date'],
  'quote_items': ['date', 'due_date', 'partial_due_date'],
  'credits': ['date', 'due_date', 'partial_due_date'],
  'recurring_invoices': ['date', 'due_date', 'partial_due_date'],
  'expenses': ['date', 'payment_date'],
  'payments': ['date'],
  'documents': ['created_at'],
  'products': ['created_at'],
  'tasks': ['created_at'],
  'activities': <String>[],
  'purchase_orders': <String>[],
  'purchase_order_items': <String>[],
  'vendors': <String>[],
};

/// CSV-export types that carry document attachments (old-Flutter
/// `hasDocuments`) — only these expose the "Attach Documents" toggle.
const _kExportHasDocuments = <String>{
  'clients',
  'invoices',
  'invoice_items',
  'quotes',
  'quote_items',
  'credits',
  'expenses',
  'payments',
  'products',
  'tasks',
  'vendors',
  'purchase_orders',
  'purchase_order_items',
};

/// `date_range` identifier → localization key. Ported from React `Export.tsx`.
const _kDateRanges = <(String, String)>[
  ('last7', 'last_7_days'),
  ('last30', 'last_30_days'),
  ('this_month', 'this_month'),
  ('last_month', 'last_month'),
  ('this_quarter', 'this_quarter'),
  ('last_quarter', 'last_quarter'),
  ('this_year', 'this_year'),
  ('last_year', 'last_year'),
  ('custom', 'custom'),
];

/// Third-party importer → required upload groups. Ported from React `Import.tsx`.
const _kThirdPartyImports = <String, List<String>>{
  'freshbooks': ['clients', 'invoices'],
  'invoice2go': ['invoices'],
  'invoicely': ['clients', 'invoices'],
  'waveaccounting': ['clients', 'accounting'],
  'zoho': ['contacts', 'invoices'],
  'quickbooks': ['backup'],
};

/// Upload group → the multipart `files[<key>]` name the server expects.
const _kThirdPartyFileKey = <String, String>{
  'clients': 'client',
  'invoices': 'invoice',
  'accounting': 'invoice',
  'contacts': 'client',
  'backup': 'backup',
};

/// `/settings/import_export` — CSV data import. Three-stage flow mirroring
/// React/admin-portal: pick entity + file → `/api/v1/preimport` → map each
/// CSV column to an entity field → `/api/v1/import`. The server runs the
/// import asynchronously and emails the user on completion.
class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  /// Export report types — mirrors React's `Export.tsx` `ExportType` union
  /// (`POST /api/v1/reports/<type>`). Every entry has a localized label in
  /// `en.json` already.
  static const List<String> _exportTypes = [
    'clients',
    'client_contacts',
    'invoices',
    'invoice_items',
    'quotes',
    'quote_items',
    'credits',
    'recurring_invoices',
    'payments',
    'expenses',
    'products',
    'vendors',
    'purchase_orders',
    'purchase_order_items',
    'tasks',
    'documents',
    'activities',
  ];

  _Step _step = _Step.pick;
  String _entity = kImportableEntities.first;
  String _exportType = 'clients';
  bool _exporting = false;
  String? _fileName;
  Uint8List? _bytes;
  bool _busy = false;
  bool _skipHeader = true;
  // Required only when [_entity] == 'bank_transaction' — the server needs a
  // target bank integration to attach imported transactions to.
  String? _bankIntegrationId;

  ImportPreview? _preview;
  // Column index → selected field path ('' = skip).
  final Map<int, String> _map = {};

  // Company-migration (import_json) state — independent of the CSV flow.
  UploadSource? _migrationSource;
  String? _migrationFileName;
  bool _migrationImportSettings = true;
  bool _migrationBusy = false;

  // CSV-export date filter (mirrors React Export.tsx). Null key = no filter.
  String? _exportDateKey;
  String _exportDateRange = 'last7';
  DateTime? _exportStart;
  DateTime? _exportEnd;
  // CSV-export option toggles (old-Flutter parity). `_exportDocuments` is only
  // offered for document-bearing types (see `_kExportHasDocuments`).
  bool _exportDocuments = false;
  bool _exportIncludeDeleted = false;

  // Third-party importer state (freshbooks / wave / zoho / …). Each required
  // group holds the bytes + display name of one picked file.
  String _thirdPartyType = 'freshbooks';
  final Map<String, ({Uint8List bytes, String name})> _thirdPartyFiles = {};
  bool _thirdPartyBusy = false;

  ImportApi get _api => ImportApi(context.read<Services>().apiClient);

  Future<void> _onCsvFiles(List<UploadSource> sources) async {
    if (sources.isEmpty) return;
    final source = sources.first;
    final bytes = await source.readRange(0, await source.length());
    if (!mounted) return;
    if (bytes.isEmpty) {
      Notify.warning(context, context.tr('dropzone_invalid_file_type'));
      return;
    }
    setState(() {
      _fileName = source.fileName;
      _bytes = bytes;
    });
  }

  Future<void> _runPreImport() async {
    if (_busy) return;
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _busy = true);
    try {
      final preview = await _api.preImport(
        entity: _entity,
        fileName: _fileName ?? 'import.csv',
        bytes: bytes,
      );
      if (!mounted) return;
      _map.clear();
      // Seed from server hints (index into `available`, -1 = no guess).
      for (var i = 0; i < preview.columns.length; i++) {
        final hint = i < preview.hints.length ? preview.hints[i] : -1;
        if (hint >= 0 && hint < preview.available.length) {
          _map[i] = preview.available[hint];
        } else {
          _map[i] = '';
        }
      }
      setState(() {
        _preview = preview;
        _step = _Step.map;
      });
    } on Object catch (e) {
      if (mounted) Notify.error(context, _msg(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport() async {
    if (_busy) return;
    final preview = _preview;
    if (preview == null) return;
    setState(() => _busy = true);
    try {
      await _api.runImport(
        hash: preview.hash,
        entity: _entity,
        skipHeader: _skipHeader,
        columnMap: _map,
        bankIntegrationId: _bankIntegrationId,
      );
      if (!mounted) return;
      setState(() => _step = _Step.done);
    } on Object catch (e) {
      if (mounted) Notify.error(context, _msg(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _step = _Step.pick;
      _fileName = null;
      _bytes = null;
      _preview = null;
      _map.clear();
      _skipHeader = true;
      _bankIntegrationId = null;
    });
  }

  String _msg(BuildContext context, Object e) {
    if (e is ValidationException) {
      // `·`, not `\n`: this is the toast *title*, which the toast controller
      // flattens to a single line — a newline join would run the messages
      // together with no separator. `trim()` because a whitespace-only entry
      // passes `isNotEmpty` and contributes a blank segment.
      final flat = e.fieldErrors.values
          .expand((v) => v)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(' · ');
      if (flat.isNotEmpty) return flat;
    }
    if (e is DemoModeException) return context.tr('not_available');
    // `ApiException.message` is non-nullable but comes straight off the server
    // body, so `{"message":""}` arrives blank.
    if (e is ApiException && e.message.trim().isNotEmpty) return e.message;
    return context.tr('an_error_occurred');
  }

  /// `POST /api/v1/reports/<type>` — queues a CSV export of the selected
  /// entity type and emails the user a download link. Mirrors React's
  /// `Export.tsx` (`send_email: true`, no `report_keys` filter = all rows,
  /// no date filter = all-time). Same email-link contract as Backup.
  Future<void> _runExport() async {
    if (_exporting) return;
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final tr = context.tr;
    setState(() => _exporting = true);
    try {
      // Date filter (mirrors React Export.tsx): omit entirely when no date key
      // is chosen → server defaults to an all-time export.
      final body = <String, dynamic>{
        'send_email': true,
        'report_keys': <String>[],
        if (_exportDateKey != null) ...{
          'date_key': _exportDateKey,
          'date_range': _exportDateRange,
          if (_exportDateRange == 'custom') ...{
            'start_date': _isoOrEmpty(_exportStart),
            'end_date': _isoOrEmpty(_exportEnd),
          },
        },
        if (_exportDocuments && _kExportHasDocuments.contains(_exportType))
          'document_email_attachment': true,
        if (_exportIncludeDeleted) 'include_deleted': true,
      };
      await services.apiClient.postJson(
        '/api/v1/reports/$_exportType',
        body: body,
      );
      if (!mounted) return;
      Notify.success(context, tr('exported_data'), messenger: messenger);
    } on Object catch (e) {
      if (mounted) {
        Notify.error(context, _msg(context, e), messenger: messenger);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _isoOrEmpty(DateTime? d) =>
      d == null ? '' : Date(d.year, d.month, d.day).toIso();

  Future<void> _onMigrationFiles(List<UploadSource> sources) async {
    if (sources.isEmpty) return;
    final source = sources.first;
    final name = source.fileName.toLowerCase();
    if (!name.endsWith('.zip') && !name.endsWith('.json')) {
      if (!mounted) return;
      Notify.warning(context, context.tr('dropzone_invalid_file_type'));
      return;
    }
    int length = 0;
    try {
      length = await source.length();
    } catch (_) {
      length = 0;
    }
    if (!mounted) return;
    if (length <= 0) {
      Notify.warning(context, context.tr('dropzone_invalid_file_type'));
      return;
    }
    setState(() {
      _migrationSource = source;
      _migrationFileName = source.fileName;
    });
  }

  Future<void> _runMigration() async {
    if (_migrationBusy) return;
    final source = _migrationSource;
    if (source == null) return;
    setState(() => _migrationBusy = true);
    try {
      await _api.runMigration(
        source: source,
        importSettings: _migrationImportSettings,
      );
      if (!mounted) return;
      Notify.success(context, context.tr('import_started'));
      setState(() {
        _migrationSource = null;
        _migrationFileName = null;
      });
    } on Object catch (e) {
      if (mounted) Notify.error(context, _msg(context, e));
    } finally {
      if (mounted) setState(() => _migrationBusy = false);
    }
  }

  Widget _migrationSection(BuildContext context) {
    return FormSection(
      title: context.tr('company_migration'),
      children: [
        Text(
          context.tr('migration_import_help'),
          style: TextStyle(fontSize: 13, color: context.inTheme.ink3),
        ),
        SizedBox(height: InSpacing.md(context)),
        FileDropZone(
          allowedExtensions: const ['zip', 'json'],
          enabled: !_migrationBusy,
          onFiles: _onMigrationFiles,
        ),
        if (_migrationFileName != null) ...[
          const SizedBox(height: InSpacing.sm),
          Text(
            _migrationFileName!,
            style: TextStyle(fontSize: 13, color: context.inTheme.ink2),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _migrationImportSettings,
          onChanged: _migrationBusy
              ? null
              : (v) => setState(() => _migrationImportSettings = v),
          title: Text(context.tr('import_settings')),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: (_migrationSource == null || _migrationBusy)
                ? null
                : _runMigration,
            child: _migrationBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('import')),
          ),
        ),
      ],
    );
  }

  Widget _exportSection(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final formatter = services.formatterIfReady(companyId);
    final dateKeys = _kExportDates[_exportType] ?? const <String>[];
    // A "custom" range needs both ends — otherwise the server 422s on the
    // required_if. Disable the action rather than surface that error.
    final customIncomplete =
        _exportDateKey != null &&
        _exportDateRange == 'custom' &&
        (_exportStart == null ||
            _exportEnd == null ||
            _exportEnd!.isBefore(_exportStart!));
    return FormSection(
      title: context.tr('export'),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _exportType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('export_type'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _exporting
              ? null
              : (v) => setState(() {
                  _exportType = v ?? _exportType;
                  // Reset the date filter when the entity changes (React parity).
                  _exportDateKey = null;
                  _exportDateRange = 'last7';
                  _exportStart = null;
                  _exportEnd = null;
                  // Drop a stale "attach documents" choice when switching to a
                  // type that doesn't support it.
                  _exportDocuments = false;
                }),
          items: [
            // No module filter here: this State persists across a company
            // switch (the settings shell keys its subtree by level, not
            // company), so a filtered list could omit the stale `_exportType`
            // and trip DropdownButtonFormField's value-in-items assertion.
            // React's Export.tsx lists every type unconditionally too.
            for (final t in _exportTypes)
              DropdownMenuItem(value: t, child: Text(context.tr(t))),
          ],
        ),
        if (dateKeys.isNotEmpty) ...[
          SizedBox(height: InSpacing.md(context)),
          DropdownButtonFormField<String?>(
            initialValue: _exportDateKey,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('date'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _exporting
                ? null
                : (v) => setState(() {
                    _exportDateKey = v;
                    if (v != null) _exportDateRange = 'last7';
                  }),
            items: [
              DropdownMenuItem(value: null, child: Text(context.tr('all'))),
              for (final k in dateKeys)
                DropdownMenuItem(value: k, child: Text(context.tr(k))),
            ],
          ),
        ],
        if (_exportDateKey != null) ...[
          SizedBox(height: InSpacing.md(context)),
          DropdownButtonFormField<String>(
            initialValue: _exportDateRange,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('date_range'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _exporting
                ? null
                : (v) =>
                      setState(() => _exportDateRange = v ?? _exportDateRange),
            items: [
              for (final (id, label) in _kDateRanges)
                DropdownMenuItem(value: id, child: Text(context.tr(label))),
            ],
          ),
        ],
        if (_exportDateKey != null && _exportDateRange == 'custom') ...[
          SizedBox(height: InSpacing.md(context)),
          InDateField(
            value: _exportStart,
            formatter: formatter,
            labelText: context.tr('start_date'),
            clearable: true,
            onChanged: (d) => setState(() => _exportStart = d),
          ),
          SizedBox(height: InSpacing.md(context)),
          InDateField(
            value: _exportEnd,
            formatter: formatter,
            labelText: context.tr('end_date'),
            clearable: true,
            onChanged: (d) => setState(() => _exportEnd = d),
          ),
        ],
        if (_kExportHasDocuments.contains(_exportType)) ...[
          SizedBox(height: InSpacing.md(context)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _exportDocuments,
            onChanged: _exporting
                ? null
                : (v) => setState(() => _exportDocuments = v),
            title: Text(context.tr('attach_documents')),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _exportIncludeDeleted,
          onChanged: _exporting
              ? null
              : (v) => setState(() => _exportIncludeDeleted = v),
          title: Text(context.tr('include_deleted')),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: (_exporting || customIncomplete) ? null : _runExport,
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(context.tr('export')),
          ),
        ),
      ],
    );
  }

  /// Direct third-party importers (FreshBooks / Wave / Zoho / …). Fixed-schema
  /// formats → no preimport/column-map; a multipart POST straight to
  /// `/api/v1/import`. Mirrors React `Import.tsx`.
  Widget _thirdPartySection(BuildContext context) {
    final groups = _kThirdPartyImports[_thirdPartyType] ?? const <String>[];
    final ready = groups.every(_thirdPartyFiles.containsKey);
    return FormSection(
      // Distinct from the CSV column-map import card above (also titled
      // "Import") so the two stacked sections aren't indistinguishable.
      title: context.tr('import_third_party'),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _thirdPartyType,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('import_type'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _thirdPartyBusy
              ? null
              : (v) => setState(() {
                  _thirdPartyType = v ?? _thirdPartyType;
                  _thirdPartyFiles.clear();
                }),
          items: [
            for (final t in _kThirdPartyImports.keys)
              DropdownMenuItem(value: t, child: Text(context.tr(t))),
          ],
        ),
        for (final group in groups) ...[
          SizedBox(height: InSpacing.md(context)),
          Text(
            context.tr(group),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: InSpacing.sm),
          FileDropZone(
            allowedExtensions: group == 'backup'
                ? const ['zip']
                : const ['csv'],
            enabled: !_thirdPartyBusy,
            onFiles: (sources) => _onThirdPartyFiles(group, sources),
          ),
          if (_thirdPartyFiles[group] != null) ...[
            const SizedBox(height: InSpacing.sm),
            Text(
              _thirdPartyFiles[group]!.name,
              style: TextStyle(fontSize: 13, color: context.inTheme.ink2),
            ),
          ],
        ],
        SizedBox(height: InSpacing.md(context)),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: (!ready || _thirdPartyBusy) ? null : _runThirdParty,
            child: _thirdPartyBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('import')),
          ),
        ),
      ],
    );
  }

  Future<void> _onThirdPartyFiles(
    String group,
    List<UploadSource> sources,
  ) async {
    if (sources.isEmpty) return;
    final source = sources.first;
    final bytes = await source.readRange(0, await source.length());
    if (!mounted) return;
    if (bytes.isEmpty) {
      Notify.warning(context, context.tr('dropzone_invalid_file_type'));
      return;
    }
    setState(() {
      _thirdPartyFiles[group] = (bytes: bytes, name: source.fileName);
    });
  }

  Future<void> _runThirdParty() async {
    if (_thirdPartyBusy) return;
    final groups = _kThirdPartyImports[_thirdPartyType] ?? const <String>[];
    setState(() => _thirdPartyBusy = true);
    try {
      await _api.runThirdPartyImport(
        importType: _thirdPartyType,
        files: [
          for (final group in groups)
            if (_thirdPartyFiles[group] != null)
              (
                key: _kThirdPartyFileKey[group] ?? group,
                bytes: _thirdPartyFiles[group]!.bytes,
                fileName: _thirdPartyFiles[group]!.name,
              ),
        ],
      );
      if (!mounted) return;
      Notify.success(context, context.tr('import_started'));
      setState(() => _thirdPartyFiles.clear());
    } on Object catch (e) {
      if (mounted) Notify.error(context, _msg(context, e));
    } finally {
      if (mounted) setState(() => _thirdPartyBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScreenScaffold(
      titleKey: 'import_export',
      body: SettingsFormShell(
        sections: [
          switch (_step) {
            _Step.pick => _pickSection(context),
            _Step.map => _mapSection(context),
            _Step.done => _doneSection(context),
          },
          if (_step == _Step.pick) _thirdPartySection(context),
          if (_step == _Step.pick) _migrationSection(context),
          if (_step == _Step.pick) _exportSection(context),
        ],
      ),
    );
  }

  /// Bank-account picker, shown only for `bank_transaction` imports — the
  /// `/api/v1/import` endpoint requires a `bank_integration_id` so imported
  /// rows attach to a target account.
  Widget _bankAccountField(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: StreamBuilder<List<BankAccount>>(
        stream: services.bankAccounts.watchAll(companyId: companyId),
        builder: (context, snap) {
          final accounts = (snap.data ?? const <BankAccount>[])
              .where((a) => !a.isDeleted)
              .toList();
          if (accounts.isEmpty) {
            // Nothing to attach imported transactions to — explain why the
            // Continue button stays disabled instead of showing an empty,
            // unselectable dropdown.
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.tr('no_bank_accounts'),
                style: TextStyle(fontSize: 13, color: context.inTheme.ink3),
              ),
            );
          }
          // Guard against a stale id carried over from another company (this
          // State persists across a company switch) — an `initialValue` absent
          // from `items` trips DropdownButtonFormField's value-in-items assert.
          final selected = accounts.any((a) => a.id == _bankIntegrationId)
              ? _bankIntegrationId
              : null;
          return DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('bank_account'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _busy
                ? null
                : (v) => setState(() => _bankIntegrationId = v),
            items: [
              for (final a in accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(a.name.isEmpty ? a.id : a.name),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _pickSection(BuildContext context) {
    return FormSection(
      title: context.tr('import'),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _entity,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: context.tr('import_type'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _busy
              ? null
              : (v) => setState(() {
                  _entity = v ?? _entity;
                  _bankIntegrationId = null;
                }),
          items: [
            // List every importable entity unconditionally (no module filter):
            // this State persists across a company switch, so a filtered list
            // could omit the stale `_entity` and trip DropdownButtonFormField's
            // value-in-items assertion. Mirrors the export picker above.
            for (final e in kImportableEntities)
              DropdownMenuItem(value: e, child: Text(context.tr(e))),
          ],
        ),
        if (_entity == 'bank_transaction') _bankAccountField(context),
        FileDropZone(
          allowedExtensions: const ['csv'],
          enabled: !_busy,
          onFiles: _onCsvFiles,
        ),
        if (_fileName != null) ...[
          const SizedBox(height: InSpacing.sm),
          Text(
            _fileName!,
            style: TextStyle(fontSize: 13, color: context.inTheme.ink2),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed:
                (_bytes == null ||
                    _busy ||
                    (_entity == 'bank_transaction' &&
                        (_bankIntegrationId ?? '').isEmpty))
                ? null
                : _runPreImport,
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('continue')),
          ),
        ),
      ],
    );
  }

  Widget _mapSection(BuildContext context) {
    final preview = _preview!;
    final tokens = context.inTheme;
    return FormSection(
      title: context.tr('column_mapping'),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _skipHeader,
          onChanged: _busy ? null : (v) => setState(() => _skipHeader = v),
          title: Text(context.tr('skip_header')),
        ),
        const Divider(height: 1),
        // One full-width searchable field per CSV column — the column name is
        // the field label, the first sample value a caption beneath it. `''`
        // is a sentinel "skip" entry so the picker still reads "Skip" for an
        // unmapped column while staying type-to-search (an entity's field list
        // can run 50+ deep). Full-width (not a 2-column row) so it stacks
        // cleanly on phones with no overflow.
        for (var i = 0; i < preview.columns.length; i++)
          Padding(
            padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchableDropdownField<String>(
                  label: preview.columns[i],
                  items: ['', ...preview.available],
                  initialValue: _map[i] ?? '',
                  displayString: (f) => f.isEmpty ? context.tr('skip') : f,
                  idOf: (f) => f,
                  onChanged: (f) {
                    if (_busy) return;
                    setState(() => _map[i] = f ?? '');
                  },
                ),
                if (i < preview.sample.length && preview.sample[i].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      preview.sample[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.ink3),
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: _busy ? null : _reset,
              child: Text(context.tr('back')),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                onPressed: (_busy || _map.values.every((v) => v.isEmpty))
                    ? null
                    : _runImport,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('import')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _doneSection(BuildContext context) {
    return FormSection(
      title: context.tr('import'),
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: context.inTheme.accent),
            SizedBox(width: InSpacing.md(context)),
            Expanded(child: Text(context.tr('import_started'))),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: _reset,
            child: Text(context.tr('done')),
          ),
        ),
      ],
    );
  }
}

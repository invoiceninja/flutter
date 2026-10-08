import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_schedule_seed.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/domain/reports/report_csv.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/domain/reports/report_schedule.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/labeled_switch_group.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/reports/helpers/report_range.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/report_states.dart';
import 'package:admin/utils/file_names.dart';
import 'package:admin/utils/formatting.dart';

/// What a report can be turned into, and how. One place, used by the wide
/// header's Export button and the narrow app bar's overflow alike.
///
/// The choices are honest about what each one is:
/// * **this view** — the rows on screen, exactly as filtered, sorted and
///   arranged, written on the device. Nothing else honours a column filter
///   or the row search, because the server is never told about them;
/// * **the full report** — the server's own file, whose type the server
///   decides (a spreadsheet, or a PDF where the report is one);
/// * **a PDF from a template**, where the report has template designs;
/// * **by email**, and **on a schedule**.
class ReportExportActions {
  ReportExportActions({
    required this.vm,
    required this.view,
    required this.formatter,
    required this.currencyId,
    required this.enabled,
  });

  final ReportsViewModel vm;
  final ReportView? view;
  final Formatter? formatter;
  final String currencyId;

  /// False behind the plan gate: every action is listed and none can run.
  final bool enabled;

  ReportDefinition get _definition => vm.definition;

  bool get _hasView {
    final v = view;
    return v != null && (v.rows.isNotEmpty || v.groups.isNotEmpty);
  }

  bool get offersTemplate =>
      _definition.filterFields.contains(ReportFilterField.template);

  bool get _offersPdfAttachment =>
      _definition.filterFields.contains(ReportFilterField.pdfEmailAttachment);

  bool get _offersDocumentAttachment => _definition.filterFields.contains(
    ReportFilterField.documentEmailAttachment,
  );

  /// The menu's entries.
  List<Widget> menuItems(BuildContext context) {
    final tr = context.tr;
    final v = view;
    VoidCallback? when(bool condition, VoidCallback action) =>
        enabled && condition ? action : null;
    return [
      if (_definition.supportsPreview) ...[
        MenuItemButton(
          leadingIcon: const Icon(Icons.table_rows_outlined, size: 16),
          onPressed: when(_hasView, () => _downloadView(context)),
          child: Text(tr('report_download_view')),
        ),
        if (v != null && v.groups.isNotEmpty)
          MenuItemButton(
            leadingIcon: const Icon(Icons.segment, size: 16),
            onPressed: when(true, () => _downloadView(context, summary: true)),
            child: Text(tr('report_download_groups')),
          ),
        const Divider(height: 1),
      ],
      MenuItemButton(
        leadingIcon: const Icon(Icons.download_outlined, size: 16),
        onPressed: when(!vm.isExporting, () => _downloadFromServer(context)),
        child: Text(tr('report_download_server')),
      ),
      if (offersTemplate)
        MenuItemButton(
          leadingIcon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          onPressed: when(!vm.isExporting, () => _downloadTemplate(context)),
          child: Text(tr('report_download_template')),
        ),
      MenuItemButton(
        leadingIcon: const Icon(Icons.email_outlined, size: 16),
        onPressed: when(!vm.isEmailing, () => _email(context)),
        child: Text(tr('report_email_me')),
      ),
      // Offered only for reports the server's scheduled-report runner
      // handles; it deletes a schedule naming any other.
      if (isReportSchedulable(vm.reportIdentifier))
        MenuItemButton(
          leadingIcon: const Icon(Icons.schedule_outlined, size: 16),
          onPressed: when(true, () => _schedule(context)),
          child: Text(tr('schedule')),
        ),
    ];
  }

  /// The name a download is saved under: the report and its range.
  ///
  /// Sanitised here, at the one place a name is made — the range is rendered
  /// through the company's date format, which is `/`-separated on four of the
  /// fourteen, and an illegal name is a save that silently does nothing.
  String _fileName(BuildContext context, String extension) {
    final stem = sanitizeFileName(
      '${context.tr(_definition.labelKey)} '
      '${reportRangeLabel(context, vm.payload, formatter)}',
      fallback: 'report',
    );
    return '$stem.$extension';
  }

  Future<void> _downloadView(
    BuildContext context, {
    bool summary = false,
  }) async {
    final v = view;
    if (v == null) return;
    final toasts = Notify.capture(context);
    final tr = context.tr;
    final name = _fileName(context, 'csv');
    final groupType = vm.groupColumn?.type;
    final csv = buildReportCsv(
      view: v,
      summary: summary,
      currencyId: currencyId,
      countLabel: tr('count'),
      groupLabel: (key) => reportGroupDisplayLabel(
        key: key,
        columnType: groupType,
        subgroup: vm.subgroup,
        formatter: formatter,
      ),
    );
    await _save(toasts, tr, name, reportCsvBytes(csv));
  }

  Future<void> _downloadFromServer(
    BuildContext context, {
    String? templateId,
  }) async {
    final toasts = Notify.capture(context);
    final tr = context.tr;
    // Named before the wait, while the context is certainly alive. The
    // extension is what the file turned out to be — the server decides, the
    // app only reads the answer.
    final names = {
      for (final format in ReportExportFormat.values)
        format: _fileName(context, format.defaultExtension),
    };
    Future<void> save(ReportExportResult result) =>
        _save(toasts, tr, names[result.format]!, result.bytes);
    final result = await vm.runExport(templateId: templateId);
    if (result != null) {
      await save(result);
      return;
    }
    final error = vm.exportError;
    if (error == null) return;
    if (error.kind == ReportErrorKind.timeout) {
      toasts?.warning(
        tr('report_timed_out'),
        action: NotifyAction(tr('keep_waiting'), () async {
          final retry = await vm.keepWaitingExport();
          if (retry != null) await save(retry);
        }),
      );
      return;
    }
    if (error.kind == ReportErrorKind.emailedInstead) {
      // Not a failure the reader can retry out of: the report is in their
      // inbox. Said plainly, as information.
      toasts?.info(tr('report_emailed_instead'));
      return;
    }
    // A captured controller has no fallback of its own for a blank message,
    // so the server's string is never passed through bare.
    toasts?.error(reportErrorText(tr, error));
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final entity = _definition.rowRecordWire ?? vm.reportIdentifier;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => _TemplateDialog(
        designs: services.designs.watchAll(companyId: companyId),
        entity: entity,
      ),
    );
    if (picked == null || !context.mounted) return;
    await _downloadFromServer(context, templateId: picked);
  }

  Future<void> _email(BuildContext context) async {
    final toasts = Notify.capture(context);
    final tr = context.tr;
    final choice = await showDialog<(bool, bool)>(
      context: context,
      builder: (context) => _EmailDialog(
        offerPdfs: _offersPdfAttachment,
        offerDocuments: _offersDocumentAttachment,
        hasColumnFilters: vm.columnFilters.isNotEmpty || vm.search.isNotEmpty,
      ),
    );
    if (choice == null) return;
    try {
      await vm.sendEmail(attachPdfs: choice.$1, attachDocuments: choice.$2);
      // Not `email_sent` — that key is a notification-preference label with
      // markup in it. The server queues the report and mails it later.
      toasts?.success(tr('email_queued'));
    } catch (_) {
      toasts?.error(tr('an_error_occurred'));
    }
  }

  void _schedule(BuildContext context) {
    final seed = ReportScheduleSeed(
      reportIdentifier: vm.reportIdentifier,
      payload: vm.payload,
      // The visible columns in the reader's order, minus any the server
      // cannot render into a file; `groupBy` likewise.
      reportKeys: vm.serverReportKeys(ordered: true),
      groupBy: vm.serverGroupBy,
    );
    // Reports → Settings crosses branches, which drops a route's `extra`;
    // the seed is staged where the schedule screen looks for it.
    context.read<Services>().stageCreateDraft('/settings/schedules', seed);
    context.go('/settings/schedules/new');
  }

  static Future<void> _save(
    ToastController? toasts,
    String Function(String, [Map<String, String>?]) tr,
    String name,
    Uint8List bytes,
  ) async {
    try {
      final path = await FilePicker.saveFile(fileName: name, bytes: bytes);
      if (path == null) return;
      // Desktop returns a path without writing; the web has no filesystem
      // (the browser has already downloaded it). Write only where asked to.
      if (!kIsWeb) {
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes);
        }
      }
      toasts?.success(tr('exported'));
    } catch (_) {
      toasts?.error(tr('an_error_occurred'));
    }
  }
}

/// The Export button of the wide header: a menu of [ReportExportActions].
class ReportExportButton extends StatelessWidget {
  const ReportExportButton({super.key, required this.actions});

  final ReportExportActions actions;

  @override
  Widget build(BuildContext context) {
    final vm = actions.vm;
    if (vm.isExporting) {
      return OutlinedButton.icon(
        onPressed: vm.cancelExport,
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        icon: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(context.tr('cancel')),
      );
    }
    return BackDismissibleMenuAnchor(
      menuChildren: actions.menuItems(context),
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        icon: const Icon(Icons.download_outlined, size: 16),
        label: Text(context.tr('export')),
      ),
    );
  }
}

class _EmailDialog extends StatefulWidget {
  const _EmailDialog({
    required this.offerPdfs,
    required this.offerDocuments,
    required this.hasColumnFilters,
  });

  final bool offerPdfs;
  final bool offerDocuments;
  final bool hasColumnFilters;

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  bool _pdfs = false;
  bool _documents = false;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final tokens = context.inTheme;
    return AlertDialog(
      title: Text(tr('report_email_me')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('report_email_body'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.ink2),
            ),
            if (widget.offerPdfs || widget.offerDocuments) ...[
              const SizedBox(height: InSpacing.sm),
              LabeledSwitchGroup(
                items: [
                  if (widget.offerPdfs)
                    LabeledSwitchItem(
                      label: tr('attach_pdf'),
                      value: _pdfs,
                      onChanged: (v) => setState(() => _pdfs = v),
                    ),
                  if (widget.offerDocuments)
                    LabeledSwitchItem(
                      label: tr('attach_documents'),
                      value: _documents,
                      onChanged: (v) => setState(() => _documents = v),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
        PrimaryDialogAction(
          label: tr('email'),
          onPressed: () => Navigator.of(context).pop((_pdfs, _documents)),
        ),
      ],
    );
  }
}

/// Pick one of the company's template designs for this report's entity.
class _TemplateDialog extends StatelessWidget {
  const _TemplateDialog({required this.designs, required this.entity});

  final Stream<List<Design>> designs;
  final String entity;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final tokens = context.inTheme;
    return SimpleDialog(
      title: Text(tr('template')),
      children: [
        StreamBuilder<List<Design>>(
          stream: designs,
          builder: (context, snapshot) {
            final all = snapshot.data;
            if (all == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            // A template is written for particular entities; one that does
            // not list this report's would render nothing.
            final templates = [
              for (final d in all)
                if (d.isTemplate &&
                    (d.entities.isEmpty || d.entities.contains(entity)))
                  d,
            ];
            if (templates.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  tr('report_no_templates'),
                  style: TextStyle(color: tokens.ink2),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in templates)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(d.id),
                    child: Text(d.name),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

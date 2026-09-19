import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/clients/view_models/client_statement_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/utils/file_names.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/pdf_bytes_guard.dart';

/// Full-screen view for `POST /api/v1/client_statement`. Fetches a PDF and
/// renders it via `printing`'s [PdfPreview]. The package's toolbar handles
/// print, share, and save; the AppBar adds a Refresh affordance because
/// [PdfPreview] doesn't surface one itself.
class ClientStatementScreen extends StatefulWidget {
  const ClientStatementScreen({required this.clientId, super.key});

  final String clientId;

  @override
  State<ClientStatementScreen> createState() => _ClientStatementScreenState();
}

class _ClientStatementScreenState extends State<ClientStatementScreen>
    with FormatterHostMixin {
  late final ClientStatementViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ClientStatementViewModel(
      repo: _services.clients,
      api: _services.clients.api,
      connectivity: _services.connectivity,
      companyId: _companyId,
      clientId: widget.clientId,
      firstMonthOfYear:
          _services.formatterIfReady(_companyId)?.settings.firstMonthOfYear ??
          1,
    );
    loadFormatter(_services, _companyId);
    // Cold-start fallback: the sync source above misses if the formatter wasn't
    // cached yet. Push the real fiscal year in once it resolves (cached future,
    // so this is cheap) so This Year / Last Year statements match the picker.
    _services.formatterFor(_companyId).then((f) {
      if (mounted) _vm.updateFiscalYearStart(f.settings.firstMonthOfYear);
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: ListenableBuilder(
            listenable: _vm,
            builder: (_, _) =>
                _FilterControls(vm: _vm, formatter: formatter, narrow: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final client = _vm.client;
        final title = client == null
            ? context.tr('statement')
            : '${context.tr('statement')} — ${client.displayName}';
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = Breakpoints.isWide(constraints);
            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: [
                  if (!wide)
                    IconButton(
                      tooltip: context.tr('filters'),
                      icon: const Icon(Icons.filter_alt_outlined),
                      onPressed: _openFiltersSheet,
                    ),
                  IconButton(
                    tooltip: context.tr('refresh'),
                    icon: const Icon(Icons.refresh),
                    onPressed: _vm.isLoading ? null : () => _vm.load(),
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (wide)
                    Padding(
                      padding: EdgeInsets.all(InSpacing.md(context)),
                      child: _FilterControls(
                        vm: _vm,
                        formatter: formatter,
                        narrow: false,
                      ),
                    ),
                  Expanded(child: _Body(vm: _vm)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm});
  final ClientStatementViewModel vm;

  @override
  Widget build(BuildContext context) {
    final bytes = vm.pdfBytes;
    final err = vm.error;
    // First-load: full-screen spinner. Subsequent loads keep the last-good PDF
    // visible behind a translucent overlay so filter changes don't blink.
    if (bytes == null && vm.isLoading && err == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bytes == null && err != null) {
      return ErrorView(message: _errorMessage(context, err), onRetry: vm.load);
    }
    if (bytes == null) {
      // Idle no-bytes/no-error path — unreachable in practice because the VM
      // kicks load() on construction, but keep a neutral placeholder.
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: context.tr('statement'),
      );
    }
    if (!isRenderablePdf(bytes)) {
      // Empty / non-PDF response — don't feed printing's rasterizer a
      // zero-page document (RangeError).
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        title: context.tr('statement'),
      );
    }
    final fileName =
        '${sanitizeFileName('statement_${vm.client?.number ?? vm.clientId}')}.pdf';
    final scrim = Theme.of(context).colorScheme.scrim.withValues(alpha: 0.4);
    return Stack(
      children: [
        Positioned.fill(
          child: PdfPreview(
            build: (_) => bytes,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            maxPageWidth: 800,
            pdfFileName: fileName,
          ),
        ),
        if (vm.isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: scrim,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        if (err != null)
          // Anchor at the bottom so the inline banner doesn't occlude
          // PdfPreview's print/share toolbar at the top.
          Positioned(
            left: InSpacing.md(context),
            right: InSpacing.md(context),
            bottom: InSpacing.md(context),
            child: _InlineErrorBanner(
              message: _errorMessage(context, err),
              onRetry: vm.isLoading ? null : vm.load,
            ),
          ),
      ],
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return Material(
      color: t.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: InSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: t.overdue, size: 20),
            const SizedBox(width: InSpacing.sm),
            Expanded(
              child: Text(message, style: TextStyle(color: t.ink)),
            ),
            const SizedBox(width: InSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(context.tr('retry'))),
          ],
        ),
      ),
    );
  }
}

class _FilterControls extends StatelessWidget {
  const _FilterControls({
    required this.vm,
    required this.formatter,
    required this.narrow,
  });

  final ClientStatementViewModel vm;
  final Formatter? formatter;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      DateRangePickerButton(
        current: vm.range,
        onChange: vm.setRange,
        formatter: formatter,
      ),
      _StatusButton(current: vm.status, onChange: vm.setStatus),
      _ShowTableToggleButton(
        label: context.tr('show_payments_table'),
        selected: vm.showPayments,
        onChange: vm.setShowPayments,
      ),
      _ShowTableToggleButton(
        label: context.tr('show_credits_table'),
        selected: vm.showCredits,
        onChange: vm.setShowCredits,
      ),
      _ShowTableToggleButton(
        label: context.tr('show_aging_table'),
        selected: vm.showAging,
        onChange: vm.setShowAging,
      ),
    ];
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final w in children)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
              child: Align(alignment: Alignment.centerLeft, child: w),
            ),
        ],
      );
    }
    return Wrap(
      spacing: InSpacing.sm,
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.current, required this.onChange});

  final StatementStatus current;
  final ValueChanged<StatementStatus> onChange;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return PopupMenuButton<StatementStatus>(
      tooltip: context.tr('status'),
      onSelected: onChange,
      itemBuilder: (_) => [
        for (final s in StatementStatus.values)
          CheckedPopupMenuItem(
            value: s,
            checked: s == current,
            child: Text(context.tr(s.name)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InRadii.r2),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 14, color: tokens.ink2),
            const SizedBox(width: 6),
            Text(
              context.tr(current.name),
              style: TextStyle(fontSize: 13, color: tokens.ink2),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink2),
          ],
        ),
      ),
    );
  }
}

class _ShowTableToggleButton extends StatelessWidget {
  const _ShowTableToggleButton({
    required this.label,
    required this.selected,
    required this.onChange,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: selected ? tokens.surface : tokens.ink2,
        backgroundColor: selected ? tokens.ink : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
          side: BorderSide(color: selected ? tokens.ink : tokens.border),
        ),
      ),
      // Reserve the leading slot in both states so the label x-position
      // doesn't shift when toggling.
      icon: SizedBox(
        width: 14,
        height: 14,
        child: selected ? const Icon(Icons.check, size: 14) : null,
      ),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      onPressed: () => onChange(!selected),
    );
  }
}

String _errorMessage(BuildContext context, StatementError err) {
  if (err is StatementNetworkError && err.message == 'Offline') {
    return context.tr('offline');
  }
  return err.message;
}

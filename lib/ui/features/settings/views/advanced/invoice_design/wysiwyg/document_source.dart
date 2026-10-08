import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/designer_pane.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/real_document.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/utils/formatting.dart';

/// Which document the designer is filled in with: one of the company's
/// recent invoices, or the made-up sample.
///
/// The page and the server preview used to show two different documents — a
/// fictional one here, whatever the server picked there — so nothing could
/// be compared between them. Both now take their document from here.
///
/// It is a way of looking at the design, not part of it: nothing here is
/// saved, and a different choice never makes the design dirty.
class DesignerDocumentController extends ChangeNotifier {
  DesignerDocumentController({
    required Future<List<Invoice>> Function() loadRecent,
    required Future<Client?> Function(String clientId) loadClient,
  }) : _loadRecent = loadRecent,
       _loadClient = loadClient;

  final Future<List<Invoice>> Function() _loadRecent;
  final Future<Client?> Function(String clientId) _loadClient;

  List<Invoice> _recent = const [];
  Invoice? _invoice;
  Client? _client;
  int _seq = 0;
  bool _disposed = false;

  /// The invoices on offer, newest first. Only ones the server knows: an
  /// unsynced invoice has no id the preview could ask for.
  List<Invoice> get recent => _recent;

  /// The chosen invoice; null while loading, when there are none, or when
  /// the sample was chosen.
  Invoice? get invoice => _invoice;
  Client? get client => _client;

  /// Load the recent invoices and start on the newest. A failure leaves the
  /// sample in place — the designer works without any of this.
  Future<void> load() async {
    try {
      final all = await _loadRecent();
      if (_disposed) return;
      _recent = [
        for (final i in all)
          if (!i.id.startsWith('tmp_') && i.id.isNotEmpty) i,
      ];
    } catch (_) {
      return;
    }
    await showInvoice(_recent.firstOrNull?.id);
  }

  /// Show invoice [id], or the sample for null.
  Future<void> showInvoice(String? id) async {
    final seq = ++_seq;
    final next = _recent.where((i) => i.id == id).firstOrNull;
    Client? client;
    if (next != null && next.clientId.isNotEmpty) {
      try {
        client = await _loadClient(next.clientId);
      } catch (_) {
        client = null;
      }
    }
    // A later choice made while the client loaded wins.
    if (_disposed || seq != _seq) return;
    _invoice = next;
    _client = client;
    notifyListeners();
  }

  /// The document the page draws: [base] (the sample with the company's own
  /// letterhead) or, when an invoice is chosen, that invoice over it.
  DesignerSampleData documentOver(
    DesignerSampleData base, {
    Formatter? formatter,
  }) {
    final invoice = _invoice;
    if (invoice == null) return base;
    // Asked for on every notification of the workspace (each keystroke in
    // the panel). The totals are worth computing once per document — and
    // the *same* object back keeps the page's render scope from telling
    // every block its document changed.
    final memo = _memo;
    if (memo != null &&
        identical(memo.base, base) &&
        identical(memo.formatter, formatter) &&
        identical(memo.invoice, invoice) &&
        identical(memo.client, _client)) {
      return memo.document;
    }
    final document = designerDataFromInvoice(
      invoice: invoice,
      client: _client,
      base: base,
      precision:
          formatter?.precisionFor(clientCurrencyId: _client?.currencyId) ?? 2,
      countryName: formatter == null
          ? null
          : (id) => formatter.countries[id]?.name ?? '',
    );
    _memo = (
      base: base,
      formatter: formatter,
      invoice: invoice,
      client: _client,
      document: document,
    );
    return document;
  }

  ({
    DesignerSampleData base,
    Formatter? formatter,
    Invoice invoice,
    Client? client,
    DesignerSampleData document,
  })?
  _memo;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// "Invoice 0025 ▾" — says which document the page is filled in with and
/// lets it be changed. Renders nothing when there is no invoice to offer:
/// a control with one choice is not a control.
class DesignerDocumentButton extends StatelessWidget {
  const DesignerDocumentButton({
    super.key,
    required this.controller,
    this.formatter,
  });

  final DesignerDocumentController controller;
  final Formatter? formatter;

  static String labelFor(BuildContext context, Invoice? invoice) =>
      invoice == null
      ? context.tr('sample_document')
      : '${context.tr('invoice')} ${invoice.number}'.trim();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.recent.isEmpty) return const SizedBox.shrink();
        final current = controller.invoice;
        return Tooltip(
          message: context.tr('document_picker_hint'),
          child: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: tokens.ink2,
              minimumSize: const Size(44, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _open(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 15, color: tokens.ink3),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labelFor(context, current),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 18, color: tokens.ink3),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context) async {
    final tokens = context.inTheme;
    final box = context.findRenderObject()! as RenderBox;
    final current = controller.invoice?.id;
    // '' stands for the sample: a null value is "dismissed".
    final picked = await showMenu<String>(
      context: context,
      position: menuAnchor(context, box.localToGlobal(Offset.zero) & box.size),
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      items: [
        for (final invoice in controller.recent)
          _item(
            context,
            value: invoice.id,
            label: labelFor(context, invoice),
            // The date, not the amount: these may be in different
            // currencies, and only the chosen one's client is loaded.
            detail: invoice.date == null
                ? ''
                : formatter?.date(invoice.date!.toIso()) ?? '',
            selected: invoice.id == current,
            tokens: tokens,
          ),
        const PopupMenuDivider(),
        _item(
          context,
          value: '',
          label: context.tr('sample_document'),
          detail: '',
          selected: current == null,
          tokens: tokens,
        ),
      ],
    );
    if (picked == null) return;
    await controller.showInvoice(picked.isEmpty ? null : picked);
  }

  PopupMenuItem<String> _item(
    BuildContext context, {
    required String value,
    required String label,
    required String detail,
    required bool selected,
    required InTheme tokens,
  }) => PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        SizedBox(
          width: 22,
          child: selected
              ? Icon(Icons.check, size: 16, color: tokens.accent)
              : null,
        ),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (detail.isNotEmpty) ...[
          SizedBox(width: InSpacing.md(context)),
          Text(detail, style: TextStyle(fontSize: 12.5, color: tokens.ink3)),
        ],
      ],
    ),
  );
}

/// The strip under the canvas that carries [DesignerDocumentButton]. Takes
/// no height at all when there is nothing to choose between.
class DesignerDocumentBar extends StatelessWidget {
  const DesignerDocumentBar({
    super.key,
    required this.controller,
    this.formatter,
  });

  final DesignerDocumentController controller;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.recent.isEmpty) return const SizedBox.shrink();
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border, width: 0.5)),
          ),
          padding: EdgeInsets.symmetric(horizontal: InSpacing.md(context)),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Row(
              children: [
                Text(
                  context.tr('showing'),
                  style: TextStyle(fontSize: 12.5, color: tokens.ink3),
                ),
                Flexible(
                  child: DesignerDocumentButton(
                    controller: controller,
                    formatter: formatter,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

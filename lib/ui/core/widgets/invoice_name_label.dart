import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Resolves an invoice's number from the local Drift cache and renders
/// it as a `Text` (or a link when [link]). Falls back to the raw
/// `invoiceId` while the watch is empty; on a cache miss it triggers a
/// lazy per-id hydrate (`InvoiceRepository.ensureLoaded`) so the number
/// resolves even when the invoice isn't on the prefetched first page
/// (e.g. the invoice a quote converted to, or an expense's invoice).
///
/// Drift dedupes identical watch queries (and the repo dedupes the
/// hydrate fetch), so N rows referencing the same invoice share one
/// subscription and one network call.
class InvoiceNameLabel extends StatefulWidget {
  const InvoiceNameLabel({
    super.key,
    required this.invoiceId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.link = false,
  });

  final String invoiceId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  /// When true the resolved number renders as a hover-underlined link to
  /// the invoice's full-screen view. Off by default.
  final bool link;

  @override
  State<InvoiceNameLabel> createState() => _InvoiceNameLabelState();
}

class _InvoiceNameLabelState extends State<InvoiceNameLabel> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(InvoiceNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invoiceId != widget.invoiceId) _ensure();
  }

  /// Lazily hydrate the referenced invoice into Drift if it isn't cached
  /// (paginated lists prefetch only page 1). No-op / deduped / negative-
  /// cached in the repo, so it's safe to fire unconditionally here.
  void _ensure() {
    final id = widget.invoiceId;
    if (id.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    services.invoices.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (widget.invoiceId.isEmpty) {
      return Text(
        '—',
        style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, widget.invoiceId);
    }
    return StreamBuilder<Invoice?>(
      initialData: services.invoices.peek(
        companyId: companyId,
        id: widget.invoiceId,
      ),
      stream: services.invoices.watch(
        companyId: companyId,
        id: widget.invoiceId,
      ),
      builder: (context, snapshot) {
        final invoice = snapshot.data;
        final label = invoice == null || invoice.number.isEmpty
            ? widget.invoiceId
            : invoice.number;
        return _text(context, label);
      },
    );
  }

  Widget _text(BuildContext context, String text) => linkOrText(
    link: widget.link,
    label: text,
    onTap: widget.link
        ? () => goEntityFullDetail(context, '/invoices', widget.invoiceId)
        : null,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}

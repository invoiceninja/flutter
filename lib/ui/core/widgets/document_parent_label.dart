import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// "Linked to" for an uploaded file: the kind of record it hangs off and,
/// when that record is cached locally, its name or number — "Invoice 0042".
///
/// The server's document list names no parent (BACKEND.md § Documents list),
/// so [parentType] / [parentId] are whatever the app has learned
/// (`docs/documents-list.md`); both null renders the em dash. A record that
/// isn't cached shows its type alone and still links — the record screen
/// fetches it — so this never fans out one request per row.
///
/// The name stream is built once per parent, never in `build`: a list re-runs
/// `build` on every emission, and a fresh Drift watch per pass is churn.
class DocumentParentLabel extends StatefulWidget {
  const DocumentParentLabel({
    super.key,
    required this.parentType,
    required this.parentId,
    this.link = false,
    this.style,
  });

  final EntityType? parentType;
  final String? parentId;

  /// Render as a link to the record. Off in a list cell, whose row already
  /// has one destination (`docs/row-actions-and-values.md`).
  final bool link;
  final TextStyle? style;

  @override
  State<DocumentParentLabel> createState() => _DocumentParentLabelState();
}

class _DocumentParentLabelState extends State<DocumentParentLabel> {
  Stream<String?>? _name;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _name ??= _watchName();
  }

  @override
  void didUpdateWidget(DocumentParentLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.parentType != widget.parentType ||
        oldWidget.parentId != widget.parentId) {
      _name = _watchName();
    }
  }

  Stream<String?> _watchName() {
    final type = widget.parentType;
    final id = widget.parentId;
    if (type == null || id == null || id.isEmpty) return Stream.value(null);
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return Stream.value(null);
    return documentParentName(services, companyId, type, id);
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.parentType;
    final id = widget.parentId;
    final style =
        widget.style ?? TextStyle(fontSize: 13, color: context.inTheme.ink);
    if (type == null || id == null || id.isEmpty) {
      return Text('—', style: style.copyWith(color: context.inTheme.ink3));
    }
    return StreamBuilder<String?>(
      stream: _name,
      builder: (context, snap) {
        final kind = context.tr(documentParentLabelKey(type));
        final name = snap.data?.trim() ?? '';
        final text = name.isEmpty ? kind : '$kind $name';
        if (!widget.link) {
          return Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        }
        return LinkText(
          label: text,
          style: style,
          onTap: () => goDocumentParent(context, type, id),
        );
      },
    );
  }
}

/// The singular label key for a record type a document can hang off.
String documentParentLabelKey(EntityType type) => switch (type) {
  EntityType.recurringInvoice => 'recurring_invoice',
  EntityType.recurringExpense => 'recurring_expense',
  EntityType.purchaseOrder => 'purchase_order',
  _ => type.name,
};

/// Open the record [id] of [type] — a company's own file opens Company
/// Details → Documents, the one place a company document is listed.
void goDocumentParent(BuildContext context, EntityType type, String id) {
  if (type == EntityType.company) {
    GoRouter.of(context).go('/settings/company_details/documents');
    return;
  }
  goEntityRecord(context, type, id);
}

/// The cached record's display name or number, or null while it isn't cached.
Stream<String?> documentParentName(
  Services s,
  String companyId,
  EntityType type,
  String id,
) => switch (type) {
  EntityType.client =>
    s.clients.watch(companyId: companyId, id: id).map((e) => e?.displayName),
  EntityType.product =>
    s.products.watch(companyId: companyId, id: id).map((e) => e?.productKey),
  EntityType.invoice =>
    s.invoices.watch(companyId: companyId, id: id).map((e) => e?.number),
  EntityType.recurringInvoice =>
    s.recurringInvoices
        .watch(companyId: companyId, id: id)
        .map((e) => e?.number),
  EntityType.quote =>
    s.quotes.watch(companyId: companyId, id: id).map((e) => e?.number),
  EntityType.credit =>
    s.credits.watch(companyId: companyId, id: id).map((e) => e?.number),
  EntityType.payment =>
    s.payments.watch(companyId: companyId, id: id).map((e) => e?.number),
  EntityType.task =>
    s.tasks.watch(companyId: companyId, id: id).map((e) => e?.number),
  EntityType.project =>
    s.projects.watch(companyId: companyId, id: id).map((e) => e?.name),
  EntityType.expense =>
    s.expenses.watch(companyId: companyId, id: id).map((e) => e?.number),
  EntityType.recurringExpense =>
    s.recurringExpenses
        .watch(companyId: companyId, id: id)
        .map((e) => e?.number),
  EntityType.vendor =>
    s.vendors.watch(companyId: companyId, id: id).map((e) => e?.name),
  EntityType.purchaseOrder =>
    s.purchaseOrders.watch(companyId: companyId, id: id).map((e) => e?.number),
  EntityType.group =>
    s.groupSettings.watch(companyId: companyId, id: id).map((e) => e?.name),
  // The company IS the workspace; "Company" says all there is to say.
  _ => Stream.value(null),
};

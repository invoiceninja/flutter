import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_screen.dart';
import 'package:admin/utils/formatting.dart';

/// Route wrapper for `/<billing_doc>/:id/email`. Resolves the active
/// company + hosted flag + formatter, guards unsaved (`tmp_`) ids, watches
/// the entity, and binds the per-type repo callbacks for the shared
/// [BillingDocEmailScreen]. One widget handles all five billing docs via a
/// `switch` (the repos share method shapes).
class BillingDocEmailRouteScreen extends StatefulWidget {
  const BillingDocEmailRouteScreen({
    super.key,
    required this.type,
    required this.id,
  });

  final BillingDocType type;
  final String id;

  @override
  State<BillingDocEmailRouteScreen> createState() =>
      _BillingDocEmailRouteScreenState();
}

class _BillingDocEmailRouteScreenState
    extends State<BillingDocEmailRouteScreen> {
  late final Services _services;
  late final String _companyId;
  late final bool _isHosted;
  Formatter? _formatter;

  /// The doc stream, built ONCE and already TYPED.
  ///
  /// `repo.watch(...)` returns a fresh mapped stream object on every call, and
  /// so does `Stream.cast` — so building or casting in `build()` makes
  /// `StreamBuilder.didUpdateWidget` (an identity comparison) resubscribe on
  /// every rebuild, re-running the Drift query each time. Only one of these is
  /// ever non-null, chosen by the final `widget.type`. Assigned after the
  /// `tmp_` guard below: `watchByTempId` hands back a SINGLE-SUBSCRIPTION
  /// controller stream, which a resubscribe would blow up on.
  Stream<Invoice?>? _invoiceDoc;
  Stream<Quote?>? _quoteDoc;
  Stream<Credit?>? _creditDoc;
  Stream<PurchaseOrder?>? _purchaseOrderDoc;
  Stream<RecurringInvoice?>? _recurringDoc;

  /// Set when reached with an unsaved `tmp_` id (deep link / restored
  /// route) — there's no server id to email, so redirect to the detail.
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _isHosted = _services.auth.session.value?.isHosted ?? false;

    if (widget.id.startsWith('tmp_')) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/${widget.type.pluralLabelKey}/${widget.id}');
        }
      });
      return;
    }
    switch (widget.type) {
      case BillingDocType.invoice:
        _invoiceDoc = _services.invoices.watch(
          companyId: _companyId,
          id: widget.id,
        );
      case BillingDocType.quote:
        _quoteDoc = _services.quotes.watch(
          companyId: _companyId,
          id: widget.id,
        );
      case BillingDocType.credit:
        _creditDoc = _services.credits.watch(
          companyId: _companyId,
          id: widget.id,
        );
      case BillingDocType.purchaseOrder:
        _purchaseOrderDoc = _services.purchaseOrders.watch(
          companyId: _companyId,
          id: widget.id,
        );
      case BillingDocType.recurringInvoice:
        _recurringDoc = _services.recurringInvoices.watch(
          companyId: _companyId,
          id: widget.id,
        );
    }
    _services.formatterFor(_companyId).then((f) {
      if (mounted) setState(() => _formatter = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_redirecting) return _loading();
    return switch (widget.type) {
      BillingDocType.invoice => _invoice(),
      BillingDocType.quote => _quote(),
      BillingDocType.credit => _credit(),
      BillingDocType.purchaseOrder => _purchaseOrder(),
      BillingDocType.recurringInvoice => _recurring(),
    };
  }

  Widget _loading() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _notFound(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('send_email'))),
    body: EmptyState(
      icon: Icons.outgoing_mail,
      title: context.tr('no_records_found'),
    ),
  );

  Widget _screen({
    required List<Invitation> invitations,
    required String clientId,
    required String vendorId,
    required String number,
    required SendEmailCallback onSend,
    ScheduleEmailCallback? onSchedule,
    required Future<int> Function(String messageId) onReactivate,
    required Future<Uint8List> Function({
      String? designId,
      required bool deliveryNote,
    })
    pdfFetcher,
  }) => BillingDocEmailScreen(
    services: _services,
    companyId: _companyId,
    type: widget.type,
    entityId: widget.id,
    entityNumber: number,
    invitations: invitations,
    clientId: clientId,
    vendorId: vendorId,
    isHosted: _isHosted,
    formatter: _formatter,
    onSend: onSend,
    onSchedule: onSchedule,
    onReactivate: onReactivate,
    pdfFetcher: pdfFetcher,
  );

  Widget _invoice() => StreamBuilder<Invoice?>(
    stream: _invoiceDoc,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
        return _loading();
      }
      final e = snap.data;
      if (e == null) return _notFound(context);
      return _screen(
        invitations: e.invitations,
        clientId: e.clientId,
        vendorId: '',
        number: e.number,
        onSend: ({required template, subject, body, ccEmail}) =>
            _services.invoices.email(
              companyId: _companyId,
              id: widget.id,
              template: template,
              subject: subject,
              body: body,
              ccEmail: ccEmail,
            ),
        onSchedule:
            ({required template, required sendAt, subject, body, ccEmail}) =>
                _services.invoices.scheduleEmail(
                  companyId: _companyId,
                  id: widget.id,
                  template: template,
                  sendAt: sendAt,
                  subject: subject,
                  body: body,
                  ccEmail: ccEmail,
                ),
        onReactivate: (m) => _services.invoices.reactivateInvitationEmail(
          companyId: _companyId,
          id: widget.id,
          messageId: m,
        ),
        pdfFetcher: ({String? designId, required bool deliveryNote}) =>
            _services.invoices.api.downloadPdf(
              entityJson: e.toApiJson(),
              designId: designId ?? (e.designId.isEmpty ? null : e.designId),
              deliveryNote: deliveryNote,
            ),
      );
    },
  );

  Widget _quote() => StreamBuilder<Quote?>(
    stream: _quoteDoc,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
        return _loading();
      }
      final e = snap.data;
      if (e == null) return _notFound(context);
      return _screen(
        invitations: e.invitations,
        clientId: e.clientId,
        vendorId: '',
        number: e.number,
        onSend: ({required template, subject, body, ccEmail}) =>
            _services.quotes.email(
              companyId: _companyId,
              id: widget.id,
              template: template,
              subject: subject,
              body: body,
              ccEmail: ccEmail,
            ),
        onSchedule:
            ({required template, required sendAt, subject, body, ccEmail}) =>
                _services.quotes.scheduleEmail(
                  companyId: _companyId,
                  id: widget.id,
                  template: template,
                  sendAt: sendAt,
                  subject: subject,
                  body: body,
                  ccEmail: ccEmail,
                ),
        onReactivate: (m) => _services.quotes.reactivateInvitationEmail(
          companyId: _companyId,
          id: widget.id,
          messageId: m,
        ),
        pdfFetcher: ({String? designId, required bool deliveryNote}) =>
            _services.quotes.api.downloadPdf(
              entityJson: e.toApiJson(),
              designId: designId ?? (e.designId.isEmpty ? null : e.designId),
            ),
      );
    },
  );

  Widget _credit() => StreamBuilder<Credit?>(
    stream: _creditDoc,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
        return _loading();
      }
      final e = snap.data;
      if (e == null) return _notFound(context);
      return _screen(
        invitations: e.invitations,
        clientId: e.clientId,
        vendorId: '',
        number: e.number,
        onSend: ({required template, subject, body, ccEmail}) =>
            _services.credits.email(
              companyId: _companyId,
              id: widget.id,
              template: template,
              subject: subject,
              body: body,
              ccEmail: ccEmail,
            ),
        onSchedule:
            ({required template, required sendAt, subject, body, ccEmail}) =>
                _services.credits.scheduleEmail(
                  companyId: _companyId,
                  id: widget.id,
                  template: template,
                  sendAt: sendAt,
                  subject: subject,
                  body: body,
                  ccEmail: ccEmail,
                ),
        onReactivate: (m) => _services.credits.reactivateInvitationEmail(
          companyId: _companyId,
          id: widget.id,
          messageId: m,
        ),
        pdfFetcher: ({String? designId, required bool deliveryNote}) =>
            _services.credits.api.downloadPdf(
              entityJson: e.toApiJson(),
              designId: designId ?? (e.designId.isEmpty ? null : e.designId),
            ),
      );
    },
  );

  Widget _purchaseOrder() => StreamBuilder<PurchaseOrder?>(
    stream: _purchaseOrderDoc,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
        return _loading();
      }
      final e = snap.data;
      if (e == null) return _notFound(context);
      return _screen(
        invitations: e.invitations,
        clientId: '',
        vendorId: e.vendorId,
        number: e.number,
        onSend: ({required template, subject, body, ccEmail}) =>
            _services.purchaseOrders.email(
              companyId: _companyId,
              id: widget.id,
              template: template,
              subject: subject,
              body: body,
              ccEmail: ccEmail,
            ),
        onSchedule:
            ({required template, required sendAt, subject, body, ccEmail}) =>
                _services.purchaseOrders.scheduleEmail(
                  companyId: _companyId,
                  id: widget.id,
                  template: template,
                  sendAt: sendAt,
                  subject: subject,
                  body: body,
                  ccEmail: ccEmail,
                ),
        onReactivate: (m) => _services.purchaseOrders.reactivateInvitationEmail(
          companyId: _companyId,
          id: widget.id,
          messageId: m,
        ),
        pdfFetcher: ({String? designId, required bool deliveryNote}) =>
            _services.purchaseOrders.api.downloadPdf(
              entityJson: e.toApiJson(),
              designId: designId ?? (e.designId.isEmpty ? null : e.designId),
            ),
      );
    },
  );

  Widget _recurring() => StreamBuilder<RecurringInvoice?>(
    stream: _recurringDoc,
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
        return _loading();
      }
      final e = snap.data;
      if (e == null) return _notFound(context);
      return _screen(
        invitations: e.invitations,
        clientId: e.clientId,
        vendorId: '',
        number: e.number,
        onSend: ({required template, subject, body, ccEmail}) =>
            _services.recurringInvoices.email(
              companyId: _companyId,
              id: widget.id,
              template: template,
              subject: subject,
              body: body,
              ccEmail: ccEmail,
            ),
        // No scheduled send for recurring invoices — the server's
        // task_scheduler rejects them. The composer hides its Schedule action
        // (BillingDocType.supportsScheduledSend == false), so this stays null.
        onSchedule: null,
        onReactivate: (m) =>
            _services.recurringInvoices.reactivateInvitationEmail(
              companyId: _companyId,
              id: widget.id,
              messageId: m,
            ),
        pdfFetcher: ({String? designId, required bool deliveryNote}) =>
            _services.recurringInvoices.api.downloadPdf(
              entityJson: e.toApiJson(),
              designId: designId ?? (e.designId.isEmpty ? null : e.designId),
            ),
      );
    },
  );
}

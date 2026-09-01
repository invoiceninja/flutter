import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/domain/billing/invoice_lock.dart';
import 'package:admin/l10n/localization.dart';

/// "This invoice is locked" notice above the invoice detail header.
///
/// Client-computed rather than read off the server's `isLocked` flag, which is
/// stale on list-sourced rows and on offline edits. The authoritative edit gate
/// lives in `InvoiceActions.dispatch` / the edit guard — this only keeps the
/// banner honest.
///
/// **Renders unconditionally**, collapsing to `SizedBox.shrink()` when nothing
/// locks the invoice, so the widget tree's SHAPE doesn't change when the reason
/// resolves. The caller must not wrap it in an `if`.
///
/// The reason is seeded synchronously ([peekInvoiceLockReason]) and then
/// corrected by the async cascade. That matters because the master-detail pane
/// re-keys its subtree per `:id`: without a seed every row click mounted this
/// at [InvoiceLockReason.none], resolved two Drift reads later, and pushed the
/// entire left column down ~44 px — invoice number, status pill, client, dates,
/// KPI strip and the whole tab block.
class InvoiceLockBanner extends StatefulWidget {
  const InvoiceLockBanner({
    super.key,
    required this.invoice,
    required this.companyId,
  });

  final Invoice invoice;

  /// Threaded from the screen rather than read off the session here: the rest
  /// of the detail screen uses its `initState`-captured company, and during a
  /// switch a locally-read `currentCompanyId` disagrees with it (and its `?? ''`
  /// fallback silently resolves an empty cascade).
  final String companyId;

  @override
  State<InvoiceLockBanner> createState() => _InvoiceLockBannerState();
}

class _InvoiceLockBannerState extends State<InvoiceLockBanner> {
  InvoiceLockReason _reason = InvoiceLockReason.none;

  /// Generation token for [_resolve]. `initState` and `didUpdateWidget` can
  /// both have a resolve in flight, and each is two independent Drift reads, so
  /// they can land out of order — stranding the banner on the WRONG client's
  /// cascade with nothing left to correct it. Only the newest resolve may write.
  int _resolveGen = 0;

  @override
  void initState() {
    super.initState();
    _reason = _seed() ?? InvoiceLockReason.none;
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(InvoiceLockBanner old) {
    super.didUpdateWidget(old);
    final a = old.invoice, b = widget.invoice;
    if (a.id != b.id ||
        a.statusId != b.statusId ||
        a.isLocked != b.isLocked ||
        a.date != b.date ||
        a.clientId != b.clientId ||
        old.companyId != widget.companyId) {
      unawaited(_resolve());
    }
  }

  InvoiceLockReason? _seed() => peekInvoiceLockReason(
    settings: context.read<Services>().settings,
    companyId: widget.companyId,
    invoice: widget.invoice,
  );

  Future<void> _resolve() async {
    final gen = ++_resolveGen;
    final reason = await resolveInvoiceLockReason(
      settings: context.read<Services>().settings,
      companyId: widget.companyId,
      invoice: widget.invoice,
    );
    if (!mounted || gen != _resolveGen) return;
    if (reason != _reason) setState(() => _reason = reason);
  }

  @override
  Widget build(BuildContext context) {
    if (_reason == InvoiceLockReason.none) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(InRadii.r2),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: tokens.ink2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr(invoiceLockMessageKey(_reason)),
                style: TextStyle(color: tokens.ink2, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

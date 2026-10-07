import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/needs_attention_band.dart';
import 'package:admin/ui/features/dashboard/widgets/section_listenable.dart';
import 'package:admin/utils/formatting.dart';

/// The needs-attention band's place at the head of a dashboard body — the band
/// and the gap beneath it, or nothing at all.
///
/// **It is always exactly one child of the list it sits in.** Both bodies are
/// `ListView`s, which match unkeyed children by index: a slot that came and
/// went would shift everything below it, and each shift rebuilds those
/// subtrees from scratch (`docs/dashboard-panels.md` § An empty panel is
/// dropped from the list). So the gap rides inside this widget rather than
/// beside it, and "not shown" is a zero-size box in the same position.
///
/// [show] is the host's verdict from the panel preferences: the user has the
/// band switched on, the company offers invoices, and — when this device hides
/// empty panels — the band has something in it. One thing overrides a false
/// verdict: **a change that failed to save**. That line is not about invoices
/// and must not disappear with them.
class DashboardAttentionSlot extends StatelessWidget {
  const DashboardAttentionSlot({
    super.key,
    required this.vm,
    required this.formatter,
    required this.show,
    required this.compact,
    required this.rowLimit,
    required this.gap,
    required this.actions,
    required this.onInvoiceTap,
    required this.onQuoteTap,
    required this.onViewAll,
    this.failedSaves,
    this.onReviewFailedSaves,
  });

  final DashboardViewModel vm;
  final Formatter formatter;
  final bool show;
  final bool compact;
  final int rowLimit;
  final double gap;
  final AttentionActions actions;
  final void Function(DashboardInvoiceRow row) onInvoiceTap;
  final void Function(DashboardQuoteRow row) onQuoteTap;
  final void Function(AttentionTab tab) onViewAll;

  /// How many changes are waiting on the user after failing to save. Must be a
  /// stream the host built once — one made in `build` re-subscribes on every
  /// rebuild. Null draws no alert line.
  final Stream<int>? failedSaves;
  final VoidCallback? onReviewFailedSaves;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: failedSaves,
      builder: (context, snap) {
        final failed = snap.data ?? 0;
        if (!show && failed == 0) return const SizedBox.shrink();
        return sectionListenable(
          vm.attentionListenable,
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeedsAttentionBand(
                // Hidden by preference but held open by the alert: show the
                // alert over the quiet line, not rows the user switched off.
                attention: show
                    ? vm.attention(
                        companyCurrencyId: formatter.settings.currencyId,
                      )
                    : NeedsAttention.none,
                state: show ? vm.pastDue.listState : ListSectionState.empty,
                formatter: formatter,
                today: vm.today,
                compact: compact,
                rowLimit: rowLimit,
                actions: actions,
                onInvoiceTap: onInvoiceTap,
                onQuoteTap: onQuoteTap,
                onViewAll: onViewAll,
                onRetry: () => vm.retry(DashboardKind.pastDue),
                failedSaves: failed,
                onReviewFailedSaves: onReviewFailedSaves,
              ),
              SizedBox(height: gap),
            ],
          ),
        );
      },
    );
  }
}

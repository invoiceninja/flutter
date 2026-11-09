import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/payments/widgets/edit/open_amount.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_section.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/search_fold.dart';

/// Above this many invoices the checklist offers a filter field.
const int kInvoiceChecklistFilterThreshold = 6;

/// Pick several of the client's open invoices at once — a checklist with
/// each one's number, date and open amount, and Select All. React's create
/// screen has the same thing as a table; v1 had only the one-at-a-time row
/// pickers, which is all this app had too. Beta feedback: an agency billed
/// one invoice per end client, paying them in a batch, had to add each by
/// hand.
///
/// [selected] is what is allocated now; the result is the new selection, or
/// null when cancelled. [applyInvoiceSelection] turns it into allocations.
///
/// [existingAmounts] are the amounts already allocated, by invoice id, so the
/// total reflects what a kept row really applies. [paymentAmount] is the
/// amount the user fixed (zero while it still follows the allocations); when
/// set, the footer shows how much of it the ticked invoices leave unapplied —
/// the figure a user reconciling a bank deposit ticks towards.
Future<Set<String>?> showInvoiceChecklistDialog(
  BuildContext context, {
  required List<AllocationTarget> targets,
  required Set<String> selected,
  required Map<String, Decimal> existingAmounts,
  required Decimal paymentAmount,
  Decimal? otherAllocated,
  Formatter? formatter,
  String? currencyId,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (_) => InvoiceChecklistDialog(
      targets: targets,
      selected: selected,
      existingAmounts: existingAmounts,
      paymentAmount: paymentAmount,
      otherAllocated: otherAllocated ?? Decimal.zero,
      formatter: formatter,
      currencyId: currencyId,
    ),
  );
}

/// The allocations after the checklist returns [selected]:
///
/// - an invoice row whose target was unticked is removed — only rows for
///   [targets]; an allocation to an invoice the list doesn't offer (already
///   paid off, say, on an existing payment) is not the checklist's to drop;
/// - a kept row keeps its amount, and its place;
/// - each newly ticked invoice is appended in the order it was ticked
///   ([selected] is insertion-ordered), auto-filled the way a row picker
///   would fill it ([computeAutoFillAmount]) — in full while no amount is
///   fixed, else capped by what is left of [paymentAmount];
/// - an invoice that cap leaves nothing for is not added: the server refuses
///   a zero allocation on a sent invoice ("Amount cannot be less than or
///   equal to zero", `ValidInvoicesRules`), so the save would fail. The
///   dialog stops offering rows once the amount is used up, so this only
///   catches what it couldn't;
/// - credit rows are untouched.
List<Paymentable> applyInvoiceSelection({
  required List<Paymentable> paymentables,
  required List<AllocationTarget> targets,
  required Set<String> selected,
  required Decimal paymentAmount,
}) {
  final byId = {for (final t in targets) t.id: t};
  final next = [
    for (final p in paymentables)
      if (p.invoiceId.isEmpty ||
          !byId.containsKey(p.invoiceId) ||
          selected.contains(p.invoiceId))
        p,
  ];
  final present = {
    for (final p in next)
      if (p.invoiceId.isNotEmpty) p.invoiceId,
  };
  for (final id in selected) {
    final t = byId[id];
    if (t == null || present.contains(id)) continue;
    final allocated = next
        .where((p) => p.invoiceId.isNotEmpty)
        .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);
    final amount = computeAutoFillAmount(
      kind: AllocationKind.invoice,
      target: t,
      paymentAmount: paymentAmount,
      allocatedExcludingThisRow: allocated,
    );
    if (amount <= Decimal.zero) continue;
    next.add(
      Paymentable(invoiceId: id, amount: amount, refunded: Decimal.zero),
    );
  }
  return next;
}

class InvoiceChecklistDialog extends StatefulWidget {
  const InvoiceChecklistDialog({
    super.key,
    required this.targets,
    required this.selected,
    required this.existingAmounts,
    required this.paymentAmount,
    required this.otherAllocated,
    this.formatter,
    this.currencyId,
  });

  final List<AllocationTarget> targets;
  final Set<String> selected;
  final Map<String, Decimal> existingAmounts;
  final Decimal paymentAmount;

  /// What the payment already allocates to invoices this list doesn't offer
  /// (one paid off since, on an existing payment). Not the list's to change,
  /// but it uses up the amount received all the same — [applyInvoiceSelection]
  /// counts it — so the room left and Unapplied have to count it too, or the
  /// dialog would allow a tick that Apply then drops at zero.
  final Decimal otherAllocated;
  final Formatter? formatter;
  final String? currencyId;

  @override
  State<InvoiceChecklistDialog> createState() => _InvoiceChecklistDialogState();
}

class _InvoiceChecklistDialogState extends State<InvoiceChecklistDialog> {
  late final Set<String> _selected = {...widget.selected};
  final TextEditingController _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  String _number(BuildContext context, AllocationTarget t) =>
      t.number.isEmpty ? context.tr('pending') : '#${t.number}';

  String _date(AllocationTarget t) {
    final d = t.date;
    final f = widget.formatter;
    return d == null || f == null ? '' : f.date(d.toIso());
  }

  String _money(Decimal amount) =>
      formatOpenAmount(amount, widget.formatter, widget.currencyId);

  /// The rows the filter leaves — every word, in any field shown, the rule
  /// every list and picker search follows.
  List<AllocationTarget> _visible(BuildContext context) {
    final words = foldedSearchWords(_filter.text);
    if (words.isEmpty) return widget.targets;
    return [
      for (final t in widget.targets)
        if (containsEveryWord(
          foldSearchText(
            [
              _number(context, t),
              if (t.isDraft) context.tr('draft'),
              _date(t),
              openAmountSearchText(
                t.balance,
                widget.formatter,
                widget.currencyId,
              ),
            ].join(' '),
          ),
          words,
        ))
          t,
    ];
  }

  /// What the ticked invoices apply: a kept row's own amount, a new one's
  /// open amount (partial first, as the row picker fills it).
  Decimal get _total {
    var sum = Decimal.zero;
    for (final t in widget.targets) {
      if (!_selected.contains(t.id)) continue;
      sum += widget.existingAmounts[t.id] ?? t.preferredAmount;
    }
    return sum;
  }

  bool _closed = false;

  // Guarded: a fast double Enter or tap must not pop twice — the second pop
  // would close the payment screen under the dialog.
  void _apply() {
    if (_closed) return;
    _closed = true;
    Navigator.of(context).pop(_selected);
  }

  /// Whether another invoice can be ticked: always, while no amount is fixed;
  /// else only while some of it is still unapplied. A row ticked past that
  /// would be allocated nothing, which the server refuses.
  bool get _roomLeft =>
      widget.paymentAmount <= Decimal.zero ||
      widget.paymentAmount > _total + widget.otherAllocated;

  /// Select All: tick the visible rows — with a fixed amount, in list order
  /// and only while it lasts, so it fills the deposit rather than overshoot
  /// it — or, when every row is ticked or nothing more fits, untick them.
  void _toggleAll(List<AllocationTarget> visible, {required bool allTicked}) {
    final toAdd = <String>[];
    if (!allTicked) {
      final fixed = widget.paymentAmount;
      var total = _total + widget.otherAllocated;
      for (final t in visible) {
        if (_selected.contains(t.id)) continue;
        if (fixed > Decimal.zero && total >= fixed) break;
        toAdd.add(t.id);
        total += t.preferredAmount;
      }
    }
    setState(() {
      if (toAdd.isEmpty) {
        _selected.removeAll(visible.map((t) => t.id));
      } else {
        _selected.addAll(toAdd);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final visible = _visible(context);
    final ticked = visible.where((t) => _selected.contains(t.id)).length;
    final allState = ticked == 0
        ? false
        : ticked == visible.length
        ? true
        : null;
    final total = _total;
    final roomLeft = _roomLeft;
    final fixed = widget.paymentAmount;
    // Never below zero: Apply caps the last invoice at what is left, so the
    // payment is never over-applied — that invoice is part-paid instead.
    final used = total + widget.otherAllocated;
    final unapplied = fixed > used ? fixed - used : Decimal.zero;
    final showFilter = widget.targets.length > kInvoiceChecklistFilterThreshold;
    final muted = theme.textTheme.bodySmall?.copyWith(color: tokens.ink3);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      title: Semantics(
        header: true,
        headingLevel: 1,
        child: Text(context.tr('select_invoices')),
      ),
      // A phone gets the width back from the default 40 px side insets: the
      // invoice numbers this list exists to tell apart are long (an agency's
      // `RobWent-1238_2026-11-01`), and at 310 px they were cut to a prefix.
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 600 ? 16 : 40,
        vertical: 24,
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: math.min(520.0, screenWidth - (screenWidth < 600 ? 32 : 80)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showFilter)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
                child: TextField(
                  controller: _filter,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _apply(),
                  decoration: InputDecoration(
                    hintText: context.tr('filter'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                ),
              ),
            // Enter on a row applies, as it does on the autofocused Apply the
            // ↵ hint sits on: clicking a row takes focus from that button, and
            // Enter would otherwise toggle the row (Space still does). Scoped
            // to the rows, so Enter on a focused Cancel still cancels.
            Flexible(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): _apply,
                  const SingleActivator(LogicalKeyboardKey.numpadEnter): _apply,
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      tristate: true,
                      value: allState,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 12,
                        end: 24,
                      ),
                      title: Text(context.tr('select_all')),
                      // Covers the rows the filter shows ([_toggleAll]).
                      onChanged: visible.isEmpty
                          ? null
                          : (_) => _toggleAll(
                              visible,
                              allTicked: allState == true,
                            ),
                    ),
                    Divider(height: 1, color: tokens.border),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final t = visible[i];
                          final date = _date(t);
                          final title = [
                            _number(context, t),
                            if (t.isDraft) context.tr('draft'),
                          ].join('  ·  ');
                          return CheckboxListTile(
                            key: ValueKey('invoice_checklist_${t.id}'),
                            value: _selected.contains(t.id),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: 12,
                              end: 24,
                            ),
                            title: LtrText(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              keepRtlScript: true,
                            ),
                            subtitle: date.isEmpty
                                ? null
                                : LtrText(date, style: muted, maxLines: 1),
                            secondary: OpenAmountText(
                              amount: t.balance,
                              formatter: widget.formatter,
                              currencyId: widget.currencyId,
                            ),
                            // A ticked row can always be unticked; an unticked one
                            // only while the amount received has room (see
                            // [_roomLeft]).
                            enabled: _selected.contains(t.id) || roomLeft,
                            onChanged: (v) => setState(() {
                              if (v ?? false) {
                                _selected.add(t.id);
                              } else {
                                _selected.remove(t.id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: tokens.border),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SummaryLine(
                    label: context.tr('count_selected', {
                      'count': '${_selected.length}',
                    }),
                    value: '${context.tr('total')}  ${_money(total)}',
                    strong: true,
                  ),
                  if (fixed > Decimal.zero) ...[
                    const SizedBox(height: 4),
                    _SummaryLine(
                      label: context.tr('amount_received'),
                      value: _money(fixed),
                    ),
                    const SizedBox(height: 4),
                    _SummaryLine(
                      label: context.tr('unapplied'),
                      value: _money(unapplied),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(label: context.tr('apply'), onPressed: _apply),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: strong ? tokens.ink : tokens.ink2,
      fontWeight: strong ? FontWeight.w600 : null,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: InSpacing.sm),
        LtrText(value, style: style, maxLines: 1),
      ],
    );
  }
}

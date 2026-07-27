import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocation_card.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocation_edit_dialog.dart';
import 'package:admin/utils/formatting.dart';

/// Marker for which side of a payment a row allocates to. Mirrors the
/// `PaymentableEntity.entityType` switch in admin-portal.
enum AllocationKind { invoice, credit }

/// Lightweight target for the picker — works for both Invoice and Credit
/// since both share `id`, `number`, and a "outstanding balance" notion.
class AllocationTarget {
  const AllocationTarget({
    required this.id,
    required this.number,
    required this.balance,
    required this.partial,
  });

  final String id;

  /// User-visible number (`#1234`). Empty on draft invoices — the picker
  /// surfaces `pending` in that case.
  final String number;

  /// The "remaining" amount on this entity. For invoices this is
  /// `balanceOrAmount`; for credits, also `balanceOrAmount`.
  final Decimal balance;

  /// Only invoices use a non-zero partial. Pre-fills the allocation amount
  /// when the user opted into a partial payment on the invoice itself.
  /// Credits report `partial = 0`.
  final Decimal partial;

  /// Preferred starting amount when the user selects this target — matches
  /// admin-portal's `PaymentableEntity.fromInvoice` math.
  Decimal get preferredAmount => partial > Decimal.zero ? partial : balance;
}

/// One section of the allocations editor — either Invoices or Credits.
///
/// Owns the picker / row / placeholder UX for a single allocation kind.
/// Holds NO reference to the edit ViewModel — instead takes the current
/// paymentables snapshot + an onChanged callback, so a future Apply Payment
/// sub-flow can mount the same widget against a different draft.
class PaymentAllocationsSection extends StatelessWidget {
  const PaymentAllocationsSection({
    super.key,
    required this.kind,
    required this.paymentables,
    required this.clientId,
    required this.paymentAmount,
    required this.onChanged,
    this.formatter,
    this.currencyId,
    this.showClientFirstHint = true,
  });

  final AllocationKind kind;

  /// The FULL paymentables list (invoices + credits). The section filters
  /// down to its own kind and writes back a merged list via [onChanged].
  final List<Paymentable> paymentables;

  final String clientId;

  /// Current `draft.amount`. Drives the per-row auto-fill cap (no cap when
  /// zero — the user hasn't seeded a target amount).
  final Decimal paymentAmount;

  final ValueChanged<List<Paymentable>> onChanged;

  /// Optional active-company [Formatter]. When supplied, money values in
  /// the picker / card / dialog render via `formatter.money(...)`. When
  /// null, falls back to raw `Decimal.toString()` (tests and bootstrap).
  final Formatter? formatter;

  /// Currency the payment is denominated in (`draft.currencyId`). Passed as
  /// `clientCurrencyId` on every `money()` call below — the [Formatter] handed
  /// down here is company-scoped, so without it a JPY/EUR client's invoices
  /// rendered with the company's symbol, separators and precision.
  final String? currencyId;

  /// When false, the "Select a client first" placeholder is suppressed so
  /// only one section in the parent owns the hint (the Invoices section
  /// is the canonical owner — Credits hides itself).
  final bool showClientFirstHint;

  bool _belongsToThisKind(Paymentable p) => kind == AllocationKind.invoice
      ? p.invoiceId.isNotEmpty
      : p.creditId.isNotEmpty;

  String _idOf(Paymentable p) =>
      kind == AllocationKind.invoice ? p.invoiceId : p.creditId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final titleKey = kind == AllocationKind.invoice ? 'invoices' : 'credits';
    if (clientId.isEmpty) {
      if (!showClientFirstHint) return const SizedBox.shrink();
      return _Section(
        title: context.tr(titleKey),
        children: [
          Text(
            context.tr('select_a_client_first'),
            style: TextStyle(color: tokens.ink3),
          ),
        ],
      );
    }
    return _LiveSection(
      kind: kind,
      paymentables: paymentables,
      clientId: clientId,
      paymentAmount: paymentAmount,
      onChanged: onChanged,
      belongsToThisKind: _belongsToThisKind,
      idOfRow: _idOf,
      formatter: formatter,
      currencyId: currencyId,
    );
  }
}

class _LiveSection extends StatefulWidget {
  const _LiveSection({
    required this.kind,
    required this.paymentables,
    required this.clientId,
    required this.paymentAmount,
    required this.onChanged,
    required this.belongsToThisKind,
    required this.idOfRow,
    required this.formatter,
    required this.currencyId,
  });

  final AllocationKind kind;
  final List<Paymentable> paymentables;
  final String clientId;
  final Decimal paymentAmount;
  final ValueChanged<List<Paymentable>> onChanged;
  final bool Function(Paymentable) belongsToThisKind;
  final String Function(Paymentable) idOfRow;
  final Formatter? formatter;
  final String? currencyId;

  @override
  State<_LiveSection> createState() => _LiveSectionState();
}

class _LiveSectionState extends State<_LiveSection> {
  // Memoize the stream so StreamBuilder doesn't cancel + resubscribe on
  // every parent rebuild (which fires on every amount keystroke through
  // the VM's notifyListeners). Re-derived only when the client / kind
  // changes — the inputs the underlying watchForClient query depends on.
  Stream<List<AllocationTarget>>? _stream;
  String? _streamClientId;
  AllocationKind? _streamKind;

  Stream<List<AllocationTarget>> _resolveStream(BuildContext context) {
    if (_stream != null &&
        _streamClientId == widget.clientId &&
        _streamKind == widget.kind) {
      return _stream!;
    }
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    final next = widget.kind == AllocationKind.invoice
        ? services.invoices
              .watchForClient(companyId: companyId, clientId: widget.clientId)
              .map<List<AllocationTarget>>(_invoiceTargets)
        : services.credits
              .watchForClient(companyId: companyId, clientId: widget.clientId)
              .map<List<AllocationTarget>>(_creditTargets);
    _stream = next;
    _streamClientId = widget.clientId;
    _streamKind = widget.kind;
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final stream = _resolveStream(context);
    final paymentables = widget.paymentables;
    final kind = widget.kind;
    final paymentAmount = widget.paymentAmount;
    final onChanged = widget.onChanged;
    final belongsToThisKind = widget.belongsToThisKind;
    final idOfRow = widget.idOfRow;

    return StreamBuilder<List<AllocationTarget>>(
      stream: stream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <AllocationTarget>[];
        final rowsForKind = paymentables
            .where(belongsToThisKind)
            .toList(growable: false);
        // Credits hide entirely when the client has none AND no row is
        // already selected — matches admin-portal payment_edit.dart:627-630.
        if (kind == AllocationKind.credit &&
            all.isEmpty &&
            rowsForKind.isEmpty) {
          return const SizedBox.shrink();
        }
        final titleKey = kind == AllocationKind.invoice
            ? 'invoices'
            : 'credits';
        if (all.isEmpty && rowsForKind.isEmpty) {
          return _Section(
            title: context.tr(titleKey),
            children: [
              Text(
                kind == AllocationKind.invoice
                    ? context.tr('no_open_invoices')
                    : context.tr('no_open_credits'),
                style: TextStyle(color: context.inTheme.ink3),
              ),
            ],
          );
        }
        return _Section(
          title: context.tr(titleKey),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (Breakpoints.isWide(constraints)) {
                  return _WideEditor(
                    kind: kind,
                    paymentables: paymentables,
                    targets: all,
                    paymentAmount: paymentAmount,
                    onChanged: onChanged,
                    belongsToThisKind: belongsToThisKind,
                    idOfRow: idOfRow,
                    formatter: widget.formatter,
                    currencyId: widget.currencyId,
                  );
                }
                return _NarrowEditor(
                  kind: kind,
                  paymentables: paymentables,
                  targets: all,
                  paymentAmount: paymentAmount,
                  onChanged: onChanged,
                  belongsToThisKind: belongsToThisKind,
                  idOfRow: idOfRow,
                  formatter: widget.formatter,
                  currencyId: widget.currencyId,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

List<AllocationTarget> _invoiceTargets(List<Invoice> invoices) {
  return invoices
      .where(
        (i) =>
            !i.isDeleted &&
            !i.isDraft &&
            i.archivedAt == null &&
            i.balanceOrAmount > Decimal.zero,
      )
      .map(
        (i) => AllocationTarget(
          id: i.id,
          number: i.number,
          balance: i.balanceOrAmount,
          partial: i.partial,
        ),
      )
      .toList(growable: false);
}

List<AllocationTarget> _creditTargets(List<Credit> credits) {
  return credits
      .where((c) => c.isApplicableForPayment)
      .map(
        (c) => AllocationTarget(
          id: c.id,
          number: c.number,
          balance: c.balance,
          partial: Decimal.zero,
        ),
      )
      .toList(growable: false);
}

/// Compute the auto-fill amount for a new allocation when the user selects
/// a target. Mirrors admin-portal `payment_edit.dart:194-199, 662-670` —
/// preferred amount (partial when set, else balance), capped by the
/// remaining headroom **only when the user has typed a payment amount**.
/// Credits ignore the cap (`limit: 0` in old app = unbounded).
Decimal computeAutoFillAmount({
  required AllocationKind kind,
  required AllocationTarget target,
  required Decimal paymentAmount,
  required Decimal allocatedExcludingThisRow,
}) {
  final preferred = target.preferredAmount;
  if (kind == AllocationKind.credit) return preferred;
  if (paymentAmount == Decimal.zero) return preferred;
  final headroom = paymentAmount - allocatedExcludingThisRow;
  if (headroom <= Decimal.zero) return Decimal.zero;
  return preferred < headroom ? preferred : headroom;
}

/// Wide layout: one Row per existing allocation + a final placeholder row
/// (UI-only, never lives in `paymentables` until the user picks a target).
class _WideEditor extends StatelessWidget {
  const _WideEditor({
    required this.kind,
    required this.paymentables,
    required this.targets,
    required this.paymentAmount,
    required this.onChanged,
    required this.belongsToThisKind,
    required this.idOfRow,
    required this.formatter,
    required this.currencyId,
  });

  final AllocationKind kind;
  final List<Paymentable> paymentables;
  final List<AllocationTarget> targets;
  final Decimal paymentAmount;
  final ValueChanged<List<Paymentable>> onChanged;
  final bool Function(Paymentable) belongsToThisKind;
  final String Function(Paymentable) idOfRow;
  final Formatter? formatter;
  final String? currencyId;

  @override
  Widget build(BuildContext context) {
    final rowsForKind = paymentables.where(belongsToThisKind).toList();
    final widgets = <Widget>[];
    for (var i = 0; i < rowsForKind.length; i++) {
      widgets.add(
        _AllocationRow(
          key: ValueKey(
            'paymentable_${kind.name}_${i}_${idOfRow(rowsForKind[i])}',
          ),
          kind: kind,
          paymentables: paymentables,
          rowIndex: _indexOfRow(paymentables, rowsForKind[i]),
          targets: targets,
          paymentAmount: paymentAmount,
          onChanged: onChanged,
          belongsToThisKind: belongsToThisKind,
          idOfRow: idOfRow,
          formatter: formatter,
          currencyId: currencyId,
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }
    // Placeholder row — only shown when at least one target is still
    // pickable (the row excludes already-allocated ids). Renders with a
    // null `rowIndex` so it knows to APPEND on select rather than REPLACE.
    final selectedIds = rowsForKind.map(idOfRow).toSet();
    final pickableTargets = targets
        .where((t) => !selectedIds.contains(t.id))
        .toList(growable: false);
    if (pickableTargets.isNotEmpty) {
      widgets.add(
        _AllocationRow(
          key: ValueKey('paymentable_${kind.name}_placeholder'),
          kind: kind,
          paymentables: paymentables,
          rowIndex: null,
          targets: targets,
          paymentAmount: paymentAmount,
          onChanged: onChanged,
          belongsToThisKind: belongsToThisKind,
          idOfRow: idOfRow,
          formatter: formatter,
          currencyId: currencyId,
        ),
      );
    } else if (rowsForKind.isNotEmpty) {
      // All available targets are allocated — surface a muted hint so the
      // section doesn't look truncated (was vanishing silently before).
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            context.tr(
              kind == AllocationKind.invoice
                  ? 'all_open_invoices_added'
                  : 'all_open_credits_added',
            ),
            style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }
}

int _indexOfRow(List<Paymentable> all, Paymentable row) {
  for (var i = 0; i < all.length; i++) {
    if (identical(all[i], row)) return i;
  }
  return all.indexOf(row);
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    super.key,
    required this.kind,
    required this.paymentables,
    required this.rowIndex,
    required this.targets,
    required this.paymentAmount,
    required this.onChanged,
    required this.belongsToThisKind,
    required this.idOfRow,
    required this.formatter,
    required this.currencyId,
  });

  final AllocationKind kind;
  final List<Paymentable> paymentables;

  /// Null when this is the placeholder row (no existing paymentable yet).
  final int? rowIndex;

  final List<AllocationTarget> targets;
  final Decimal paymentAmount;
  final ValueChanged<List<Paymentable>> onChanged;
  final bool Function(Paymentable) belongsToThisKind;
  final String Function(Paymentable) idOfRow;
  final Formatter? formatter;
  final String? currencyId;

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = rowIndex == null;
    final current = isPlaceholder ? null : paymentables[rowIndex!];
    final currentId = current == null ? '' : idOfRow(current);
    final currentAmount = current?.amount ?? Decimal.zero;

    // Exclude ids already used by OTHER rows of this kind so the picker
    // never suggests a duplicate.
    final otherSelected = paymentables
        .where(belongsToThisKind)
        .where((p) => !identical(p, current))
        .map(idOfRow)
        .toSet();
    final pickable = targets
        .where((t) => !otherSelected.contains(t.id))
        .toList(growable: false);

    AllocationTarget? selected;
    for (final t in pickable) {
      if (t.id == currentId) {
        selected = t;
        break;
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SearchableDropdownField<AllocationTarget>(
            label: context.tr(
              kind == AllocationKind.invoice ? 'invoice' : 'credit',
            ),
            items: pickable,
            initialValue: selected,
            displayString: (t) {
              final number = t.number.isEmpty
                  ? context.tr('pending')
                  : '#${t.number}';
              final amount = formatter == null
                  ? t.balance.toString()
                  : formatter!.money(t.balance, clientCurrencyId: currencyId);
              return '$number · $amount';
            },
            idOf: (t) => t.id,
            onChanged: (target) =>
                _onTargetSelected(context, target, currentAmount),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: _AmountField(
            kind: kind,
            currentAmount: currentAmount,
            enabled: !isPlaceholder && currentId.isNotEmpty,
            onChanged: (decimal) => _updateAmount(decimal),
            useCommaAsDecimalPlace:
                formatter?.settings.useCommaAsDecimalPlace ?? false,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.tr('remove'),
          color: isPlaceholder || currentId.isEmpty
              ? Theme.of(context).disabledColor
              : null,
          onPressed: isPlaceholder || currentId.isEmpty ? null : _remove,
        ),
      ],
    );
  }

  void _onTargetSelected(
    BuildContext context,
    AllocationTarget? target,
    Decimal currentAmount,
  ) {
    if (target == null) {
      // Ignore the picker's clear affordance on existing rows — it would
      // silently drop the user's typed amount + invoice link. The canonical
      // remove affordance is the trailing X icon (`_remove`); the picker's
      // null callback is only meaningful on the placeholder row, which has
      // nothing to drop.
      return;
    }
    final excludingThisRow = paymentables
        .where(belongsToThisKind)
        .where((p) => !identical(p, _maybeCurrent()))
        .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount);
    final autoFill = computeAutoFillAmount(
      kind: kind,
      target: target,
      paymentAmount: paymentAmount,
      allocatedExcludingThisRow: excludingThisRow,
    );
    final newRow = Paymentable(
      invoiceId: kind == AllocationKind.invoice ? target.id : '',
      creditId: kind == AllocationKind.credit ? target.id : '',
      amount: autoFill,
      refunded: Decimal.zero,
    );
    if (rowIndex == null) {
      onChanged([...paymentables, newRow]);
    } else {
      final next = List<Paymentable>.from(paymentables);
      next[rowIndex!] = newRow;
      onChanged(next);
    }
  }

  Paymentable? _maybeCurrent() =>
      rowIndex == null ? null : paymentables[rowIndex!];

  void _updateAmount(Decimal decimal) {
    if (rowIndex == null) return;
    final next = List<Paymentable>.from(paymentables);
    next[rowIndex!] = paymentables[rowIndex!].copyWith(amount: decimal);
    onChanged(next);
  }

  void _remove() {
    if (rowIndex == null) return;
    final next = List<Paymentable>.from(paymentables)..removeAt(rowIndex!);
    onChanged(next);
  }
}

class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.kind,
    required this.currentAmount,
    required this.enabled,
    required this.onChanged,
    required this.useCommaAsDecimalPlace,
  });

  final AllocationKind kind;
  final Decimal currentAmount;
  final bool enabled;
  final ValueChanged<Decimal> onChanged;
  final bool useCommaAsDecimalPlace;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: decimalInputText(widget.currentAmount),
    );
  }

  @override
  void didUpdateWidget(covariant _AmountField old) {
    super.didUpdateWidget(old);
    // Re-seed only when the external value differs from what's typed AND
    // the field isn't focused — avoids the cursor jumping mid-keystroke.
    if (_focusNode.hasFocus) return;
    final typedDecimal =
        parseDecimal(
          _controller.text,
          useCommaAsDecimalPlace: widget.useCommaAsDecimalPlace,
        ) ??
        Decimal.zero;
    if (typedDecimal == widget.currentAmount) return;
    final external = decimalInputText(widget.currentAmount);
    _controller.value = TextEditingValue(
      text: external,
      selection: TextSelection.collapsed(offset: external.length),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = FormSaveScope.maybeOf(context);
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: context.tr(
          widget.kind == AllocationKind.invoice ? 'amount' : 'applied',
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      onChanged: (v) {
        widget.onChanged(
          parseDecimal(
                v,
                useCommaAsDecimalPlace: widget.useCommaAsDecimalPlace,
              ) ??
              Decimal.zero,
        );
      },
      onFieldSubmitted: (_) => scope?.trySubmit(),
    );
  }
}

/// Narrow-mode (mobile) layout: a stack of [PaymentAllocationCard]s, with
/// the placeholder row replaced by a single "Add" outlined button that
/// opens the picker dialog directly.
class _NarrowEditor extends StatelessWidget {
  const _NarrowEditor({
    required this.kind,
    required this.paymentables,
    required this.targets,
    required this.paymentAmount,
    required this.onChanged,
    required this.belongsToThisKind,
    required this.idOfRow,
    required this.formatter,
    required this.currencyId,
  });

  final AllocationKind kind;
  final List<Paymentable> paymentables;
  final List<AllocationTarget> targets;
  final Decimal paymentAmount;
  final ValueChanged<List<Paymentable>> onChanged;
  final bool Function(Paymentable) belongsToThisKind;
  final String Function(Paymentable) idOfRow;
  final Formatter? formatter;
  final String? currencyId;

  @override
  Widget build(BuildContext context) {
    final rowsForKind = paymentables.where(belongsToThisKind).toList();
    final selectedIds = rowsForKind.map(idOfRow).toSet();
    final pickable = targets
        .where((t) => !selectedIds.contains(t.id))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rowsForKind.length; i++)
          PaymentAllocationCard(
            key: ValueKey(
              'paymentable_card_${kind.name}_${i}_${idOfRow(rowsForKind[i])}',
            ),
            kind: kind,
            row: rowsForKind[i],
            targets: targets,
            formatter: formatter,
            currencyId: currencyId,
            onTap: () => _openEditor(
              context,
              rowsForKind[i],
              _indexOfRow(paymentables, rowsForKind[i]),
            ),
            onRemove: () => _remove(_indexOfRow(paymentables, rowsForKind[i])),
          ),
        if (pickable.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                icon: const Icon(Icons.add),
                label: Text(
                  context.tr(
                    kind == AllocationKind.invoice
                        ? 'add_invoice'
                        : 'add_credit',
                  ),
                ),
                onPressed: () => _openEditor(context, null, null),
              ),
            ),
          )
        else if (rowsForKind.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.tr(
                kind == AllocationKind.invoice
                    ? 'all_open_invoices_added'
                    : 'all_open_credits_added',
              ),
              style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    Paymentable? existing,
    int? rowIndex,
  ) async {
    final result = await showPaymentAllocationEditDialog(
      context,
      kind: kind,
      initial: existing,
      targets: targets,
      excludeIds: paymentables
          .where(belongsToThisKind)
          .where((p) => !identical(p, existing))
          .map(idOfRow)
          .toSet(),
      paymentAmount: paymentAmount,
      allocatedExcludingThisRow: paymentables
          .where(belongsToThisKind)
          .where((p) => !identical(p, existing))
          .fold<Decimal>(Decimal.zero, (sum, p) => sum + p.amount),
      formatter: formatter,
      currencyId: currencyId,
    );
    if (result == null) return;
    if (rowIndex == null) {
      onChanged([...paymentables, result]);
    } else {
      final next = List<Paymentable>.from(paymentables);
      next[rowIndex] = result;
      onChanged(next);
    }
  }

  void _remove(int rowIndex) {
    final next = List<Paymentable>.from(paymentables)..removeAt(rowIndex);
    onChanged(next);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

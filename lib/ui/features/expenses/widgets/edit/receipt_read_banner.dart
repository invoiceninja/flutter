import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/expenses/receipt_fill.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';

/// The New Expense strip that says a receipt is being read, what it filled,
/// or that it couldn't be read (`docs/receipt-ocr.md`). Lives in the edit
/// scaffold's top banner slot, full width in both layouts.
///
/// Never moves focus, scrolls, or opens the keyboard. Hidden on a phone
/// while the soft keyboard is up — a small screen can't spare the row.
class ReceiptReadBanner extends StatefulWidget {
  const ReceiptReadBanner({super.key, required this.vm});

  final ExpenseEditViewModel vm;

  @override
  State<ReceiptReadBanner> createState() => _ReceiptReadBannerState();
}

class _ReceiptReadBannerState extends State<ReceiptReadBanner>
    with WidgetsBindingObserver {
  /// The (read, state) last announced — each state of each read is spoken
  /// once, whether or not the strip is on screen to see.
  (int, ReceiptBannerState)? _announced;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.vm.addListener(_announceState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceState());
  }

  @override
  void didUpdateWidget(ReceiptReadBanner old) {
    super.didUpdateWidget(old);
    if (old.vm != widget.vm) {
      old.vm.removeListener(_announceState);
      widget.vm.addListener(_announceState);
    }
  }

  @override
  void dispose() {
    widget.vm.removeListener(_announceState);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The keyboard came or went: nothing this strip depends on through
  /// MediaQuery notices (see `keyboardUp` below), so rebuild by hand.
  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  /// Off the view model, not the build: a strip hidden behind the keyboard
  /// still tells a screen reader the read finished. No live region — that
  /// would speak the strip again on every rebuild.
  void _announceState() {
    if (!mounted) return;
    final vm = widget.vm;
    final state = vm.receiptBannerState;
    final key = (vm.receiptReadId, state);
    if (state == ReceiptBannerState.none || _announced == key) return;
    _announced = key;
    final message = switch (state) {
      ReceiptBannerState.reading => context.tr('reading_receipt'),
      ReceiptBannerState.filled => [
        context.tr('receipt_filled'),
        for (final v in _values(context, vm)) '${v.label} ${v.value}',
      ].join(', '),
      ReceiptBannerState.vendorOnly => _vendorOnlyTitle(context, vm),
      _ => context.tr('receipt_not_readable'),
    };
    final view = View.of(context);
    final direction = Directionality.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(view, message, direction);
    });
  }

  String _vendorOnlyTitle(BuildContext context, ExpenseEditViewModel vm) =>
      context.tr('on_receipt', {
        'name': vm.lastReceiptRead?.scan.vendorName ?? '',
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final vm = widget.vm;
        final state = vm.receiptBannerState;
        if (state == ReceiptBannerState.none) return const SizedBox.shrink();
        // The window's own inset: a Scaffold strips the keyboard from its
        // body's MediaQuery, and this strip sits in one.
        final keyboardUp = View.of(context).viewInsets.bottom > 0;
        if (keyboardUp && MediaQuery.sizeOf(context).shortestSide < 600) {
          return const SizedBox.shrink();
        }
        final tokens = context.inTheme;
        // A save in flight owns the form: nothing here may change it.
        final idle = !vm.isSaving;

        final String title;
        var values = const <_Value>[];
        final actions = <Widget>[];
        Widget hide() => TextButton(
          onPressed: idle ? vm.dismissReceiptBanner : null,
          child: Text(context.tr('hide')),
        );
        switch (state) {
          case ReceiptBannerState.reading:
            title = context.tr('reading_receipt');
            actions.add(
              TextButton(
                onPressed: vm.cancelReceiptRead,
                child: Text(context.tr('cancel')),
              ),
            );
          case ReceiptBannerState.filled:
          case ReceiptBannerState.vendorOnly:
            title = state == ReceiptBannerState.filled
                ? context.tr('receipt_filled')
                : _vendorOnlyTitle(context, vm);
            values = _values(context, vm);
            if (state == ReceiptBannerState.filled) {
              actions.add(
                TextButton(
                  onPressed: idle ? vm.undoReceiptRead : null,
                  child: Text(context.tr('undo')),
                ),
              );
            }
            actions.add(hide());
          case ReceiptBannerState.failed:
          case ReceiptBannerState.none:
            title = context.tr('receipt_not_readable');
            actions.add(hide());
        }
        final reading = state == ReceiptBannerState.reading;
        final valueStyle = TextStyle(color: tokens.ink2, fontSize: 13);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: tokens.accentSoft,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          padding: EdgeInsetsDirectional.fromSTEB(
            InSpacing.lg(context),
            InSpacing.sm,
            InSpacing.md(context),
            InSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                spacing: InSpacing.md(context),
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state == ReceiptBannerState.failed
                            ? Icons.info_outline
                            : Icons.document_scanner_outlined,
                        size: 18,
                        color: tokens.ink2,
                      ),
                      const SizedBox(width: InSpacing.sm),
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: tokens.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Wraps rather than overflows at a large text size.
                  Wrap(children: actions),
                ],
              ),
              if (values.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: 26,
                    bottom: InSpacing.xs,
                  ),
                  child: Wrap(
                    children: [
                      for (final (i, v) in values.indexed) ...[
                        if (i > 0) Text(' · ', style: valueStyle),
                        // An amount or a date reads left to right in every
                        // locale; a vendor's name is text like any other.
                        v.isText
                            ? Text(v.value, style: valueStyle)
                            : LtrText(v.value, style: valueStyle),
                      ],
                    ],
                  ),
                ),
              // The bar holds the place the values line takes once the read
              // lands, so the strip barely moves.
              if (reading)
                const Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: 26,
                    top: InSpacing.xs,
                    bottom: InSpacing.xs,
                  ),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Each field the newest read filled, in form order, as that read left it
  /// (not the live draft, which the user may have changed since) and
  /// through the company's [Formatter] — the month as a word, so a swapped
  /// day and month shows.
  List<_Value> _values(BuildContext context, ExpenseEditViewModel vm) {
    final filled = vm.receiptFilledFields;
    final d = vm.receiptFilledDraft;
    if (d == null) return const [];
    final services = context.read<Services>();
    final formatter = services.formatterIfReady(vm.companyId);
    final out = <_Value>[];
    if (filled.containsKey(ReceiptFillField.amount)) {
      final currencyId = d.currencyId.isEmpty ? null : d.currencyId;
      final amount =
          formatter?.money(d.amount, clientCurrencyId: currencyId) ??
          d.amount.toString();
      final code = currencyId == null
          ? null
          : services.statics.currencies[currencyId]?.code;
      out.add(
        _Value(
          context.tr('amount'),
          code == null || amount.contains(code) ? amount : '$amount $code',
        ),
      );
    }
    final date = d.date;
    if (filled.containsKey(ReceiptFillField.date) && date != null) {
      out.add(
        _Value(
          context.tr('date'),
          formatter?.dateWithMonthName(date.toIso()) ?? date.toIso(),
        ),
      );
    }
    if (filled.containsKey(ReceiptFillField.vendor)) {
      final read = vm.lastReceiptRead;
      final name = read?.vendorName ?? read?.scan.vendorName;
      if (name != null) {
        out.add(_Value(context.tr('vendor'), name, isText: true));
      }
    }
    return out;
  }
}

class _Value {
  const _Value(this.label, this.value, {this.isText = false});
  final String label;
  final String value;

  /// Free text (a vendor's name), laid out in the reading direction.
  final bool isText;
}

/// "From receipt" under a field a receipt read filled — or "From receipt —
/// please check", in the warning colour, for a guess. Read with the field's
/// own semantics, so a screen reader hears where the value came from.
class ReceiptFieldMarker extends StatelessWidget {
  const ReceiptFieldMarker({super.key, required this.confidence});

  final ReceiptConfidence confidence;

  /// The marker for [field] on [vm], or null when it has none.
  static Widget? of(ExpenseEditViewModel vm, ReceiptFillField field) {
    final c = vm.receiptMarker(field);
    return c == null ? null : ReceiptFieldMarker(confidence: c);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final check = confidence == ReceiptConfidence.check;
    final color = check ? tokens.warning : tokens.ink3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.document_scanner_outlined, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.tr(check ? 'from_receipt_check' : 'from_receipt'),
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Tells [vm] while the user is in [field] — a half-typed value isn't in the
/// draft yet, and a receipt read must not overwrite it under the caret
/// ([ExpenseEditViewModel.noteReceiptFieldFocus]). Takes no focus itself.
class ReceiptFieldFocus extends StatelessWidget {
  const ReceiptFieldFocus({
    super.key,
    required this.vm,
    required this.fields,
    required this.child,
  });

  final ExpenseEditViewModel vm;
  final List<ReceiptFillField> fields;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      for (final f in fields) {
        vm.noteReceiptFieldFocus(f, focused);
      }
    },
    child: child,
  );
}

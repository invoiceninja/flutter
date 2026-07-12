import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// Modal sheet with a search field + scrollable checkbox list. Returns
/// the selected ids on Apply, `null` on Cancel. Used by the match panel
/// for picking invoices on CREDIT-Create and expenses on DEBIT-Link
/// (the two genuinely multi-select cases — single-select pickers use
/// `SearchableDropdownField<T>` instead).
///
/// `currencyOf` + `amountOf`, when supplied, drive the running summary
/// line at the bottom ("N selected — total $X"). Pass them for any list
/// where the user wants to see a sum (invoice balances, expense
/// amounts); omit for lists where the running total isn't meaningful.
Future<List<String>?> showMultiPickSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) idOf,
  required String Function(T) displayString,
  String Function(T)? subtitleOf,
  Decimal Function(T)? amountOf,
  String Function(T)? currencyOf,
  String? summaryFormatter,
  Formatter? formatter,
  List<String> initialSelected = const <String>[],
  bool addSelectAllButton = false,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => _MultiPickSheet<T>(
      title: title,
      items: items,
      idOf: idOf,
      displayString: displayString,
      subtitleOf: subtitleOf,
      amountOf: amountOf,
      currencyOf: currencyOf,
      formatter: formatter,
      initialSelected: initialSelected.toSet(),
      addSelectAllButton: addSelectAllButton,
    ),
  );
}

class _MultiPickSheet<T> extends StatefulWidget {
  const _MultiPickSheet({
    required this.title,
    required this.items,
    required this.idOf,
    required this.displayString,
    required this.initialSelected,
    this.subtitleOf,
    this.amountOf,
    this.currencyOf,
    this.formatter,
    this.addSelectAllButton = false,
  });

  final String title;
  final List<T> items;
  final String Function(T) idOf;
  final String Function(T) displayString;
  final String Function(T)? subtitleOf;
  final Decimal Function(T)? amountOf;
  final String Function(T)? currencyOf;
  final Formatter? formatter;
  final Set<String> initialSelected;
  final bool addSelectAllButton;

  @override
  State<_MultiPickSheet<T>> createState() => _MultiPickSheetState<T>();
}

class _MultiPickSheetState<T> extends State<_MultiPickSheet<T>> {
  late Set<String> _selected;
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialSelected);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Iterable<T> get _visibleItems {
    if (_query.isEmpty) return widget.items;
    final needle = _query.toLowerCase();
    return widget.items.where((item) {
      final label = widget.displayString(item).toLowerCase();
      final subtitle = widget.subtitleOf?.call(item).toLowerCase() ?? '';
      return label.contains(needle) || subtitle.contains(needle);
    });
  }

  Decimal get _selectedTotal {
    if (widget.amountOf == null) return Decimal.zero;
    var total = Decimal.zero;
    for (final item in widget.items) {
      if (_selected.contains(widget.idOf(item))) {
        total += widget.amountOf!(item);
      }
    }
    return total;
  }

  String? get _selectedCurrency {
    if (widget.currencyOf == null) return null;
    for (final item in widget.items) {
      if (_selected.contains(widget.idOf(item))) {
        return widget.currencyOf!(item);
      }
    }
    return null;
  }

  /// Running-total label. Formats the summed amount through the central
  /// [Formatter] (using the selected rows' currency when one is supplied,
  /// else the company default). Falls back to the bare `CODE 0.00` shape
  /// while the formatter is still resolving / not provided.
  String get _selectedTotalText {
    final currencyId = _selectedCurrency;
    final formatted = widget.formatter?.money(
      _selectedTotal,
      currencyId: currencyId,
    );
    if (formatted != null && formatted.isNotEmpty) return formatted;
    return '${currencyId == null ? '' : '$currencyId '}'
        '${_selectedTotal.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final visible = _visibleItems.toList(growable: false);
    final canApply = _selected.isNotEmpty;
    final showSummary = widget.amountOf != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 4,
        bottom: viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: context.tr('search'),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            if (widget.addSelectAllButton) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.select_all, size: 16),
                  label: Text(
                    _allVisibleSelected(visible)
                        ? context.tr('select_none')
                        : context.tr('select_all'),
                  ),
                  onPressed: () => setState(() {
                    if (_allVisibleSelected(visible)) {
                      _selected.removeAll(visible.map(widget.idOf));
                    } else {
                      _selected.addAll(visible.map(widget.idOf));
                    }
                  }),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          context.tr('no_results'),
                          style: TextStyle(color: tokens.ink3),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      itemBuilder: (ctx, i) {
                        final item = visible[i];
                        final id = widget.idOf(item);
                        final selected = _selected.contains(id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: selected,
                          title: Text(widget.displayString(item)),
                          subtitle: widget.subtitleOf == null
                              ? null
                              : Text(
                                  widget.subtitleOf!(item),
                                  style: TextStyle(
                                    color: tokens.ink3,
                                    fontSize: 12,
                                  ),
                                ),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          }),
                        );
                      },
                    ),
            ),
            if (showSummary) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      context.tr('n_selected', {
                        'count': _selected.length.toString(),
                      }),
                      style: TextStyle(color: tokens.ink2),
                    ),
                    const Spacer(),
                    Text(
                      '${context.tr('total')}: $_selectedTotalText',
                      style: moneyTextStyle(
                        color: tokens.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('cancel')),
                ),
                const SizedBox(width: 12),
                PrimaryDialogAction(
                  label: context.tr('apply'),
                  enabled: canApply,
                  onPressed: () =>
                      Navigator.of(context).pop(_selected.toList()),
                  // Search + multi-select — no Enter hint.
                  autofocus: false,
                  showEnterHint: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _allVisibleSelected(List<T> visible) {
    if (visible.isEmpty) return false;
    return visible.every((item) => _selected.contains(widget.idOf(item)));
  }
}

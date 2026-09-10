import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';

/// Which segment of a chip the [SegmentMenu] is editing.
enum SegmentKind { comparator, value, field }

/// Self-contained dropdown for one segment of a comparable filter chip.
///
/// Deliberately does NOT touch the search text controller or the
/// `FilterSuggestionController` — every choice commits straight through
/// the key (`changeOp` / `addValue`), so picking a comparator or value
/// never dumps `<key>:<value>` text into the search field (the bug the
/// shared value-mode overlay had).
///
///  * [SegmentKind.comparator] — one row per `key.supportedOps`
///    (localized phrase / symbol), the current op check-marked. Tap →
///    `key.changeOp` (one VM write, value preserved).
///  * [SegmentKind.value], date key — relative presets + "Absolute
///    date →" (Material date picker). Commits the chosen value, keeping
///    the current operator.
///  * [SegmentKind.value], numeric/string key — a small autofocused
///    field prefilled with the current value; Enter commits. Edits the
///    value only — the comparator is changed via the comparator segment.
///  * [SegmentKind.field] — one row per [fieldChoices] (other comparable
///    keys of the same value type), the current key check-marked. Tap →
///    swap the chip onto the chosen field, carrying the operator + value
///    over in one VM write.
class SegmentMenu extends StatelessWidget {
  const SegmentMenu({
    required this.vm,
    required this.filterKey,
    required this.kind,
    required this.currentWire,
    required this.onClose,
    this.fieldChoices = const [],
    super.key,
  });

  final GenericListViewModel<dynamic> vm;
  final ComparableFilterKey filterKey;
  final SegmentKind kind;
  final String currentWire;
  final VoidCallback onClose;

  /// Other comparable keys of the same [FilterValueType] this chip can
  /// switch to (only consulted for [SegmentKind.field]). Includes the
  /// current key, rendered check-marked.
  final List<ComparableFilterKey> fieldChoices;

  static const double _maxWidth = 280;

  /// The date key behind this chip, when it is one — gives access to the
  /// `between` window slot (`date_range` / `due_date_range`).
  DateColumnFilterKey? get _dateKey => filterKey is DateColumnFilterKey
      ? filterKey as DateColumnFilterKey
      : null;

  bool get _isWindow => _dateKey != null && _dateKey!.isWindowWire(currentWire);

  /// Open the shared dual-calendar popover, seeded from the current
  /// window when this chip is already a between, and commit the result.
  Future<void> _openRangePopover(BuildContext context) async {
    final key = _dateKey!;
    final formatter = context.read<Services>().formatterIfReady(vm.companyId);
    final seed = _isWindow ? key.parseWindow(currentWire) : null;
    // Close BEFORE the await, not after. `pickDateRangeWindow` pushes a
    // `PopupRoute`, and while this menu is still showing its
    // `BackDismissibleOverlay` holds a `ChildBackButtonDispatcher` — which the
    // `Router` consults *before* it pops anything. So a back press meant for
    // the calendar would instead dismiss the menu underneath it and leave the
    // calendar open, burning a press on something the user cannot see.
    // `token_search_field._onSelectValue` states the same rule for its own
    // await, and the value below applies fine to an already-closed menu.
    onClose();
    final wire = await pickDateRangeWindow(
      context,
      column: key.serverKey,
      formatter: formatter,
      seed: seed,
    );
    if (wire != null) await key.addValue(vm, wire);
  }

  @override
  Widget build(BuildContext context) {
    // Field kind short-circuits ahead of `parseWire` / the op chain:
    // `parseWire` can't decode a window wire, and the field menu doesn't
    // need the parsed value/op anyway.
    if (kind == SegmentKind.field) {
      return _shell(context, _fieldList(context));
    }

    final (value, parsedOp) = filterKey.parseWire(currentWire);
    final op = _isWindow ? FilterOp.between : parsedOp;

    final Widget body;
    if (kind == SegmentKind.comparator) {
      body = _comparatorList(context, op);
    } else if (op == FilterOp.between && _dateKey != null) {
      body = _betweenValueList(context);
    } else if (filterKey.valueType == FilterValueType.date) {
      body = _dateValueList(context, op);
    } else {
      body = _ValueField(
        initial: value,
        onSubmit: (text) {
          final t = text.trim();
          if (t.isEmpty) {
            onClose();
            return;
          }
          filterKey.addValue(vm, filterKey.buildWire(t, op));
          onClose();
        },
      );
    }

    return _shell(context, body);
  }

  /// The shared popup chrome (Esc-to-close, Material elevation, rounded
  /// border, width/height cap) wrapping any segment [body].
  Widget _shell(BuildContext context, Widget body) {
    final tokens = context.inTheme;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(InRadii.r2),
        color: tokens.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _maxWidth,
            maxHeight: 360,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(InRadii.r2),
              border: Border.all(color: tokens.border),
            ),
            child: body,
          ),
        ),
      ),
    );
  }

  /// Field segment: list every same-type comparable key. Picking a new
  /// one carries the current operator + value across in a single VM
  /// write (op falls back to the target's default if unsupported).
  Widget _fieldList(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final target in fieldChoices)
          _MenuRow(
            autofocus: target.serverKey == filterKey.serverKey,
            selected: target.serverKey == filterKey.serverKey,
            label: target.displayLabel(context),
            onTap: () {
              if (target.serverKey == filterKey.serverKey) {
                onClose();
                return;
              }
              final (value, op) = filterKey.parseWire(currentWire);
              final newOp = target.supportedOps.contains(op)
                  ? op
                  : target.defaultOp;
              // Fire-and-forget then close synchronously — matches the
              // comparator path so `_closeSegment` nulls the (now stale)
              // chip before the swap's async notify rebuilds the overlay.
              vm.swapExtraFilter(
                fromServerKey: filterKey.serverKey,
                toServerKey: target.serverKey,
                wireValue: target.buildWire(value, newOp),
                alsoClearServerKey: target is DateColumnFilterKey
                    ? target.rangeServerKey
                    : null,
              );
              onClose();
            },
          ),
      ],
    );
  }

  Widget _comparatorList(BuildContext context, FilterOp current) {
    final ops = filterKey.supportedOps;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (var i = 0; i < ops.length; i++)
          _MenuRow(
            autofocus: ops[i] == current,
            selected: ops[i] == current,
            label: filterOpPhrase(context, ops[i], filterKey.valueType),
            onTap: () {
              // `between` has no single value to carry through `changeOp`
              // — it needs the dual-calendar window picker.
              if (ops[i] == FilterOp.between && _dateKey != null) {
                _openRangePopover(context);
                return;
              }
              filterKey.changeOp(vm, currentWire, ops[i]);
              onClose();
            },
          ),
      ],
    );
  }

  /// Value segment for a `between` chip: a single row that (re)opens the
  /// dual-calendar window picker, seeded with the current window.
  Widget _betweenValueList(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _MenuRow(
          autofocus: true,
          label: '${context.tr('date_range')}  →',
          onTap: () => _openRangePopover(context),
        ),
      ],
    );
  }

  Widget _dateValueList(BuildContext context, FilterOp op) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final (token, labelKey) in kRelativeDatePresets)
          _MenuRow(
            label: context.tr(labelKey),
            onTap: () {
              filterKey.addValue(vm, filterKey.buildWire(token, op));
              onClose();
            },
          ),
        Divider(height: 9, color: context.inTheme.border),
        _MenuRow(
          label: '${context.tr('absolute_date')}  →',
          onTap: () async {
            // Close BEFORE the await — see `_openRangePopover`. `showDatePicker`
            // is `useRootNavigator: true`, so its route is not even on this
            // navigator and a `ModalRoute.isCurrentOf` guard could not see it;
            // closing first is the only thing that works for both.
            onClose();
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(2000),
              lastDate: DateTime(now.year + 5),
            );
            if (picked != null) {
              final iso =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
                  '${picked.day.toString().padLeft(2, '0')}';
              await filterKey.addValue(vm, filterKey.buildWire(iso, op));
            }
          },
        ),
      ],
    );
  }
}

/// One tappable menu row — keyboard-activatable (Enter/Space when
/// focused), hover tint, optional leading ✓ for the current selection.
class _MenuRow extends StatefulWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool autofocus;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        autofocus: widget.autofocus,
        onTap: widget.onTap,
        child: Container(
          color: _hovered ? tokens.surfaceAlt : Colors.transparent,
          // ≥44 px row so the picker stays thumb-friendly on touch.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: widget.selected
                    ? Icon(Icons.check, size: 16, color: tokens.ink)
                    : null,
              ),
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numeric/string value editor — a single autofocused line, Enter
/// commits. Stays inside the popup; never writes to the search field.
class _ValueField extends StatefulWidget {
  const _ValueField({required this.initial, required this.onSubmit});

  final String initial;
  final ValueChanged<String> onSubmit;

  @override
  State<_ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<_ValueField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
        );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _c,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: widget.onSubmit,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          hintText: context.tr('change_value'),
        ),
      ),
    );
  }
}

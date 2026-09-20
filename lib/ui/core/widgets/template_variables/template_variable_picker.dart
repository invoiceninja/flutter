import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';

/// What the user chose in [showTemplateVariablePicker].
sealed class TemplateVariablePick {
  const TemplateVariablePick();
}

/// Use [token] — insert it, or put it in place of the chip that was tapped.
final class TemplateVariablePicked extends TemplateVariablePick {
  const TemplateVariablePicked(this.token);

  final String token;
}

/// Delete the chip that was tapped.
final class TemplateVariableRemoved extends TemplateVariablePick {
  const TemplateVariableRemoved();
}

/// Searchable, grouped list of the variables [scope] can use — the "change
/// the variable" surface behind every chip, and the "Insert variable" one
/// behind the fields' buttons (invoiceninja/flutter#139).
///
/// With [currentToken] it is a *change*: titled accordingly, the current
/// variable pinned first with a ✓ (tapping it just closes), a "Did you mean …"
/// row for a typo, and a Remove action in the header — no confirmation, since
/// the host offers an Undo toast. Without, it is an *insert*.
///
/// [forSubject] hides variables whose value is HTML (buttons, tables), which
/// have no business in a subject line. [values] shows each variable's value
/// for the document being emailed, and is searched as well as the label and
/// the token.
///
/// A centered dialog on a wide window, a bottom sheet on a narrow one — the
/// `openTaskFilters` recipe. Both are routes, so Android back closes them with
/// no overlay wrapper. Returns null when dismissed.
Future<TemplateVariablePick?> showTemplateVariablePicker(
  BuildContext context, {
  required TemplateVariableScope scope,
  String? currentToken,
  bool forSubject = false,
  Map<String, TemplateVariableValue> values = const {},
}) {
  final body = TemplateVariablePickerBody(
    scope: scope,
    currentToken: currentToken,
    forSubject: forSubject,
    values: values,
  );
  if (MediaQuery.sizeOf(context).width >= Breakpoints.wide) {
    return showDialog<TemplateVariablePick>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<TemplateVariablePick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      // Keyboard-aware both ways (`line_item_picker_sheet.dart`, flutter#86):
      // lift by the inset, and measure the cap against what the keyboard left.
      final insets = MediaQuery.viewInsetsOf(ctx).bottom;
      final maxHeight = (MediaQuery.sizeOf(ctx).height - insets) * 0.85;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: body,
        ),
      );
    },
  );
}

/// The picker's content, public so it can be pumped on its own in tests.
class TemplateVariablePickerBody extends StatefulWidget {
  const TemplateVariablePickerBody({
    super.key,
    required this.scope,
    this.currentToken,
    this.forSubject = false,
    this.values = const {},
  });

  final TemplateVariableScope scope;
  final String? currentToken;
  final bool forSubject;
  final Map<String, TemplateVariableValue> values;

  @override
  State<TemplateVariablePickerBody> createState() =>
      _TemplateVariablePickerBodyState();
}

class _TemplateVariablePickerBodyState
    extends State<TemplateVariablePickerBody> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pop([TemplateVariablePick? pick]) => Navigator.of(context).pop(pick);

  /// The value column, and part of the search haystack.
  ///
  /// Routed through [describeTemplateVariable] rather than reading
  /// `widget.values` directly, so a row shows exactly what the chip it opens
  /// from shows — notably a value that merely repeats its own label
  /// (`$view_button`) is suppressed in both places, instead of the chip
  /// hiding it and the picker printing it back.
  String? _valueText(String token) {
    final display = describeTemplateVariable(
      context,
      token,
      widget.scope,
      value: widget.values[token],
    );
    return switch (display?.value) {
      null => null,
      '' => '—',
      final value => value,
    };
  }

  List<TemplateVariable> _matching(TemplateVariableGroup group, String query) =>
      [
        for (final v in group.variables)
          if ((!widget.forSubject || v.subjectSafe) &&
              v.token != widget.currentToken &&
              _matches(v, query))
            v,
      ];

  /// Joins the searchable fields with a character the user cannot type, so a
  /// query can never match across the label/token/value boundary. Written as
  /// the escape, never as the byte: a raw NUL makes the whole file binary to
  /// `file`, to `grep`/`ripgrep` (every source-scanning lint silently stops
  /// covering it) and to git — see `test/lint/no_control_bytes_test.dart`.
  static const _fieldGap = '\u0000';

  bool _matches(TemplateVariable v, String query) {
    if (query.isEmpty) return true;
    final haystack = [
      templateVariableLabel(context, v),
      v.token,
      _valueText(v.token) ?? '',
    ].join(_fieldGap).toLowerCase();
    return haystack.contains(query);
  }

  /// Enter picks the first visible row only when the user has typed
  /// something — on an empty query it would silently insert whatever sorts
  /// first (the lesson of invoiceninja/flutter#34).
  void _submit(String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) return;
    for (final group in templateVariableGroups(widget.scope)) {
      final hits = _matching(group, query);
      if (hits.isNotEmpty) {
        _pop(TemplateVariablePicked(hits.first.token));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final theme = Theme.of(context);
    final current = widget.currentToken;
    final query = _search.text.trim().toLowerCase();

    final rows = <Widget>[];
    if (current != null && query.isEmpty) {
      final display = describeTemplateVariable(
        context,
        current,
        widget.scope,
        value: widget.values[current],
      );
      rows.add(
        _VariableRow(
          label: display?.label ?? current,
          token: current,
          value: _valueText(current),
          selected: true,
          onTap: _pop,
        ),
      );
      final lookup = lookupTemplateVariable(current, widget.scope);
      final doubtful =
          lookup == null ||
          !lookup.inScope ||
          widget.values[current] is TemplateVariableUnknown;
      final suggestion = doubtful
          ? closestTemplateVariable(current, widget.scope)
          : null;
      if (suggestion != null &&
          (!widget.forSubject || suggestion.subjectSafe)) {
        final label = templateVariableLabel(context, suggestion);
        rows
          ..add(
            _SectionHeader(text: context.tr('did_you_mean', {'value': label})),
          )
          ..add(
            _VariableRow(
              label: label,
              token: suggestion.token,
              value: _valueText(suggestion.token),
              onTap: () => _pop(TemplateVariablePicked(suggestion.token)),
            ),
          );
      }
    }
    for (final group in templateVariableGroups(widget.scope)) {
      final hits = _matching(group, query);
      if (hits.isEmpty) continue;
      rows.add(_SectionHeader(text: context.tr(group.labelKey)));
      for (final v in hits) {
        rows.add(
          _VariableRow(
            label: templateVariableLabel(context, v),
            token: v.token,
            value: _valueText(v.token),
            onTap: () => _pop(TemplateVariablePicked(v.token)),
          ),
        );
      }
    }
    if (rows.isEmpty) {
      rows.add(
        Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Text(
            context.tr('no_records_found'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: t.ink3),
          ),
        ),
      );
    }

    return SafeArea(
      // A short sheet never needs the top inset; the bottom one keeps the
      // last row out of the Android gesture strip.
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              InSpacing.lg(context),
              InSpacing.sm,
              InSpacing.sm,
              InSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(
                      current == null ? 'insert_variable' : 'change_variable',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (current != null)
                  TextButton(
                    onPressed: () => _pop(const TemplateVariableRemoved()),
                    child: Text(context.tr('remove')),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  tooltip: context.tr('close'),
                  onPressed: _pop,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
            child: TextField(
              controller: _search,
              // No keyboard on touch until asked for: the list is the point,
              // and a keyboard would cover half of it.
              autofocus: !Env.isTouchPrimary,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.tr('search'),
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(height: InSpacing.sm),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: InSpacing.sm),
              children: rows,
            ),
          ),
        ],
      ),
    );
  }
}

/// Letter-spaced section divider — `filter_suggestion_menu.dart`'s
/// `_SectionHeader`.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.lg(context),
        InSpacing.xs,
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: t.ink3,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One variable: friendly label over its mono token, the document's value (if
/// any) on the trailing edge. At least 44 px tall on touch.
class _VariableRow extends StatelessWidget {
  const _VariableRow({
    required this.label,
    required this.token,
    required this.onTap,
    this.value,
    this.selected = false,
  });

  final String label;
  final String token;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 40,
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              InSpacing.md(context),
              6,
              InSpacing.lg(context),
              6,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: selected
                      ? Icon(Icons.check, size: 16, color: t.accent)
                      : null,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.ink,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                      Text(
                        token,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kMonoFontFamily,
                          fontSize: 12,
                          color: t.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: InSpacing.sm),
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(color: t.ink2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

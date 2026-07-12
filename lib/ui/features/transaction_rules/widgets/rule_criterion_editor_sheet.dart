import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/transaction_rule.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

/// Modal sheet for editing one [RuleCriterion]. Returns the modified
/// criterion on save, or null on cancel.
Future<RuleCriterion?> showRuleCriterionSheet({
  required BuildContext context,
  required RuleCriterion initial,
  required bool isCredit,
}) {
  return showModalBottomSheet<RuleCriterion>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) =>
        _RuleCriterionSheet(initial: initial, isCredit: isCredit),
  );
}

class _RuleCriterionSheet extends StatefulWidget {
  const _RuleCriterionSheet({required this.initial, required this.isCredit});

  final RuleCriterion initial;
  final bool isCredit;

  @override
  State<_RuleCriterionSheet> createState() => _RuleCriterionSheetState();
}

class _RuleCriterionSheetState extends State<_RuleCriterionSheet> {
  late String _searchKey;
  late String _operator;
  late TextEditingController _value;
  // CREDIT rules carry the matched-entity placeholder ($invoice.* / $payment.* /
  // $client.*) in `value`, not `search_key` — the server's matchCredit()
  // switches on `value`. Mirrors React's RuleModal. Unused for DEBIT.
  late String _creditValueKey;

  static const _debitKeys = <String>[
    kRuleSearchKeyDescription,
    kRuleSearchKeyAmount,
    kRuleSearchKeyParticipant,
    kRuleSearchKeyParticipantName,
  ];

  static const _stringOperators = <String>[
    kRuleOperatorIs,
    kRuleOperatorContains,
    kRuleOperatorStartsWith,
    kRuleOperatorIsEmpty,
  ];

  // No `is_empty` here: the server's matchNumberOperator (ProcessBankRules)
  // only handles =,<,<=,>,>= and returns false for anything else, so a numeric
  // `is_empty` criterion silently never matches. Mirrors React's numberOperators.
  static const _numberOperators = <String>[
    kRuleOperatorEquals,
    kRuleOperatorLessThan,
    kRuleOperatorLessThanOrEqual,
    kRuleOperatorGreaterThan,
    kRuleOperatorGreaterThanOrEqual,
  ];

  @override
  void initState() {
    super.initState();
    // search_key is ALWAYS a bank-transaction field (description / amount /
    // participant / participant_name) for both DEBIT and CREDIT. For CREDIT the
    // matched entity field travels in `value` as a $invoice.* / $payment.* /
    // $client.* placeholder, so seed `_creditValueKey` from the initial value.
    _searchKey =
        widget.initial.searchKey.isNotEmpty &&
            _debitKeys.contains(widget.initial.searchKey)
        ? widget.initial.searchKey
        : _debitKeys.first;
    _creditValueKey = kRuleCreditSearchKeys.contains(widget.initial.value)
        ? widget.initial.value
        : kRuleCreditSearchKeys.first;
    final operators = _operatorsFor(_operatorKey);
    _operator =
        widget.initial.operator.isNotEmpty &&
            operators.contains(widget.initial.operator)
        ? widget.initial.operator
        : operators.first;
    // Free-text value is DEBIT-only; CREDIT uses the placeholder dropdown.
    _value = TextEditingController(
      text: widget.isCredit ? '' : widget.initial.value,
    );
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  List<String> _operatorsFor(String key) =>
      isNumericSearchKey(key) ? _numberOperators : _stringOperators;

  /// The key whose type (string vs numeric) drives the operator set. For
  /// CREDIT that's the matched placeholder (the server picks its comparator
  /// from `value`); for DEBIT it's the bank-transaction field in `search_key`.
  String get _operatorKey => widget.isCredit ? _creditValueKey : _searchKey;

  @override
  Widget build(BuildContext context) {
    final operators = _operatorsFor(_operatorKey);
    final hideValue = !widget.isCredit && _operator == kRuleOperatorIsEmpty;
    // Save is only meaningful when a value is present (or `is_empty` is
    // selected, which deliberately omits the value field). Without this
    // gate users can land a `description contains <empty>` criterion
    // that always matches every row.
    final canSave =
        _searchKey.isNotEmpty &&
        _operator.isNotEmpty &&
        (widget.isCredit
            ? _creditValueKey.isNotEmpty
            : hideValue || _value.text.trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('add_rule'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildSearchKeyField(context),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _operator,
            decoration: InputDecoration(labelText: context.tr('operator')),
            items: [
              for (final op in operators)
                DropdownMenuItem(value: op, child: Text(labelForOperator(op))),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _operator = v);
            },
          ),
          const SizedBox(height: 12),
          if (widget.isCredit)
            _buildCreditValueField(context)
          else if (!hideValue)
            TextField(
              controller: _value,
              decoration: InputDecoration(labelText: context.tr('value')),
              keyboardType: isNumericSearchKey(_searchKey)
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              autofocus: true,
              // Re-render so canSave flips as the user types.
              onChanged: (_) => setState(() {}),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
                child: Text(context.tr('cancel')),
              ),
              const SizedBox(width: 12),
              PrimaryDialogAction(
                label: context.tr('save'),
                enabled: canSave,
                onPressed: () => Navigator.of(context).pop(
                  RuleCriterion(
                    searchKey: _searchKey,
                    operator: _operator,
                    value: widget.isCredit
                        ? _creditValueKey
                        : hideValue
                        ? ''
                        : _value.text.trim(),
                  ),
                ),
                // Value field + dropdowns own focus — no Enter hint.
                autofocus: false,
                showEnterHint: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The `search_key` field — a bank-transaction field for BOTH debit and
  /// credit (description / amount / participant / participant_name). For
  /// debit the operator set follows this key; for credit the operator set
  /// follows the placeholder, so reconcile against [_operatorKey].
  Widget _buildSearchKeyField(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _searchKey,
      decoration: InputDecoration(labelText: context.tr('field')),
      items: [
        for (final k in _debitKeys)
          DropdownMenuItem(value: k, child: Text(labelForSearchKey(k))),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _searchKey = v;
          final next = _operatorsFor(_operatorKey);
          if (!next.contains(_operator)) _operator = next.first;
        });
      },
    );
  }

  /// CREDIT-only placeholder picker — the $invoice.* / $payment.* / $client.*
  /// field the bank transaction is matched against. Serialized into the wire
  /// `value`; the server's matchCredit() switches on it. 19 entries → use
  /// [SearchableDropdownField] per the "type-to-search past ~20 options" rule.
  Widget _buildCreditValueField(BuildContext context) {
    return SearchableDropdownField<String>(
      label: context.tr('value'),
      items: kRuleCreditSearchKeys,
      initialValue: _creditValueKey.isEmpty ? null : _creditValueKey,
      idOf: (k) => k,
      displayString: labelForSearchKey,
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _creditValueKey = v;
          // Operator type follows the placeholder for credit.
          final next = _operatorsFor(_operatorKey);
          if (!next.contains(_operator)) _operator = next.first;
        });
      },
    );
  }
}

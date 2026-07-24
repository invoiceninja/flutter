import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_list_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_filter_keys.dart';

/// Thin wrapper that wires [TokenSearchField] for the Recurring Expenses list.
///
/// Stateful + key-caching: `TagFilterKey` opens a Drift watch subscription in
/// its constructor, so the key list is rebuilt (and the old one disposed) only
/// when the custom-field label signature changes — never on every re-emit.
class RecurringExpenseTokenSearchField extends StatefulWidget {
  const RecurringExpenseTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final RecurringExpenseListViewModel vm;
  final bool wide;

  @override
  State<RecurringExpenseTokenSearchField> createState() =>
      _RecurringExpenseTokenSearchFieldState();
}

class _RecurringExpenseTokenSearchFieldState
    extends State<RecurringExpenseTokenSearchField> {
  Stream<Company?>? _companyStream;
  String? _streamCompanyId;

  List<FilterKey>? _keys;
  String? _signature;

  static String _sig(String companyId, Company? c) => c == null
      ? '$companyId#'
      : '$companyId#'
            '${[for (var i = 1; i <= 4; i++) c.customFieldLabel('expense$i')].join('|')}';

  void _disposeKeys() {
    for (final k in _keys ?? const <FilterKey>[]) {
      k.dispose();
    }
    _keys = null;
  }

  List<FilterKey> _keysFor(Services services, Company? company) {
    final signature = _sig(widget.vm.companyId, company);
    if (_keys != null && _signature == signature) return _keys!;
    _disposeKeys();
    _signature = signature;
    return _keys = buildRecurringExpenseFilterKeys(
      tags: services.tags,
      companyId: widget.vm.companyId,
      company: company,
    );
  }

  @override
  void dispose() {
    _disposeKeys();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    if (_companyStream == null || _streamCompanyId != widget.vm.companyId) {
      _streamCompanyId = widget.vm.companyId;
      _companyStream = services.company.watchCompany(widget.vm.companyId);
    }
    return StreamBuilder<Company?>(
      stream: _companyStream,
      builder: (context, companySnap) {
        return TokenSearchField(
          vm: widget.vm,
          filterKeys: _keysFor(services, companySnap.data),
          wide: widget.wide,
          hintKey: 'search_recurring_expenses_or_filter_hint',
        );
      },
    );
  }
}

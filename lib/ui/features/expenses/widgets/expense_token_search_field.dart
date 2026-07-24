import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/expenses/view_models/expense_list_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/expense_filter_keys.dart';

/// Thin wrapper that wires [TokenSearchField] for the expenses list.
///
/// Stateful so the filter keys (and the client-names watch stream) are
/// built once and reused: the category / project / vendor membership keys
/// open Drift watch subscriptions in their constructors, and rebuilding
/// the key list on every list rebuild leaked three live stream queries per
/// rebuild. The keys read client names through [_names] (a State field) so
/// they stay fresh on every stream emission without being rebuilt.
class ExpenseTokenSearchField extends StatefulWidget {
  const ExpenseTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ExpenseListViewModel vm;
  final bool wide;

  @override
  State<ExpenseTokenSearchField> createState() =>
      _ExpenseTokenSearchFieldState();
}

class _ExpenseTokenSearchFieldState extends State<ExpenseTokenSearchField> {
  Stream<Map<String, String>>? _namesStream;
  String? _streamCompanyId;
  Map<String, String> _names = const <String, String>{};

  List<FilterKey>? _keys;
  String? _keysCompanyId;

  void _disposeKeys() {
    for (final k in _keys ?? const <FilterKey>[]) {
      k.dispose();
    }
    _keys = null;
  }

  List<FilterKey> _keysFor(Services services) {
    if (_keys != null && _keysCompanyId == widget.vm.companyId) {
      return _keys!;
    }
    _disposeKeys();
    _keysCompanyId = widget.vm.companyId;
    return _keys = buildExpenseFilterKeys(
      clients: services.clients,
      categories: services.expenseCategories,
      projects: services.projects,
      vendors: services.vendors,
      tags: services.tags,
      companyId: widget.vm.companyId,
      // Reads through the State field, so the cached keys see the latest
      // names on every emission without being reconstructed.
      nameForClientId: (id) => _names[id],
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
    // Hoisted (not built inline in the StreamBuilder) so a parent rebuild
    // doesn't swap the subscription — the stable-stream rule from the
    // outbox-spinner bug class.
    if (_namesStream == null || _streamCompanyId != widget.vm.companyId) {
      _streamCompanyId = widget.vm.companyId;
      _namesStream = services.clients
          .watchActiveNames(companyId: widget.vm.companyId)
          .map(
            (rows) => {
              for (final r in rows)
                if (r.name.isNotEmpty) r.id: r.name,
            },
          );
    }
    return StreamBuilder<Map<String, String>>(
      stream: _namesStream,
      builder: (context, snap) {
        _names = snap.data ?? _names;
        return TokenSearchField(
          vm: widget.vm,
          filterKeys: _keysFor(services),
          wide: widget.wide,
          hintKey: 'search_expenses_or_filter_hint',
        );
      },
    );
  }
}

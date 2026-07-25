import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_list_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_filter_keys.dart';

/// Thin wrapper that wires [TokenSearchField] for the recurring invoices list.
///
/// Stateful + key-caching: `TagFilterKey` opens a Drift watch subscription in
/// its constructor, so the key list is rebuilt (and the old one disposed) only
/// when a shaping input changes — never on every stream re-emit.
class RecurringInvoiceTokenSearchField extends StatefulWidget {
  const RecurringInvoiceTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final RecurringInvoiceListViewModel vm;
  final bool wide;

  @override
  State<RecurringInvoiceTokenSearchField> createState() =>
      _RecurringInvoiceTokenSearchFieldState();
}

class _RecurringInvoiceTokenSearchFieldState
    extends State<RecurringInvoiceTokenSearchField> {
  Stream<Company?>? _companyStream;
  Stream<Map<String, String>>? _clientNameStream;
  String? _streamCompanyId;

  List<FilterKey>? _keys;
  String? _signature;

  void _ensureStreams(Services services) {
    if (_streamCompanyId == widget.vm.companyId && _companyStream != null) {
      return;
    }
    _streamCompanyId = widget.vm.companyId;
    _companyStream = services.company.watchCompany(widget.vm.companyId);
    _clientNameStream = services.clients
        .watchActiveNames(companyId: widget.vm.companyId)
        .map(
          (rows) => {
            for (final r in rows)
              if (r.name.isNotEmpty) r.id: r.name,
          },
        );
  }

  static String _sig(String companyId, Company? c, Map<String, String> names) {
    final labels = c == null
        ? ''
        : [
            for (var i = 1; i <= 4; i++) c.customFieldLabel('invoice$i'),
          ].join('|');
    final n = (names.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}=${e.value}')
        .join(',');
    return '$companyId#$labels#$n';
  }

  void _disposeKeys() {
    for (final k in _keys ?? const <FilterKey>[]) {
      k.dispose();
    }
    _keys = null;
  }

  List<FilterKey> _keysFor(
    Services services,
    Company? company,
    Map<String, String> names,
  ) {
    final signature = _sig(widget.vm.companyId, company, names);
    if (_keys != null && _signature == signature) return _keys!;
    _disposeKeys();
    _signature = signature;
    return _keys = buildRecurringInvoiceFilterKeys(
      clients: services.clients,
      tags: services.tags,
      companyId: widget.vm.companyId,
      company: company,
      nameForClientId: (id) => names[id],
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
    _ensureStreams(services);
    return StreamBuilder<Company?>(
      stream: _companyStream,
      builder: (context, companySnap) {
        return StreamBuilder<Map<String, String>>(
          stream: _clientNameStream,
          builder: (context, snap) {
            final names = snap.data ?? const <String, String>{};
            return TokenSearchField(
              vm: widget.vm,
              filterKeys: _keysFor(services, companySnap.data, names),
              wide: widget.wide,
              hintKey: 'search_recurring_invoices_or_filter_hint',
            );
          },
        );
      },
    );
  }
}

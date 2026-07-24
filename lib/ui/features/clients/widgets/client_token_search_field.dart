import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:admin/ui/features/clients/view_models/client_list_view_model.dart';

/// Thin wrapper that wires [TokenSearchField] for the clients list. Watches
/// the current `Company` (for custom-field labels) plus live group/user name
/// maps so the `group:` / `assigned:` chips render names, not raw ids.
///
/// Stateful + key-caching: `TagFilterKey` opens a Drift watch subscription in
/// its constructor, so the key list is rebuilt (and the old one disposed) only
/// when a shaping input actually changes — never on every stream re-emit.
class ClientTokenSearchField extends StatefulWidget {
  const ClientTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ClientListViewModel vm;
  final bool wide;

  @override
  State<ClientTokenSearchField> createState() => _ClientTokenSearchFieldState();
}

class _ClientTokenSearchFieldState extends State<ClientTokenSearchField> {
  Stream<Company?>? _companyStream;
  Stream<Map<String, String>>? _groupStream;
  Stream<Map<String, String>>? _userStream;
  String? _streamCompanyId;

  List<FilterKey>? _keys;
  String? _signature;

  void _ensureStreams(Services services) {
    if (_streamCompanyId == widget.vm.companyId && _companyStream != null) {
      return;
    }
    _streamCompanyId = widget.vm.companyId;
    _companyStream = services.company.watchCompany(widget.vm.companyId);
    _groupStream = services.groupSettings
        .watchAll(companyId: widget.vm.companyId)
        .map(
          (rows) => {
            for (final g in rows)
              if (g.name.isNotEmpty) g.id: g.name,
          },
        );
    _userStream = services.user
        .watchAllForPicker(companyId: widget.vm.companyId)
        .map(
          (rows) => {
            for (final u in rows)
              if (u.displayName.isNotEmpty) u.id: u.displayName,
          },
        );
  }

  /// Content signature of every input the keys close over. Group/user name
  /// maps arrive as fresh instances on each Drift emit, so compare by content
  /// (not identity) to keep the cache stable — and the TagFilterKey's
  /// subscription alive — across no-op re-emits.
  static String _sig(
    String companyId,
    Company? company,
    Map<String, String> groupNames,
    Map<String, String> userNames,
  ) {
    final labels = company == null
        ? ''
        : [
            for (var i = 1; i <= 4; i++) company.customFieldLabel('client$i'),
          ].join('|');
    String flatten(Map<String, String> m) =>
        (m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
            .map((e) => '${e.key}=${e.value}')
            .join(',');
    return '$companyId#$labels#${flatten(groupNames)}#${flatten(userNames)}';
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
    Map<String, String> groupNames,
    Map<String, String> userNames,
  ) {
    final signature = _sig(widget.vm.companyId, company, groupNames, userNames);
    if (_keys != null && _signature == signature) return _keys!;
    _disposeKeys();
    _signature = signature;
    return _keys = buildClientFilterKeys(
      company: company,
      statics: services.statics,
      groups: services.groupSettings,
      users: services.user,
      tags: services.tags,
      companyId: widget.vm.companyId,
      nameForGroupId: (id) => groupNames[id],
      nameForAssignedId: (id) => userNames[id],
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
          stream: _groupStream,
          builder: (context, groupSnap) {
            final groupNames = groupSnap.data ?? const <String, String>{};
            return StreamBuilder<Map<String, String>>(
              stream: _userStream,
              builder: (context, userSnap) {
                final userNames = userSnap.data ?? const <String, String>{};
                return TokenSearchField(
                  vm: widget.vm,
                  filterKeys: _keysFor(
                    services,
                    companySnap.data,
                    groupNames,
                    userNames,
                  ),
                  wide: widget.wide,
                  hintKey: 'search_clients_or_filter_hint',
                );
              },
            );
          },
        );
      },
    );
  }
}

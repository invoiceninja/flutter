import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';

/// `tag:foo` — multi-valued membership filter resolved through the tag cache
/// for [entityType] (`task` / `project`). `serverKey` is `tag_ids`
/// (`QueryFilters::tag_ids` — a CSV that returns entities matching **any** of
/// the ids via `whereHas('tags', whereIn)`; OR semantics, not AND). A names
/// cache (archived included) backs `displayValueFor` so chips show the tag
/// name rather than the raw id.
class TagFilterKey extends MembershipFilterKey {
  TagFilterKey({
    required this.tags,
    required this.companyId,
    required this.entityType,
  }) {
    _namesSub = tags
        .watchAll(
          companyId: companyId,
          entityType: entityType,
          includeArchived: true,
        )
        .listen((rows) {
          _names
            ..clear()
            ..addEntries(rows.map((t) => MapEntry(t.id, t.name)));
        });
  }

  final TagRepository tags;
  final String companyId;
  final String entityType;
  final Map<String, String> _names = <String, String>{};
  StreamSubscription<List<Tag>>? _namesSub;

  @override
  String get id => 'tag';

  @override
  bool get acceptsTypedValue => false;

  @override
  int? get idleSuggestionCap => 50;

  @override
  String get serverKey => 'tag_ids';

  @override
  bool get checkboxMultiSelect => true;

  @override
  String displayLabel(BuildContext context) => context.tr('tags');

  @override
  String displayValueFor(String rawValue) {
    final name = _names[rawValue];
    return (name != null && name.isNotEmpty) ? name : rawValue;
  }

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    return tags.watchAll(companyId: companyId, entityType: entityType).map((
      all,
    ) {
      final filtered = q.isEmpty
          ? all.take(idleSuggestionCap!)
          : all.where((t) => t.name.toLowerCase().contains(q));
      return [
        for (final t in filtered)
          FilterValueSuggestion(
            rawValue: t.id,
            displayLabel: t.name.isEmpty ? t.id : t.name,
          ),
      ];
    });
  }

  @override
  void dispose() {
    _namesSub?.cancel();
    _namesSub = null;
  }
}

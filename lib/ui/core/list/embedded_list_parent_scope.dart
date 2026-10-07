import 'package:flutter/widgets.dart';

import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';

/// Filters a record screen wants one of its embedded lists to show — the
/// client's past-due line asking the Invoices tab for exactly the invoices it
/// counted.
///
/// A mailbox rather than a callback because the screen has no handle on the
/// list: it sits under the tabs, may not be mounted yet (its tab has never
/// been opened), or may be mounted and offstage. The list collects what is
/// addressed to its entity type when it mounts and whenever this notifies,
/// and applies it through the same `applyDeepLinkIntent` a dashboard panel's
/// "View All" uses — so it arrives as real, removable filter chips.
class EmbeddedListIntents extends ChangeNotifier {
  final Map<EntityType, ListFilterIntent> _pending = {};

  /// Addresses [intent] to the embedded list of [type]. Replaces one that has
  /// not been collected yet.
  void send(EntityType type, ListFilterIntent intent) {
    _pending[type] = intent;
    notifyListeners();
  }

  /// Hands over the intent waiting for [type], once.
  ListFilterIntent? take(EntityType type) => _pending.remove(type);
}

/// What an embedded related-record list needs to know about the record it is
/// embedded in — placed by a record screen above its tabs, read once by
/// `EntityListScreenScaffold`'s embedded branch.
///
/// The eight list screens a client embeds take a `clientId` and nothing else,
/// so before this a list had no idea its parent was deleted (it offered New on
/// a record the server will not attach anything to) or not yet synced (New
/// then built a document pointing at a `tmp_` id). Threading two more
/// parameters through every list screen would have been sixteen edits to say
/// one thing; an inherited scope says it once.
///
/// Absent — a list that is not embedded, or a host that has not adopted this
/// — means "nothing to add", and the list behaves exactly as before.
class EmbeddedListParentScope extends InheritedWidget {
  const EmbeddedListParentScope({
    super.key,
    required this.parentId,
    this.readOnly = false,
    this.intents,
    required super.child,
  });

  /// See [EmbeddedListIntents]. Null for a host that never filters its lists.
  final EmbeddedListIntents? intents;

  /// The parent record's id. A `tmp_` id sends New through `requireSynced`.
  final String parentId;

  /// The parent cannot take new related records (it is soft-deleted). The
  /// list's New button and its `N` shortcut are withdrawn.
  final bool readOnly;

  static EmbeddedListParentScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EmbeddedListParentScope>();

  @override
  bool updateShouldNotify(EmbeddedListParentScope oldWidget) =>
      oldWidget.parentId != parentId ||
      oldWidget.readOnly != readOnly ||
      !identical(oldWidget.intents, intents);
}

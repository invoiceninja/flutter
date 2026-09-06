import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// A [SearchableDropdownField] that resolves its selection by **id** rather
/// than by scanning the list it happens to be showing.
///
/// Every entity picker in the app was written the same way: a `StreamBuilder`
/// over `repo.watchPage(loadedPages: 100)`, then a linear scan for the row
/// whose id matches the draft. That window is at most a few thousand rows and
/// is **not** the catalogue — so a document referencing a record outside it
/// renders a **blank field on a form that has a value**, with no error and
/// nothing to click. It also goes blank for a `tmp_` id the moment an
/// offline-created record round-trips, because the swap deletes the tmp row.
///
/// [watchById] fixes both: repositories route a `tmp_` id through `id_remap`
/// and re-subscribe when the alias lands (`BaseEntityRepository.watchByTempId`),
/// so the resolved entity survives the swap. The result is *sticky* — once an
/// entity is known it is never replaced by null — so a stream hiccup can't blank
/// a populated field either.
///
/// The list goes through [WatchBuilder], which already owns a stream across
/// parent rebuilds — that matters because the call sites this replaces built a
/// fresh `watchPage(...)` inside `build`, so a host form that notifies per
/// keystroke tore the subscription down and re-queried Drift on every
/// character. [itemsStream] must therefore return a **fresh** stream per call,
/// per that widget's contract.
///
/// It stays a leaf: no `Services`, no repository type. Callers supply the
/// projections, which is also what lets one widget serve entities whose streams
/// differ (`watchPage` vs `watchActive` vs a client-scoped variant).
class EntityPickerField<T extends Object> extends StatefulWidget {
  const EntityPickerField({
    super.key,
    required this.label,
    required this.selectedId,
    required this.itemsStream,
    required this.watchById,
    required this.displayString,
    required this.idOf,
    required this.onChanged,
    this.cacheKey,
    this.errorText,
    this.emptyHintKey,
    this.optionLeadingBuilder,
    this.footerBuilder,
  });

  /// Resolved (already-translated) field label.
  final String label;

  /// The id the host form holds. Empty means nothing is selected.
  final String selectedId;

  /// Builds the list to offer. Must return a **fresh** stream per call (every
  /// repo `watch*` does); [WatchBuilder] re-invokes it only when [cacheKey]
  /// changes, never per build.
  final Stream<List<T>> Function() itemsStream;

  /// Resolves one id to its entity, independently of [itemsStream]. Point this
  /// at `repo.watch(companyId:, id:)` so a `tmp_` id and a record outside the
  /// loaded window both resolve.
  final Stream<T?> Function(String id) watchById;

  final String Function(T) displayString;
  final String Function(T) idOf;
  final ValueChanged<T?> onChanged;

  /// Anything that invalidates [itemsStream] — the company id, and any scope
  /// the caller narrows by (a client-scoped project list, say). Records compare
  /// by value, so a tuple is the usual shape. Passed straight to
  /// [WatchBuilder.cacheKey].
  final Object? cacheKey;

  final String? errorText;
  final String? emptyHintKey;
  final Widget Function(BuildContext, T)? optionLeadingBuilder;
  final WidgetBuilder? footerBuilder;

  @override
  State<EntityPickerField<T>> createState() => _EntityPickerFieldState<T>();
}

class _EntityPickerFieldState<T extends Object>
    extends State<EntityPickerField<T>> {
  StreamSubscription<T?>? _selectedWatch;

  /// The entity [EntityPickerField.selectedId] names, resolved independently of
  /// the visible list. Sticky by design — see [_watchSelected].
  T? _resolved;

  @override
  void initState() {
    super.initState();
    _watchSelected();
  }

  @override
  void didUpdateWidget(EntityPickerField<T> old) {
    super.didUpdateWidget(old);
    // Re-arm on a cacheKey change too: a company switch changes which rows the
    // id even refers to. `_watchSelected` decides for itself whether the
    // previous answer is still usable.
    if (old.selectedId != widget.selectedId ||
        old.cacheKey != widget.cacheKey) {
      _watchSelected();
    }
  }

  @override
  void dispose() {
    _selectedWatch?.cancel();
    super.dispose();
  }

  /// Track the selected entity by id, independently of the query and of the
  /// visible page.
  ///
  /// Two rules, both learned from `ClientPickerField._watchSelected`:
  ///
  ///  * **Sticky.** A null emission is ignored, so a not-yet-loaded or
  ///    momentarily-missing row never blanks a field that already has a value.
  ///  * **Re-arm unconditionally**, including for a selection this widget just
  ///    committed. Returning early there leaves the subscription pointed at the
  ///    previous entity forever, and because these are table-grained Drift
  ///    watches the next write re-emits that old row and reverts the field.
  void _watchSelected() {
    _selectedWatch?.cancel();
    _selectedWatch = null;
    final id = widget.selectedId;
    final resolved = _resolved;
    // Drop the previous answer ONLY when it disagrees with the id about to be
    // watched. Clearing unconditionally looks safe and is not: this re-arms on
    // a `cacheKey` change too, and the project pickers' key carries the host
    // form's client id — while picking a client deliberately KEEPS the project
    // ("surprise-clearing is annoying", `expense_edit_identity_section.dart`).
    // So the id had not changed and the answer was still right, but blanking it
    // handed `SearchableDropdownField` a null `initialValue`, which clears its
    // own `_committed` and text: a blank Project field on a form that holds a
    // project. Same guard `ClientPickerField._watchSelected` uses.
    if (id.isEmpty || (resolved != null && widget.idOf(resolved) != id)) {
      _resolved = null;
    }
    if (id.isEmpty) return;
    _selectedWatch = widget.watchById(id).listen(
      (entity) {
        if (!mounted || entity == null) return;
        setState(() => _resolved = entity);
      },
      // Repo by-id watches forward errors (`watchByTempId` does so explicitly),
      // and an unhandled one here escapes to the zone — failing any enclosing
      // widget test and red-screening the app. Keep the last good answer: this
      // stream enhances the list, it is never the only source.
      onError: (Object _) {},
    );
  }

  /// [items] with the resolved selection spliced in when the window doesn't
  /// already contain it.
  ///
  /// Splicing rather than only passing it as `initialValue` matters twice.
  /// `SearchableDropdownField` renders a **disabled placeholder** for an empty
  /// `items` (it assumes statics still loading), so a resolved record would sit
  /// behind a greyed "Loading" field it can never escape. And an option the
  /// list doesn't contain can't be re-picked after the user opens the popover.
  /// Leading is right: `_idleOptions` hoists the committed row to index 0
  /// anyway, so this matches where it will end up.
  (List<T>, T?) _optionsWithSelection(List<T> items) {
    final id = widget.selectedId;
    if (id.isEmpty) return (items, null);
    for (final it in items) {
      if (widget.idOf(it) == id) return (items, it);
    }
    final resolved = _resolved;
    if (resolved == null) return (items, null);
    // Look the resolved record up by **its own** id, not by [id]. The watch was
    // keyed by [id] and, after an offline create round-trips, answers with the
    // REAL row while the form still holds the `tmp_` id — so the two differ
    // precisely in the case this widget exists to survive. Matching on [id]
    // alone missed the real row already sitting in [items] and spliced a second
    // copy in, giving the popover two identical rows, only the first ticked.
    final resolvedId = widget.idOf(resolved);
    // Only when the two disagree — i.e. after a tmp -> real swap. Otherwise the
    // loop above already proved this id absent, and re-scanning a 5,000-row
    // window on every build (the host rebuilds per keystroke) buys nothing.
    if (resolvedId != id) {
      for (final it in items) {
        if (widget.idOf(it) == resolvedId) return (items, it);
      }
    }
    return ([resolved, ...items], resolved);
  }

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<T>>(
      cacheKey: widget.cacheKey,
      create: widget.itemsStream,
      builder: (context, snapshot) {
        final (options, selected) = _optionsWithSelection(
          snapshot.data ?? const [],
        );
        return SearchableDropdownField<T>(
          label: widget.label,
          items: options,
          initialValue: selected,
          displayString: widget.displayString,
          idOf: widget.idOf,
          onChanged: widget.onChanged,
          errorText: widget.errorText,
          emptyHintKey: widget.emptyHintKey,
          optionLeadingBuilder: widget.optionLeadingBuilder,
          footerBuilder: widget.footerBuilder,
        );
      },
    );
  }
}

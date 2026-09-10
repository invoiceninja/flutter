import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _kFile = 'lib/ui/features/tasks/widgets/task_filter_bar.dart';

/// `TaskFilterBar`'s three pickers must stay on `EntityPickerField`, and must
/// keep reading the whole-table name accessors.
///
/// Structural, and it has to be. `EntityPickerField`'s own suite already proves
/// the mechanism — `entity_picker_field_test.dart` has "renders a selection that
/// is NOT in the loaded window" and "resolution is sticky" — so what is left to
/// protect is the *wiring*, and a widget test of this bar would need a
/// `noSuchMethod` `Services` stub with three fake repositories to assert
/// something a grep can see. Same trade `sidebar_menu_wiring_test.dart` makes.
///
/// Three regressions this catches, all of which compile, run and look fine:
///
/// 1. **The window scan.** `items.where((c) => c.id == filters.clientId)
///    .firstOrNull` resolves the selection out of whatever page is loaded, which
///    is verbatim the shape `EntityPickerField`'s class doc exists to kill.
///    Every stream here is active-only, so archiving the selected record dropped
///    it from `items`, `SearchableDropdownField.didUpdateWidget` blanked the
///    field **without firing `onChanged`**, and the list stayed filtered by an
///    invisible criterion — no ✕ either, since `canClear` reads the controller
///    text. Nothing re-syncs it: this bar is `TaskFiltersMixin`'s sole mutator.
/// 2. **`watchPage` for the option list.** A paged entity read here offered the
///    alphabetically-first rows of whatever page 1 of the login prefetch left in
///    Drift, and paid a full `jsonDecode` per row for the privilege. The Tasks
///    list's own filter (`ClientFilterKey.watchValueSuggestions`) reads
///    `watchActiveNames`; this must match it. `watchAllForPicker` is the same
///    thing for the roster, and its dartdoc names this exact picker.
/// 3. **A missing `emptyHintKey`.** The disabled placeholder falls back to
///    `'loading'`, so a company with no projects — an ordinary configuration
///    whose stream settles on `[]` for good — got a dead field promising
///    something that would never arrive.
///
/// The assignee picker deliberately passes **no** `emptyHintKey`: the roster
/// arrives bundled on `/refresh` and always holds at least the signed-in user,
/// so an empty list there really is a loading state. Hence two, not three.
///
/// Since invoiceninja/flutter#136 it also pins the *absence* of a second
/// responsive gate here — see the last test.
void main() {
  late final String src = File(_kFile).readAsStringSync();

  /// `//` tails stripped — the prose above and the file's own dartdoc name
  /// every token these rules match.
  late final String code = src
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  /// [code] with every run of whitespace removed, so an assertion about a
  /// method chain survives `dart format` wrapping it across lines.
  late final String dense = code.replaceAll(RegExp(r'\s+'), '');

  test('all three pickers resolve their selection by id', () {
    // The name is about `watchById`, so check `watchById` — counting
    // `EntityPickerField<` alone stays green for `watchById: (_) =>
    // const Stream.empty()`, or for one that re-scans `itemsStream`, which is
    // the exact window scan this widget replaced.
    expect(
      'watchById:'.allMatches(code).length,
      3,
      reason: 'each picker must resolve its selection independently',
    );
    expect(
      'selectedId:'.allMatches(code).length,
      3,
      reason: 'and each must be told which id to resolve',
    );
    for (final byId in const [
      'services.projects.watch(companyId:companyId,id:id)',
      'services.clients.watch(companyId:companyId,id:id)',
      'services.user.watch(companyId:companyId,id:id)',
    ]) {
      expect(
        dense.contains(byId),
        isTrue,
        reason:
            'Expected `$byId` — a `watchById` that reads the list stream back '
            'is the window scan wearing the right parameter name.',
      );
    }
    expect(
      'EntityPickerField<'.allMatches(code).length,
      3,
      reason:
          'Project, Client and Assigned User must each be an EntityPickerField, '
          'which resolves the selection through `watchById` instead of scanning '
          'the loaded window.',
    );
    expect(
      code.contains('SearchableDropdownField'),
      isFalse,
      reason:
          'A raw SearchableDropdownField here means the selection is being '
          'resolved by scanning `items` again — archive the selected record and '
          'the field blanks while the list stays filtered.',
    );
  });

  test('the option lists are whole-table name queries', () {
    // Matched against the whitespace-stripped source: `dart format` wraps a
    // long chain, so the receiver and the call are not adjacent in the file.
    for (final accessor in const [
      'projects.watchActiveNames',
      'clients.watchActiveNames',
      'user.watchAllForPicker',
    ]) {
      expect(
        dense.contains(accessor),
        isTrue,
        reason:
            'Expected `$accessor` — a filter offers the whole local set, not a '
            'page. See ClientFilterKey.watchValueSuggestions.',
      );
    }
    expect(
      code.contains('watchPage('),
      isFalse,
      reason:
          'watchPage is a paged entity read: it offers only what page 1 of the '
          'login prefetch left in Drift, and decodes every row to do it.',
    );
  });

  /// Every picker must fall back to the record id for a nameless row. Nothing
  /// upstream supplies it for projects — `projects.name` is `withDefault('')`,
  /// the DAO emits the column raw, and `ProjectRepository.watchActiveNames` is
  /// a passthrough where its Client and Vendor twins both fall back — and the
  /// DAO orders by `name.lower()`, so a blank sorts to the TOP of the list.
  /// For clients it matters for a second reason: `BaseEntityDao.watchById` has
  /// no archived/deleted predicate, so an archived selection stays resolvable
  /// and gets spliced back in, where a blank name reads as an empty field over
  /// an active filter — the defect this widget exists to remove.
  test('no picker can render a nameless record as blank', () {
    // `.trim()`, matching the repository-level fallbacks
    // (`r.name.trim().isEmpty ? r.id : r.name`) — a whitespace-only name is
    // just as blank on screen, and a bare `.isEmpty` misses it. Matched
    // against `dense` so `dart format` may wrap these however it likes.
    for (final fallback in const [
      'p.name.trim().isEmpty?p.id:p.name',
      'c.name.trim().isEmpty?c.id:c.name',
      'u.displayName.trim().isEmpty?u.id:u.displayName',
    ]) {
      expect(
        dense.contains(fallback),
        isTrue,
        reason:
            'Expected `$fallback`. CLAUDE.md: a picker falls back to the '
            'record id, because a repeated "(no name)" cannot tell two '
            'nameless rows apart in a list you must pick from.',
      );
    }
  });

  /// `watchAllForPicker` is the whole-roster accessor, but `UserDao
  /// .watchAllForCompany` is a bare `select(users)..where(companyId)` — no
  /// `orderBy`, no state filter — where the `watchPage` it replaced defaulted to
  /// `sortField: 'first_name'` and `states: {active}`. Both have to be restored
  /// at this call site, exactly as `activity_filter_sheet.dart` sorts at its own.
  test('the roster is filtered to active and sorted', () {
    expect(
      dense.contains('u.archivedAt==0&&!u.isDeleted'),
      isTrue,
      reason:
          'watchAllForPicker returns archived and soft-deleted users too. '
          '`archivedAt` is an int epoch (0 = not archived), never null — an '
          '`== null` test is dead code and filters the roster to nothing.',
    );
    expect(
      dense.contains('a.displayName.toLowerCase().compareTo('),
      isTrue,
      reason:
          'watchAllForPicker applies no ORDER BY, so without this the dropdown '
          'is in rowid order where it used to be alphabetical.',
    );
  });

  test('the two pickers that can legitimately be empty say so', () {
    expect(
      "emptyHintKey: 'no_records_found'".allMatches(code).length,
      2,
      reason:
          'Project and Client must both pass it — their streams settle on `[]` '
          'for a company that has none, and the placeholder otherwise reads '
          '"Loading" for ever. The assignee picker deliberately does not.',
    );
  });

  /// The wide/narrow decision arrives as a parameter now, and this file must
  /// not take a second one.
  ///
  /// It used to be a `LayoutBuilder` *inside* the bar's own
  /// `Container(padding: horizontal: 24)`, which means it really tested
  /// `pane - 48 >= 600`. Two consequences, both silent. The AppBar cannot be
  /// reached from the body — `Scaffold.appBar` is built outside it — so the
  /// filter action has to be gated by the host screen; and if this file keeps
  /// its own gate as well, a 600-648 px pane renders the stacked pickers *and*
  /// suppresses the AppBar icon, which is the exact layout #136 removed. The
  /// threshold moved into `taskFiltersInline`, where the gutters are subtracted
  /// once and a table test can see it.
  test('the bar takes the responsive gate rather than deciding it', () {
    expect(
      code.contains('LayoutBuilder'),
      isFalse,
      reason:
          'a second gate here disagrees with the one the host screen passes to '
          'the AppBar — see `taskFiltersInline`.',
    );
    expect(
      code.contains('Breakpoints.isWide('),
      isFalse,
      reason:
          'the bar no longer answers the width question; `taskFiltersInline` '
          'does, from the pane width minus this file\'s own gutters.',
    );
    expect(
      code.contains('required this.inline'),
      isTrue,
      reason:
          'defaulting `inline` turns a missed call site into silent double '
          'chrome (the inline row AND the AppBar icon) or none at all, instead '
          'of a compile error.',
    );
  });
}

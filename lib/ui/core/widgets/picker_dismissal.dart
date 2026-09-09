import 'package:flutter/widgets.dart';

/// The `onTapOutside` every `RawAutocomplete` field in this app must set.
///
/// Companion to `EscapeObserver` (`escape_observer.dart`): that one exists
/// because `DismissIntent` hides the options overlay without telling anyone,
/// this one because on a phone **nothing hides it at all**.
///
/// Three SDK facts conspire (verified against Flutter 3.44.1):
///
///  1. `RawAutocomplete._canShowOptionsView` is `hasFocus && options.isNotEmpty`
///     (`widgets/autocomplete.dart`), so the overlay closes on exactly three
///     things — a `_select`, a `DismissIntent` (Escape, i.e. a hardware
///     keyboard), or **focus loss**.
///  2. `_EditableTextTapOutsideAction` (`widgets/editable_text.dart`)
///     deliberately does *not* unfocus for a `PointerDeviceKind.touch` event on
///     android / iOS / fuchsia unless `kIsWeb` — a soft keyboard must not close
///     on a stray tap. Desktop and mobile web always unfocus.
///  3. An option list with anything in it therefore has no way out.
///     `SearchableDropdownField._optionsFor` never returns empty (it falls back
///     to the idle list for a pristine or empty query, and an empty `items`
///     takes the disabled-placeholder branch instead), and the line-item tax
///     cell always prepends a "none" row. The create-bearing pickers *can* go
///     empty — `TagPickerField._canCreate` is false for an empty query, and
///     `_ProductCell` appends its create row only for a non-empty one — and
///     that does unmount the overlay. But it is not a dismissal a user can aim
///     for, so it rescues nobody.
///
/// Net: on native touch a picker's popover had **no dismissal path** — it stayed
/// up until the user picked something or left the screen (invoiceninja/flutter#130,
/// reported against Activity's User filter but true of every picker in the app).
///
/// This is safe **because** `RawAutocomplete` wraps both the field and the
/// options overlay in `TextFieldTapRegion` — the same default
/// `groupId: EditableText` — and a tap-region group acts as one region, so a tap
/// on an option row, on the popover's footer, or on a selection handle counts as
/// *inside* and never fires this. The proof isn't the source, it's the product:
/// on desktop a mouse-down outside already unfocuses today, so if the overlay
/// sat outside the group, clicking an option on desktop could never work. It
/// does, so it doesn't. `TapRegion` is also route-aware — it nulls
/// `onTapOutside` while `ModalRoute.isCurrentOf` is false — so a picker behind an
/// open dialog (`ClientPickerField` mid-create) is left alone.
///
/// Off native touch this reproduces `_EditableTextTapOutsideAction` exactly, so
/// desktop and mobile web are unchanged.
///
/// **The scope is "the field has focus", not "a popover is open" — deliberately.**
/// `EditableText` wires `onTapOutside` under `_hasFocus ? … : null`, and
/// `RawAutocomplete._select` hides the overlay *without* unfocusing, so
/// "focused, popover closed, keyboard up" is a common state (it is where you
/// land right after picking). On native touch these fields therefore now drop
/// the keyboard on the first pointer-**down** of any outside gesture — a scroll
/// started right after a pick included, which reflows the page under the
/// finger. Every ordinary `TextField` in the app keeps focus there. Kept anyway:
/// it is what desktop already does, and a keyboard left up over a form the user
/// has finished with is its own annoyance. Narrowing it was considered and
/// rejected — it needs a visibility predicate threaded in here, a visibility
/// flag added to `TagPickerField` and `_TaxCell` (neither has one), and a
/// re-implementation of the SDK's platform matrix, since a naive gate would
/// stop *desktop* unfocusing when nothing is open.
///
/// `test/lint/picker_popover_wiring_test.dart` fails the build on a
/// `RawAutocomplete` that doesn't set it. Note that the tap-region-group
/// argument above is pinned by the **SDK source**, not by any test of ours: a
/// widget test cannot see it, because removing the overlay takes a frame and
/// `tester.tap` pumps none between pointer-down and pointer-up — so even an
/// unfocus that fired on an option tap would leave the row mounted long enough
/// to complete. Verified by experiment, not assumed.
TapRegionCallback dismissPickerOnTapOutside(FocusNode focusNode) =>
    (_) => focusNode.unfocus();

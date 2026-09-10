import 'package:flutter/widgets.dart';

/// The `onTapOutside` every `RawAutocomplete` field in this app must set.
///
/// Companion to `EscapeObserver` (`escape_observer.dart`): that one exists
/// because `DismissIntent` hides the options overlay without telling anyone,
/// this one because on a phone **nothing hides it at all**. See also
/// [BackDismissiblePickerOverlay] below — the same story for Android's back
/// gesture, which the SDK handles even less than it handles a touch tap.
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

/// Closes a non-route overlay on Android's **back**, instead of letting the
/// press navigate away from — or out of — the screen underneath it.
///
/// The mechanism behind [BackDismissiblePickerOverlay] and the search field's
/// two `OverlayPortal` menus, and a sibling to
/// `back_dismissible_menu_anchor.dart`, which does the same job for
/// `MenuAnchor`. All three exist because an overlay that is **not a route** gets
/// no back handling from Flutter: back falls through to `SystemBackGate`, which
/// runs `NavHistoryController.back()` and leaves the screen — **or exits the
/// app**, since that gate calls `SystemNavigator.pop()` when `canGoBack` is
/// false and the app restores exactly where the user left off, so a session
/// relaunched onto the screen in question has no history behind it.
///
/// **A `PopScope` cannot do this.** `ModalRoute.onPopInvokedWithResult` notifies
/// *every* registered `PopEntry`, so a `canPop: false` entry here would stop
/// nothing — `SystemBackGate`'s entry resolves to the same route and its handler
/// would still navigate. The fix has to sit **above** route popping, and that is
/// a `ChildBackButtonDispatcher`: `RootBackButtonDispatcher.invokeCallback`
/// walks its children newest-first and stops on the first that returns true,
/// only falling through to `RouterDelegate.popRoute` when none did.
///
/// **Mount it inside the overlay's own subtree, never around the anchor.** That
/// is what makes "is it open?" free — the subtree exists only while the overlay
/// is showing, so *mounted == open* by construction and no host needs a
/// visibility flag. It also dodges both objections to Flutter's
/// `BackButtonListener` that `BackDismissibleMenuAnchor` documents: a subtree
/// that exists only while open puts no dispatcher-per-list-row in the parent's
/// child list and changes no tree depth around the anchor. (That widget is
/// unusable here anyway — it asserts on `Router.of` and then bangs, and the
/// picker suites pump bare `MaterialApp`s with no `Router` throughout.)
///
/// **[onBack] must actually dismiss the thing.** Returning `true` tells the
/// `Router` the press is handled, so a callback that dismisses nothing produces
/// "back is dead" — strictly worse than the bug this fixes. Use [canDismiss]
/// where the host has a real visibility flag and the mount window is wider than
/// the open window; leave it null where mount lifetime is the whole predicate.
///
/// **A row that pushes a route must dismiss BEFORE it awaits it.** This is the
/// sharp edge, and it is the flip side of the whole design: the `Router`
/// consults child dispatchers *before* it pops anything, so while this is
/// mounted it out-ranks **every** modal route — including one pushed on top of
/// the overlay. A menu row that opens a date picker and awaits it would
/// otherwise hand the user's back press to the menu *underneath* the calendar,
/// closing something invisible and leaving the calendar up. `segment_menu.dart`
/// and `FilterSuggestionMenu.onDismiss` both close first for exactly this
/// reason, and `token_search_field._onSelectValue` had already written the rule
/// down for its own await.
///
/// A `ModalRoute.isCurrentOf` guard — the trick `TapRegion` uses, cited below —
/// is **not** a substitute: it catches a route pushed on the nearest navigator
/// but not `showDatePicker`, which is `useRootNavigator: true`. Nor can this
/// widget take that dependency, because `_claim` runs inside a layout callback
/// and its safety rests on `_RouterScope` being the only inherited widget it
/// depends on.
///
/// Android only in practice: iOS has no system back, desktop has Escape, and on
/// web the browser's back arrives through the route-information provider rather
/// than `didPopRoute`, so no child dispatcher is consulted.
class BackDismissibleOverlay extends StatefulWidget {
  const BackDismissibleOverlay({
    super.key,
    required this.onBack,
    this.canDismiss,
    required this.child,
  });

  /// Dismisses the overlay. Runs only while this subtree is mounted and
  /// [canDismiss] (if given) agrees.
  final VoidCallback onBack;

  /// Optional guard. Return false to decline the press and let it fall through
  /// to the next child dispatcher and then the `Router` — so the worst case is
  /// "back behaves normally", never "back is dead".
  final bool Function()? canDismiss;

  /// The overlay content, returned unchanged. This widget builds no
  /// `RenderObject`, so it is invisible to layout.
  final Widget child;

  @override
  State<BackDismissibleOverlay> createState() => _BackDismissibleOverlayState();
}

class _BackDismissibleOverlayState extends State<BackDismissibleOverlay> {
  BackButtonDispatcher? _root;
  ChildBackButtonDispatcher? _child;

  /// Claimed here rather than in `initState` because `Router.maybeOf` reads an
  /// inherited widget, and taking that dependency lazily from a callback is what
  /// makes the framework complain.
  ///
  /// This can run inside a **layout** callback, not merely a build:
  /// `OverlayPortal.overlayChildLayoutBuilder` wraps its builder in an
  /// `AbstractLayoutBuilder`. Safe because the claim is pure set mutation on
  /// both sides — nothing touches the render tree, nothing calls `setState`, and
  /// `addCallback` here is the **child's** (the plain `_CallbackHookProvider`
  /// one), never `RootBackButtonDispatcher.addCallback`, which is the override
  /// that would mutate `WidgetsBinding`'s observer list. The one dependency
  /// taken, `_RouterScope`, compares five identities that are all fixed for this
  /// app's lifetime, so it never notifies.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final root = Router.maybeOf(context)?.backButtonDispatcher;
    if (!identical(root, _root)) {
      _release();
      _root = root;
    }
    _claim();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _claim() {
    // One callback per child dispatcher, or `_CallbackHookProvider` invokes
    // `_callbacks.single()` and throws — caught, reported, and then silently
    // answering `defaultValue` for ever. The guard also absorbs the re-entry
    // from a deactivate/activate cycle, which keeps this State alive and re-runs
    // `didChangeDependencies` while the overlay is still up.
    if (_child != null) return;
    final root = _root;
    if (root == null) return; // no Router: a bare-MaterialApp test, a preview
    _child = root.createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
  }

  /// `removeCallback` is what un-registers us: with no callbacks left the child
  /// calls `parent.forget(this)`, which drops it from the root's
  /// `LinkedHashSet` and hands priority straight back to whoever held it before.
  void _release() {
    _child?.removeCallback(_onBack);
    _child = null;
  }

  Future<bool> _onBack() async {
    if (!mounted) return false;
    if (!(widget.canDismiss?.call() ?? true)) return false;
    widget.onBack();
    return true; // handled — the Router does not pop
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// [BackDismissibleOverlay] for a `RawAutocomplete` options popover, which is
/// dismissed by dropping the field's focus.
///
/// The other half of [dismissPickerOnTapOutside]: that one gave the popover a
/// way out for a *tap*, this one for the gesture an Android user reaches for
/// first. `RawAutocomplete` handles back even less well than a touch tap —
/// `autocomplete.dart` (and `editable_text.dart`) contain **no** `PopScope`,
/// `BackButtonListener` or `NavigatorPopHandler` at all, and
/// `_canShowOptionsView` closes the overlay only on a `_select`, a
/// `DismissIntent` (Escape, i.e. a hardware keyboard) or focus loss. That was
/// invoiceninja/flutter#134, reported against the Tasks filter bar's Assigned
/// User picker but true of all five hosts.
///
/// It bites hardest on a **keyboard-less** picker (`_suppressKeyboard`, ≤ 6
/// options on touch): `TextInputType.none` suppresses `showSoftInput`, so there
/// is no Android IME to swallow the back press first and it reaches Flutter on
/// the very first try. On a typable picker the IME eats one, which is why the
/// bug looked intermittent — it tracked the size of the option list.
///
/// **Mounted inside `optionsViewBuilder`, never around the field**, so mount ==
/// open; `_buildOptionsView` even returns `SizedBox.shrink()` *without invoking
/// the builder* when the field's paint transform is degenerate, so the
/// containment errs the safe way. `TagPickerField` and `_TaxCell` track no
/// visibility flag of their own and the paragraph above records that adding one
/// to each was considered and rejected; this needs none.
///
/// **`unfocus()`, not `DismissIntent`** — a live bug, not a preference.
/// `RawAutocomplete` registers `_hideOptions` in an `Actions` that wraps only the
/// **field** branch of the portal; the overlay child is a *sibling* element under
/// `_OverlayPortalElement`, so walking up from here skips it and finds the
/// nearest `Actions` **above** `RawAutocomplete` — under a `MaterialApp`,
/// `ModalRoute`'s dismiss action. `Actions.invoke(context, const
/// DismissIntent())` would therefore pop the route: the bug wearing a hat. It
/// would also strand the three hosts that *do* keep an `_optionsVisible` flag,
/// since `EscapeObserver` watches the Escape **key** and a back-triggered intent
/// fires none. Dropping focus needs no bookkeeping at all: every host already
/// clears its flag and snaps its text on blur, so back, tap-outside and a
/// re-pick of the committed row all end in one place.
///
/// A global "a picker is open" flag consulted by `SystemBackGate` is the design
/// not to re-propose: it cannot tell "field focused" from "popover open" —
/// `_select` closes the overlay *without* unfocusing, so it would eat back after
/// every pick — and `SystemBackGate` never runs for a dialog route's back, so a
/// picker inside a dialog would be uncovered.
///
/// `test/lint/picker_popover_wiring_test.dart` fails the build on a
/// `RawAutocomplete` whose popover doesn't carry this.
class BackDismissiblePickerOverlay extends StatelessWidget {
  const BackDismissiblePickerOverlay({
    super.key,
    required this.focusNode,
    required this.child,
  });

  /// The same node the host hands `RawAutocomplete.focusNode` — and the same one
  /// [dismissPickerOnTapOutside] gets. Unfocusing it is what hides the overlay.
  final FocusNode focusNode;

  /// The popover, exactly as `optionsViewBuilder` built it.
  final Widget child;

  @override
  Widget build(BuildContext context) => BackDismissibleOverlay(
    onBack: focusNode.unfocus,
    // Load-bearing, not merely defensive — don't delete it as redundant with
    // the mount lifetime. It is also what makes a picker immune to the
    // route-above hazard in [BackDismissibleOverlay]'s doc: a pushed route
    // takes the focus scope, so `hasFocus` goes false and the press falls
    // through to close that route. (`RawAutocomplete` unmounts the popover on
    // focus loss anyway, so the two agree.) The plainer job it also does is
    // stopping a stale registration from swallowing the user's back.
    canDismiss: () => focusNode.hasFocus,
    child: child,
  );
}

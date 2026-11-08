# Selecting and copying text

Companion to CLAUDE.md § Detail screens. How read-only text is selected and copied on each platform: the `SelectionArea` every detail body (and the `/activity` feed, whose rows have no long-press of their own) sits in, what `AppSelectionArea` adds on touch, how tap-to-copy and selection share one value, and why entity-list rows are left out.

## A detail body is selectable on every platform

**A detail body (and the `/activity` feed) is wrapped in `AppSelectionArea` (`lib/ui/core/widgets/app_selection_area.dart`), never a bare `SelectionArea`, on every platform.** Long-press selects a word on touch, with handles and the Copy / Select all menu; drag selects with a mouse. Until invoiceninja/flutter#188 both sites read `Env.isMobile ? body : SelectionArea(child: body)`, so on a phone the only way to copy part of a record, such as a project's description to paste into a task, was to open its edit screen. Tap-to-copy (below) covers a whole labelled value, but nothing else on the page had it, and nothing on screen says that a tap copies.

The old gate's stated reason was that "selection handles would fight" tap-to-copy. Measured on android under `flutter test` (`defaultTargetPlatform` is android there), they don't:

| Gesture, inside a `SelectionArea` on touch | Result |
|---|---|
| Tap a `GestureDetector(onTap:)` / `InkWell` child | the child gets it |
| Long-press plain text, or a tap-only child | selects the word, menu shows |
| Long-press a child with its own `onLongPress` (list row, call button), no selection showing | the child gets it |
| Vertical drag | scrolls. A touch drag never starts a selection (`_handleMouseDragStart` returns early for an imprecise pointer) |

Mobile web had run this combination since the gate was written (`Env.isMobile` is native-only), and on Android Chrome `defaultTargetPlatform` is android, so it was the same gesture code.

What *does* go wrong is that **Flutter's selection has no dismissal for a tap someone else wins.** `SelectableRegion` clears its selection on a tap only when its own `TapAndHorizontalDragGestureRecognizer` wins the tap, and a deeper recognizer wins the sweep. So after selecting a word, a tap on a row, a tab, a button or a tap-to-copy value ran that action and left the selection and its floating menu up. A tap on the app bar, which is outside the region altogether, did the same. Android's back left the page with the selection still showing, as with the `MenuAnchor` case in `docs/popup-dismissal.md`. `AppSelectionArea` adds both dismissals on touch, and only there:

- **A tap the region did not handle, anywhere in the app.** While a selection shows, a global pointer route (`GestureBinding.pointerRouter.addGlobalRoute`) sees every pointer, the app bar's and the menu's included. A touch tap (under `kTouchSlop`, under `kLongPressTimeout`) is checked **after the next frame**. If the selection is still there, over the same range, with its menu in the same state, the tap did not touch it, so it is dismissed. A changed range is the menu's own Select all. A changed menu is iOS toggling it on a tap on the selection. A gone selection is Android's own collapse, or the menu's Copy. The check runs post-frame, not in a microtask, because the menu's overlay entry is removed synchronously but disposed only when the frame finalizes. A microtask still counted the menu, read iOS's toggle-off as "unchanged" and dismissed the selection the user was tapping to keep. The iOS test in `app_selection_area_test.dart` fails against the microtask version. An earlier version used a `Listener` around the body, which never saw the app bar.
- **Android's back.** While a selection shows, a `ChildBackButtonDispatcher` takes back first and clears it, claimed imperatively and released when the selection goes (the `BackDismissibleMenuAnchor` pattern). A swapped `Router` root takes a standing claim with it, as `picker_dismissal.dart` does.

Four details are load-bearing:

- **Whether a selection shows is read live, from a `SelectionListener`, never remembered.** A selection can vanish with no gesture at all, when its text unmounts on a tab switch or a record refresh. `SelectionArea.onSelectionChanged` fires only from gestures and `clearSelection`, never from the geometry update an unmount causes. A flag kept from it outlived the selection, swallowed the next back and spent the next tap-to-copy on nothing. The listener's notifier reads the region's geometry, so `_onBack` re-checks it and lets a stale claim's back through. (Swapping one `Text` for another in the same slot is *not* an unmount: the paragraph is updated in place and keeps a selection over the new text, which is still a selection that shows.)
- "Shows" means `SelectionStatus.uncollapsed`. Android collapses the selection on a tap rather than removing it, so "has a selection" reads true after any tap on plain text.
- Whether the menu is showing is counted by the menu's own mount and unmount (`_ToolbarPresence`, wrapped around the SelectionArea's default `AdaptiveTextSelectionToolbar.selectableRegion`), because `SelectableRegionState.selectionOverlay` is `@visibleForTesting`. It is a count, not a flag, because a re-shown menu can mount its replacement before the old one disposes.
- **With a mouse (`!Env.isTouchPrimary`) the widget builds a bare `SelectionArea` and nothing else** — no listener, no menu wrapper, no route — so desktop is exactly what it was. `onSelectionChanged` in particular would build the whole selected string on every drag update of a long body.

**On Android a horizontal scrub across an fl_chart chart in a detail body does nothing** (upstream; no workaround). On Android, `TapAndHorizontalDragGestureRecognizer` sets `eagerVictoryOnDrag` and claims a horizontal drag at `computeHitSlop` with no gesture settings (`kTouchSlop`, 18), even though a touch drag never starts a selection. A recognizer under it that waits longer loses the arena. A `GestureDetector` reads the device's slop from `MediaQuery` (`DeviceGestureSettings.fromView`, about 8 dp on Android, so a pan accepts at about 16) and still wins, which covers `InteractiveViewer` and so the PDF pane. fl_chart's `RenderBaseChart` builds a bare `PanGestureRecognizer` that waits for `kPanSlop` (36). A tap on a point and a long-press-and-drag still reach the chart, and iOS waits for the others to lose (`eagerVictoryOnDrag = false`), so it is unaffected. `SelectionContainer.disabled` around the charts and the PDF view stops text registering, not the region's recognizers. Under `flutter test` there is no device slop, so a `GestureDetector` pan there loses too: a test of a pan inside a detail body needs `gestureSettings` on its `MediaQuery`.

Upstream `SelectionArea` crash reports that touch now shares with desktop: flutter#196102 and flutter#192081 (a selectable holding a selection edge removed, or a clear while selectables change) and flutter#195521 (a `Text.rich` with `WidgetSpan`s rebuilt mid-selection).

## Tap-to-copy yields to a showing selection

**`CopyableValue`'s touch tap copies the whole value in one tap, unless a selection is showing — then the tap is spent dismissing it (`AppSelectionArea.dismissSelection`).** A tap on text dismisses a native selection, and copying the whole value over the user's own selection, with a toast, was the surprise the old gate had feared. A long-press on a value selects a word like anywhere else. A link-bearing value's long-press-to-copy (`enableLongPressToCopy`) always copies: it is deliberate, and with a selection showing the region wins the long-press anyway.

One consequence is accepted: on iOS a tap on a word selected *inside* a tap-to-copy value is won by the value, so it dismisses the selection rather than toggling its menu as a tap on selected plain text does.

## List rows stay unselectable on touch

**A touch entity-list row has no text selection: its tap is its one destination (`docs/row-actions-and-values.md` § A narrow list row has exactly one destination) and its long-press starts multi-select (`SelectableListRow.onLongPress`).** Selection would have to take one of those away, and the record's detail screen, where everything is selectable, is one tap away. With a mouse, `CellCopyHover` puts a copy icon on a table cell.

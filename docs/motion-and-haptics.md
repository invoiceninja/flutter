# Motion and haptics — how long things move, and when the device buzzes

Companion to CLAUDE.md § Design system (v2). That section carries the rule; this doc carries the tokens, why reduced motion is the same code path, and where the haptics may fire. The first surfaces built on them are the setup wizard, the dashboard checklist and the first-run Welcome (docs/first-run-welcome.md), whose motion table is below.

| Piece | File |
|---|---|
| Durations, curves, the reduced-motion switch | `InMotion` in `lib/app/design_tokens.dart` |
| The haptic vocabulary | `InHaptics` in `lib/ui/core/utils/haptics.dart` |

## Every decorative animation runs through `InMotion.of(context)`, so reduced motion is zero, and the device buzzes only through `InHaptics`

**Durations.** `InMotion.fast` (150 ms) for a quick acknowledgement — a crossfade, an exit; `base` (240 ms) for an element entering or changing place; `slow` (320 ms) for a larger surface or a bar filling. A moment that needs its own figure (a 450 ms finish, a 280 ms collapse) still passes it through `InMotion.of(context)(duration)`: the point of the rule is the reduced-motion answer, not a ban on numbers.

**Curves.** `InMotion.out` (easeOutCubic) for things arriving, `in_` (easeInCubic) for things leaving, `move` (easeInOutCubic) for things travelling between states.

**Reduced motion is the same code.** `InMotion.of(context)` reads `MediaQuery.disableAnimations` and answers `Duration.zero` when the user asked for less — so every state still changes (a tick still turns green, a step still swaps), nothing moves, and there is no second branch to forget. A route transition, which builds outside the widget's own context, checks `MediaQuery.maybeDisableAnimationsOf` itself (the `/setup` page in `router.dart`).

**Haptics only on a native phone or tablet.** `InHaptics` fires only when `Env.isMobile`: desktop and web have no motor, and a platform-channel call there is at best a no-op and at worst an error in a test. Three weights, one meaning each:

| Call | When |
|---|---|
| `InHaptics.selection()` | moving between choices — a wizard step, a Welcome list switch |
| `InHaptics.light()` | something the user did landed — a logo into the preview, a checklist tick on return |
| `InHaptics.success()` | a flow they started is finished — the wizard's finish, the checklist all done |

A haptic fires once per event: the checklist's all-done buzz is guarded by the record it writes, so a second visit stays still.

## An animation that repeats forever runs only while the app is `resumed` and motion is not reduced

A repeating `AnimationController` asks for a frame every vsync, and a frame is the whole window drawn again, however small the thing that moved. The framework stops frames on its own only in the `hidden` and `paused` lifecycle states. The Linux embedder reports `hidden` from GDK's iconified / withdrawn window state, which X11 sets and **Wayland does not**: xdg-shell has no minimized state a GTK 3 client can read, and a covered window is told nothing either. So on native Wayland a minimized window stays `inactive` and keeps drawing.

That shipped as invoiceninja/flutter#189: the Flatpak (native Wayland) held 17-19 % of the GPU, and eleven cores under software rendering, while minimized. The AppImage sat at 0 % on the same machine only because `linuxdeploy-plugin-gtk` forces `GDK_BACKEND=x11`. The source was the pulsing dot in `RunningDurationLabel`, which the shell's running-timer pill mounts on every screen for as long as a timer runs.

The rule: an animation with no end is started only while `WidgetsBinding.instance.lifecycleState` is `resumed` (or null, before the first report) and `MediaQuery.disableAnimations` is off, and is parked at its resting value otherwise. Losing focus is the one signal every platform and compositor sends, and a window the user is not working in does not need a decoration to move. `_syncPulse` in `running_duration_label.dart` is the reference; `running_duration_label_test.dart` pins it by asserting no frame is scheduled once the app is `inactive`. A once-a-second text tick is fine in the background; sixty frames a second is not.

The fix is in the app, not the packaging: the Flathub manifest is not ours to change for this (docs/flatpak.md), and forcing X11 there would only hide the cost on one package.

## The first-run surfaces' motion

| Moment | Motion | Haptic |
|---|---|---|
| Sign-up → `/setup` | the wizard waits 90 ms, then fades in and settles from 0.98 over 210 ms (the old page is not faded) | — |
| Wizard first frame | heading, subtitle and fields fade and rise 8 px over 360 ms | — |
| Wizard step change | out 120 ms, in 240 ms, sliding from the side it was reached from, mirrored in RTL | selection |
| Logo into the preview | fade + scale from 0.94, 260 ms | light |
| Finish | the button turns into a check, the bar fills, the content fades — 450 ms, then the commit | success |
| Checklist arrives | fade + 12 px rise, 320 ms, after 120 ms | — |
| A tick on return | scale 0.6 → 1, easeOutBack; bar 400 ms | light |
| All done | title crossfade; colour to `paid` | success |
| Welcome in | dialog fade + scale from 0.96, 220 ms; the sheet slides up | — |

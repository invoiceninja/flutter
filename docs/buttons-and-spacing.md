# Buttons and spacing

Companion to CLAUDE.md § Design system (v2). Why a button stretches edge to edge, why dialog actions stack, what `PrimaryDialogAction` bakes in, and how the responsive spacing tokens and bordered-card padding are sized. CLAUDE.md keeps one line per rule; the mechanism and the reference call sites are here.

## Pair related action buttons side-by-side

**Pair related action buttons side-by-side**, not stacked — a `Row` with `SizedBox(width: InSpacing.md(context))` between them. Cancel sits next to the primary action, never above it.

## Side-by-side dialog actions need a per-call `minimumSize` override

**Side-by-side dialog actions need a per-call `minimumSize` override.** A `FilledButton` / `FilledButton.tonal` / `OutlinedButton` inside `AlertDialog.actions` (or any `Row`) needs `style: FilledButton.styleFrom(minimumSize: const Size(64, 44))` (Outlined uses `Size(64, 40)`). The themes default to `Size.fromHeight(44)` = infinite width — right for column-stacked form buttons, but in a horizontal context `Row` crashes layout and `AlertDialog.actions` silently stacks via `OverflowBar`. Inline comments in `theme.dart` explain why.

## Dialog primary actions use `PrimaryDialogAction`

**Dialog primary actions use `PrimaryDialogAction`** (`lib/ui/core/widgets/primary_dialog_action.dart`), not a hand-rolled `FilledButton`. It bakes in the `Size(64, 44)` override, `autofocus`, and a subtle trailing **Enter** affordance (a dimmed `↵` — the app's standard Enter glyph) so users learn Enter submits. `variant:` selects plain / `.tonal` / `.destructive`; keep `autofocus: false` when a text field should own focus (Enter still submits via `FormSaveScope`/`onSubmitted`), and `showEnterHint: false` when Enter can't/shouldn't fire the primary. Two non-obvious `showEnterHint: false` cases (they cause a *lying* hint otherwise): **dropdown-only dialogs** — `SearchableDropdownField` consumes Enter to pick an option and never calls `FormSaveScope.trySubmit()`, so a scope around it is dead; and **primaries that start disabled** (`enabled: x != null`) — a disabled button can't take `autofocus`, so Enter never reaches it. References: `discard_changes_dialog.dart`, `company_picker.dart`, `type_to_confirm_dialog.dart` (destructive), `merge_client_dialog.dart` (dropdown → no hint).

## Centered single-action buttons must constrain their own width too

**Centered single-action buttons must constrain their own width too.** The same `Size.fromHeight(44)` (= `Size(double.infinity, 44)`) default makes a bare `FilledButton` stretch full-width — wrong for an `EmptyState` action or any centered call-to-action (renders as one edge-to-edge bar). Pass `minimumSize: const Size(64, 44)` so it sizes to content. Don't create full-width `FilledButton`s outside a deliberately column-stacked form/footer context. Reference: the Reports empty-state "Run report" action in `lib/ui/features/reports/widgets/reports_body.dart`.

## Spacing tokens are responsive and take a context

**Spacing tokens `InSpacing.md` / `InSpacing.lg` are responsive context-aware static methods** (`lib/app/design_tokens.dart`), not const doubles — wider on desktop, tighter on mobile (`md`: 8 px narrow `<600` / 12 px wide `≥600`; `lg`: 12 / 16 px). Call with a `BuildContext`: `EdgeInsets.all(InSpacing.lg(context))`, `SizedBox(width: InSpacing.md(context))`. **Drop `const` from any wrapping `EdgeInsets` / `SizedBox` / `Padding`** — the value is no longer compile-time const (perf cost is nil: Flutter's `Element.canUpdate` matches on `runtimeType + key`, not `==`). `InSpacing.sm` (8 px) stays `const` for math contexts and small inter-icon gaps; `xs` / `xl` / `xxl` stay const too — not part of the responsive system.

## Bordered-card form sections pad with `InSpacing.lg(context)`

**Bordered-card form sections use `InSpacing.lg(context)` interior padding by default.** That's what `FormSection`, `DashboardCardShell`, and the task-edit identity card use; new one-off bordered cards (`Container` with `tokens.border` + `BorderRadius.circular(InRadii.r3)`) match with `padding: EdgeInsets.all(InSpacing.lg(context))`. Column-aligned interior surfaces (table headers + rows + add-row tiles) use the horizontal value (`horizontal: InSpacing.lg(context)`) so cells line up with the section title. Card-to-card inset consistency is the point.

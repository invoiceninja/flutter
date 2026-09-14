import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_edit_field_decoration.dart';

/// A form field that is **shown but not editable**, because the server refuses
/// to change it on UPDATE. Renders as an [InputDecorator] matching the host's
/// own field chrome: floating label, the resolved value, a lock suffix, and a
/// helper line saying why.
///
/// Deliberately **not** a disabled picker. A greyed-out combobox reads as
/// "temporarily unavailable, try again" — which is a lie the user keeps
/// tapping, and is precisely the confusing UX invoiceninja/flutter#158 was
/// filed about. A lock plus a sentence is the honest rendering of "not ever".
///
/// An **empty** id is rendered, not refused: the value falls back to a muted em
/// dash and the row loses its tap target, but the label and the reason still
/// say what is locked. Falling through to the live picker instead was tried and
/// removed — on a saved record the server pins the party to its current value,
/// so a picker there can only 422 or be discarded.
///
/// Lives in `core/widgets/` rather than `core/edit/`: it takes no ViewModel, it
/// composes [ClientNameLabel] / [VendorNameLabel] / [LinkText] which all live
/// here, and it must stay outside `lib/ui/features/**` — see
/// [LockedClientFieldRow] for why that is load-bearing rather than tidiness.
class LockedEntityFieldRow extends StatelessWidget {
  const LockedEntityFieldRow({
    super.key,
    required this.label,
    required this.child,
    this.helperText,
    this.errorText,
    this.onTap,
  });

  /// Already resolved through `tr()`.
  final String label;

  /// The resolved value. A `*NameLabel`, never raw text built from an id.
  final Widget child;

  /// Already resolved through `tr()`. Null renders no helper line.
  ///
  /// Rendered as a sibling BELOW the tappable field box rather than through
  /// `InputDecoration.helperText`, which lays out inside the decorator — and so
  /// inside the row's hit area. "Why can't I edit this?" → tap the sentence was
  /// then a navigation away from the form, raising a discard prompt on a dirty
  /// one. The explanation must not be a tap target.
  ///
  /// Suppressed while [errorText] is set, so the two never stack: a live
  /// rejection outranks a standing explanation. (`InputDecoration` enforces the
  /// same precedence for its own pair; here it is explicit because the two no
  /// longer share a slot.)
  final String? helperText;

  final String? errorText;

  /// Opens the record the value names. Null leaves the row inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // `billingFieldDecoration` rather than the ambient `inputDecorationTheme`:
    // it is byte-for-byte the chrome `SearchableDropdownField` builds inline
    // (dense, 14/14 padding, `InRadii.r1` outline, accent focus), and EVERY
    // picker this row stands in for — `ClientPickerField`, `EntityPickerField`,
    // `SearchableDropdownField` — renders with it. Matching the control it
    // replaces is the whole point; the ambient theme differs by one radius step
    // and would read as a seam beside its own siblings.
    //
    // `errorText` stays ON the decoration: it owns the error border, and it is
    // rare and transient, so having it inside the tap area is an acceptable
    // trade the always-visible helper line is not (see [helperText]).
    final decorated = InputDecorator(
      decoration: billingFieldDecoration(context).copyWith(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 3,
        suffixIcon: Icon(Icons.lock_outline, size: 18, color: tokens.ink3),
        // An `InputDecorator` with no editable child never focuses and is never
        // "empty" (`_labelShouldWithdraw` is `!isEmpty || (isFocused &&
        // enabled)`), so without this the label sits ON the value instead of
        // floating. Same mechanism `docs/pickers.md` § A picker's empty state
        // has to say something documents for the disabled-placeholder branch.
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: child,
    );
    final tap = onTap;
    final field = tap == null
        ? decorated
        // The ROW owns the tap, and the name carries the visual cue (see
        // [lockedValueLinkStyle]). The alternative — a `*NameLabel(link: true)`
        // inside the decorator — cannot work here: `LinkText` is
        // `HitTestBehavior.opaque` and sizes to its glyphs, so reaching the
        // `InSizes.touchTarget` floor would mean a min-height constraint that
        // `RenderParagraph` passes straight into the decorator's child,
        // inflating a ~48 px field to ~72. This is the ancestor-tap mode
        // `LinkText`'s own doc describes, and the same call
        // `no_list_tile_name_link_test` pins for list rows: one surface, one
        // destination.
        //
        // The field already clears `InSizes.touchTarget` on every platform
        // without help: `InputDecorator` wraps `suffixIcon` in its own
        // `ConstrainedBox(minHeight: kMinInteractiveDimension)` (48), and this
        // row always has one. An explicit floor here would be dead code, and a
        // test "pinning" it would pass with the floor deleted.
        : MergeSemantics(
            // `button:`, not `link:` — `docs/row-actions-and-values.md` is
            // explicit that an inline text link takes `link` while **a whole
            // row that navigates keeps `button`**, as `ActivityFeedRow` does.
            // `onTap` is re-declared because role and action otherwise come
            // from two different nodes: `InkResponse` supplies the action and
            // never sets `button` (`ink_well.dart`), which is the split
            // `semantics_excludes_need_ontap_test.dart` exists to catch.
            // `MergeSemantics` (rather than `ExcludeSemantics` + an explicit
            // `label:`) folds the label, value and reason into that one node
            // without needing the value as a synchronous string — it arrives
            // asynchronously from `ClientNameLabel`.
            child: Semantics(
              button: true,
              onTap: tap,
              child: Material(
                // A LOCAL Material, never the ancestor's:
                // `test/lint/no_ink_widget_test.dart`.
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: tap,
                  borderRadius: BorderRadius.circular(InRadii.r1),
                  child: decorated,
                ),
              ),
            ),
          );

    final helper = helperText;
    return Padding(
      // Matches `ClientPickerField.build`'s own wrapper, so swapping the picker
      // for this row doesn't shift the card's vertical rhythm.
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          if (helper != null && errorText == null) ...[
            const SizedBox(height: 4),
            Padding(
              // Line the reason up with the field's own content box rather than
              // its border, the way Material insets its helper row.
              padding: EdgeInsets.symmetric(horizontal: InSpacing.md(context)),
              child: Text(
                helper,
                maxLines: 3,
                style:
                    theme.inputDecorationTheme.helperStyle ??
                    theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The at-rest styling for a locked row's value when the row navigates.
///
/// On touch it underlines and recolours, because the hover underline that
/// carries "this is a link" on a pointer platform can never fire there
/// (invoiceninja/flutter#128) — and an `InkWell` shows nothing at rest either.
/// On a pointer platform the `InkWell`'s own hover highlight and click cursor
/// are the affordance, so the text is left alone.
TextStyle? lockedValueLinkStyle(BuildContext context) {
  if (!linkNeedsAtRestCue) return null;
  return TextStyle(
    color: linkAtRestColor(context),
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.underline,
    decorationColor: linkAtRestColor(context),
  );
}

/// [LockedEntityFieldRow] for a client, resolved through [ClientNameLabel] and
/// tapping through to the client when the signed-in user can `view_client`.
///
/// [ClientNameLabel] is not an implementation detail here — it is the reason
/// this widget exists rather than a fourth hand-rolled `StreamBuilder<Client?>`
/// + `Text(name ?? id)`. The two rows this replaces both printed the raw hashid
/// on a cache miss AND never called `ClientRepository.ensureLoaded`, so for a
/// client outside the locally-paged window the name never resolved at all.
/// See `client_name_label.dart`'s own "Never renders the raw clientId" note.
///
/// Passes `link: false`: the row owns the tap. That also keeps every host file
/// clear of the literal `link: true`, which `test/lint/no_list_tile_name_link_test.dart`
/// substring-scans for across the whole of `lib/ui/features/`.
class LockedClientFieldRow extends StatelessWidget {
  const LockedClientFieldRow({
    super.key,
    required this.clientId,
    this.label,
    this.helperText,
    this.errorText,
    this.tappable = true,
  });

  final String clientId;

  /// Defaults to `tr('client')`.
  final String? label;
  final String? helperText;
  final String? errorText;

  /// False leaves the row inert — for a lock whose value is not a destination
  /// the user should be sent to (the task form's project-derived client).
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final canView =
        context.read<Services>().auth.session.value?.currentCompany?.can(
          'view_client',
        ) ??
        false;
    final navigates = tappable && canView && clientId.isNotEmpty;
    return LockedEntityFieldRow(
      label: label ?? context.tr('client'),
      helperText: helperText,
      errorText: errorText,
      onTap: navigates
          ? () => goEntityFullDetail(context, '/clients', clientId)
          : null,
      child: ClientNameLabel(
        clientId: clientId,
        style: navigates ? lockedValueLinkStyle(context) : null,
      ),
    );
  }
}

/// Vendor twin of [LockedClientFieldRow] — `view_vendor` / `/vendors`.
class LockedVendorFieldRow extends StatelessWidget {
  const LockedVendorFieldRow({
    super.key,
    required this.vendorId,
    this.label,
    this.helperText,
    this.errorText,
    this.tappable = true,
  });

  final String vendorId;

  /// Defaults to `tr('vendor')`.
  final String? label;
  final String? helperText;
  final String? errorText;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final canView =
        context.read<Services>().auth.session.value?.currentCompany?.can(
          'view_vendor',
        ) ??
        false;
    final navigates = tappable && canView && vendorId.isNotEmpty;
    return LockedEntityFieldRow(
      label: label ?? context.tr('vendor'),
      helperText: helperText,
      errorText: errorText,
      onTap: navigates
          ? () => goEntityFullDetail(context, '/vendors', vendorId)
          : null,
      child: VendorNameLabel(
        vendorId: vendorId,
        style: navigates ? lockedValueLinkStyle(context) : null,
      ),
    );
  }
}

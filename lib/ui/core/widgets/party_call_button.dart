import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/utils/phone_actions.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// Height of the [PhoneCallButtonVariant.inline] trigger's layout box: the
/// `bodyMedium` line box of the name row it sits in, at text scale 1.0.
///
/// **Not** [InSizes.touchTarget], and that is the whole point. A 44 px-tall
/// box would drive the row's cross axis and push the dates + KPI strip down
/// ~24 px on every billing-doc header — and, because the party resolves
/// asynchronously, do it a frame or two *late* on a cold deep link, which is
/// exactly the follow-a-link-in-the-field case. CLAUDE.md's touch-target trap
/// 4 covers this shape by name: *cap trailing widgets to the row's content
/// box, not the target*. The target is reclaimed on the axis that has room —
/// the box is [actionButtonSize()] **wide** — the same trade
/// `contactActionButtonStyle` (32) and `CopyIconButton` (22) already make.
///
/// It must stay `<=` the name's own line box or the header grows;
/// `party_call_button_test.dart`'s `layout` group pins that at 1.0x and at
/// `kTextScaleMax`, so bumping the app's base font size will fail there rather
/// than silently shifting five screens.
///
/// [PhoneCallButtonVariant.listRow] deliberately does **not** use it — see
/// there for why the same trade points the other way in a list row.
const double _kTriggerHeight = 20;

/// Extra width for the `▾` affordance when there is more than one number.
///
/// [PhoneCallButtonVariant.inline] only. `listRow` fits the caret *inside* its
/// larger target instead of widening the box — see there.
const double _kCaretWidth = 12;

/// Where a [PhoneCallButton] is being rendered, which is the one thing that
/// decides its box, its alignment, its weight and whether it claims the
/// secondary gesture. Four knobs that always move together, so one parameter
/// rather than four booleans a caller could mix incoherently.
enum PhoneCallButtonVariant {
  /// Beside a party's name in a detail header (invoiceninja/flutter#110).
  ///
  /// [_kTriggerHeight] tall so it can never drive the name row's cross axis;
  /// glyph start-aligned so it reads as attached to the name it acts on;
  /// 16/14 px icons, sized to sit with 14 px body text; long-press (touch) or
  /// right-click (pointer) copies the number.
  inline,

  /// A standalone control in an entity-list row's trailing action cluster
  /// (invoiceninja/flutter#111).
  ///
  /// Four deliberate differences from [inline], each the mirror image of a
  /// header constraint that doesn't apply here:
  ///
  ///  * **An [actionButtonSize()]-tall box** — square on touch (44), and on a
  ///    pointer as wide as its glyphs need (see the `math.max` in `_build`).
  ///    Trap 4 says reclaim the target on the axis that has room; in a header
  ///    that axis is horizontal, in a list row it is *vertical* — the row is
  ///    already floored at [kEntityListRowHeight] and the sibling `…` menu is
  ///    already [actionButtonSize()] tall, so 44 px adds no height at all.
  ///  * **Centred glyph**, because the `…` beside it is a centred `IconButton`
  ///    and a start-aligned one sits ~14 px off its neighbour's axis.
  ///  * **20/18 px icons in `ink2`.** That `…` is an M3 `IconButton`: 24 px in
  ///    `onSurfaceVariant`, which `theme.dart` maps to `ink2`. At the inline
  ///    16 px `ink3` the call glyph reads as a faint afterthought next to it.
  ///  * **No secondary gesture.** The row owns long-press (enter multi-select);
  ///    a copy toast where the user expected selection is the wrong trade. With
  ///    no child `LongPressGestureRecognizer` the gesture falls straight
  ///    through to the row.
  listRow,
}

/// The phone affordance beside a billing document's client / vendor name
/// (invoiceninja/flutter#110).
///
/// Resolves the party from Drift, builds its [PhoneCandidate] list and hands it
/// to [PhoneCallButton]. Exactly one of [clientId] / [vendorId] should be set.
///
/// [PhoneActionsScope] is the **outermost** thing here, and deliberately so: it
/// gates the Drift watch and the `ensureLoaded` on the preference, so a device
/// with tap-to-call off (the desktop default) does no work at all. Putting the
/// scope inside [PhoneCallButton] would still render correctly and still
/// subscribe on every billing-doc detail screen.
class PartyCallButton extends StatefulWidget {
  const PartyCallButton({super.key, this.clientId, this.vendorId});

  final String? clientId;
  final String? vendorId;

  @override
  State<PartyCallButton> createState() => _PartyCallButtonState();
}

class _PartyCallButtonState extends State<PartyCallButton> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(PartyCallButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId ||
        oldWidget.vendorId != widget.vendorId) {
      _ensure();
    }
  }

  /// Lazily hydrate an off-page party — same shape as `ClientNameLabel._ensure`
  /// (deduped and negative-cached in the repo, so firing it unconditionally is
  /// safe). In practice a no-op: the sibling name label in the same `Row`
  /// already asked for this party.
  void _ensure() {
    final clientId = widget.clientId ?? '';
    final vendorId = widget.vendorId ?? '';
    if (clientId.isEmpty && vendorId.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    if (vendorId.isNotEmpty) {
      services.vendors.ensureLoaded(companyId: companyId, id: vendorId);
    } else {
      services.clients.ensureLoaded(companyId: companyId, id: clientId);
    }
  }

  @override
  Widget build(BuildContext context) => PhoneActionsScope(builder: _build);

  Widget _build(BuildContext context) {
    final services = context.read<Services>();
    if (!services.phoneActions.value.tapToCall) return const SizedBox.shrink();

    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final clientId = widget.clientId ?? '';
    final vendorId = widget.vendorId ?? '';
    if (companyId.isEmpty || (clientId.isEmpty && vendorId.isEmpty)) {
      return const SizedBox.shrink();
    }

    if (vendorId.isNotEmpty) {
      return WatchBuilder<Vendor?>(
        cacheKey: (companyId, vendorId),
        initialData: services.vendors.peek(companyId: companyId, id: vendorId),
        create: () =>
            services.vendors.watch(companyId: companyId, id: vendorId),
        builder: (context, snap) {
          final vendor = snap.data;
          return PhoneCallButton(
            candidates: vendor == null
                ? const <PhoneCandidate>[]
                : vendorPhoneCandidates(vendor),
            partyName: vendor?.name ?? '',
            // No `clientId`: a vendor has no settings cascade, so the
            // out-of-hours check falls back to the company's timezone.
            onViewParty: () =>
                goEntityFullDetail(context, '/vendors', vendorId),
            viewPartyLabelKey: 'view_vendor',
          );
        },
      );
    }

    return WatchBuilder<Client?>(
      cacheKey: (companyId, clientId),
      initialData: services.clients.peek(companyId: companyId, id: clientId),
      create: () => services.clients.watch(companyId: companyId, id: clientId),
      builder: (context, snap) {
        final client = snap.data;
        return PhoneCallButton(
          candidates: client == null
              ? const <PhoneCandidate>[]
              : clientPhoneCandidates(client),
          partyName: client?.displayName ?? '',
          clientId: clientId,
          onViewParty: () => goEntityFullDetail(context, '/clients', clientId),
          viewPartyLabelKey: 'view_client',
        );
      },
    );
  }
}

/// The trigger itself: a discrete phone glyph that dials a single number, or
/// opens a picker when the party has several.
///
/// Party-agnostic — it takes a resolved candidate list — so it is testable
/// without a repository. Renders nothing when [candidates] is empty or the
/// preference is off, so a caller needs no branching of its own.
class PhoneCallButton extends StatefulWidget {
  const PhoneCallButton({
    super.key,
    required this.candidates,
    required this.partyName,
    this.clientId,
    this.onViewParty,
    this.viewPartyLabelKey = 'view_client',
    this.variant = PhoneCallButtonVariant.inline,
  });

  final List<PhoneCandidate> candidates;

  /// Box, alignment, icon weight and secondary gesture. See
  /// [PhoneCallButtonVariant] — the five billing-doc headers take the default.
  final PhoneCallButtonVariant variant;

  /// Names the party in the picker's title. Not a fallback for a contact name.
  final String partyName;

  /// Resolves the per-client timezone override for the out-of-hours warning.
  /// Null for a vendor, which has no settings cascade of its own.
  final String? clientId;

  /// Escape hatch from the picker to the party's own screen, which lists every
  /// stored number — including ones `cleanPhoneNumber` deliberately rejects.
  final VoidCallback? onViewParty;
  final String viewPartyLabelKey;

  @override
  State<PhoneCallButton> createState() => _PhoneCallButtonState();
}

class _PhoneCallButtonState extends State<PhoneCallButton> {
  bool _hovering = false;

  /// Re-entrancy latch: `callPhoneNumber` is async, so without this a
  /// double-tap fires two launches (and two confirm dialogs).
  bool _busy = false;

  @override
  Widget build(BuildContext context) => PhoneActionsScope(builder: _build);

  Widget _build(BuildContext context) {
    if (!context.read<Services>().phoneActions.value.tapToCall) {
      return const SizedBox.shrink();
    }
    final candidates = widget.candidates;
    if (candidates.isEmpty) return const SizedBox.shrink();

    final tokens = context.inTheme;
    final multi = candidates.length > 1;
    final listRow = widget.variant == PhoneCallButtonVariant.listRow;
    final idle = listRow ? tokens.ink2 : tokens.ink3;
    final glyph = listRow ? 20.0 : 16.0;
    final caret = listRow ? 18.0 : 14.0;
    // `listRow` fits the caret *inside* the target rather than bolting
    // [_kCaretWidth] on beside it: a 44 px box already has room for 20 + 18,
    // and in a list row those 12 px come straight out of the client's name.
    // The `max` is the pointer case, where the target is only 32 and the
    // glyphs genuinely need more. Icons don't scale with text (`Icon`
    // defaults `applyTextScaling` to false), so this is a fixed comparison.
    final width = listRow
        ? math.max(actionButtonSize(), glyph + (multi ? caret : 0))
        : actionButtonSize() + (multi ? _kCaretWidth : 0);
    // Touch keeps the secondary gesture only on the inline variant; in a list
    // row the long-press belongs to the row (enter multi-select).
    final secondary = listRow ? null : () => _onSecondary(context);

    Widget button = Material(
      // The header card is an opaque `Container` and `EntityDetailScaffold`
      // skips its own `Scaffold` in a master-detail pane, so ink needs a host
      // right here or the splash is painted under the card (or asserts).
      // Same reasoning as `DashboardCardShell`.
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _onTap(context),
        // Touch-only. On desktop the detail body sits inside a `SelectionArea`
        // and the tooltip below already claims long-press, so an unconditional
        // handler would put three consumers in one subtree — and no test would
        // see it, since `flutter test` reports android.
        onLongPress: Env.isTouchPrimary ? secondary : null,
        onSecondaryTap: Env.isTouchPrimary ? null : secondary,
        onHover: (value) {
          if (value != _hovering) setState(() => _hovering = value);
        },
        borderRadius: BorderRadius.circular(InRadii.r1),
        // Inside the ink widget, and with no `excludeSemantics`: that flag
        // prunes descendant semantics, and `InkWell` contributes its tap
        // action as a descendant — wrapping from outside yields a node a
        // screen reader announces but cannot activate. `CopyIconButton` has
        // the same shape.
        child: Semantics(
          button: true,
          label: _semanticsLabel(context, multi: multi),
          child: SizedBox(
            width: width,
            height: listRow ? actionButtonSize() : _kTriggerHeight,
            child: Row(
              // Inline: start-aligned, not centred — the box is 44 px wide for
              // the finger, but the *glyph* has to sit next to the name it acts
              // on, and centring it strands the icon ~22 px out in the slack
              // where it reads as unattached. The extra width extends
              // rightwards into empty row space instead.
              //
              // In a list row there is no name to attach to and the `…` next
              // to it is a centred `IconButton`, so centring is what puts the
              // two glyphs on one axis.
              mainAxisAlignment: listRow
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.call_outlined,
                  size: glyph,
                  color: _hovering ? tokens.accent : idle,
                ),
                // The house "this opens a list" marker. Without it, one glyph
                // would hide two different behaviours.
                if (multi)
                  Icon(
                    Icons.arrow_drop_down,
                    size: caret,
                    color: _hovering ? tokens.accent : idle,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!Env.isTouchPrimary) {
      button = Tooltip(
        message: _tooltip(context, multi: multi),
        child: button,
      );
    }
    // The gap lives here, not at the call site, so it disappears along with
    // the button when there is nothing to dial. It is not decorative, in
    // either variant: inline, the name beside this is a `LinkText` whose
    // `GestureDetector` is `HitTestBehavior.opaque` and runs right up to our
    // edge; in a list row the whole row is a tap target that opens the record.
    // Two adjacent targets that do opposite things (dial the party vs.
    // navigate away) — the same rule `kColActionsClusterGap` states for the
    // list table's action cluster, and the reason the tile puts that constant
    // on our other side.
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: InSpacing.sm),
      child: button,
    );
  }

  String _labelOf(BuildContext context, PhoneCandidate candidate) =>
      candidate.label.isEmpty
      ? context.tr('no_name_fallback')
      : candidate.label;

  String _semanticsLabel(BuildContext context, {required bool multi}) {
    final call = context.tr('call');
    if (multi) {
      return widget.partyName.isEmpty ? call : '$call ${widget.partyName}';
    }
    return '$call ${_labelOf(context, widget.candidates.first)}';
  }

  String _tooltip(BuildContext context, {required bool multi}) {
    if (multi) return _semanticsLabel(context, multi: true);
    final only = widget.candidates.first;
    return '${_semanticsLabel(context, multi: false)} · ${only.phone}';
  }

  /// Long-press (touch) / right-click (pointer). Copies the one number, or
  /// opens the picker when there is nothing single to copy.
  Future<void> _onSecondary(BuildContext context) async {
    if (widget.candidates.length > 1) return _onTap(context);
    await copyToClipboard(context, widget.candidates.first.phone);
  }

  Future<void> _onTap(BuildContext context) async {
    if (_busy) return;
    final candidates = widget.candidates;
    if (candidates.isEmpty) return;
    _busy = true;
    try {
      var picked = candidates.first;
      if (candidates.length > 1) {
        final chosen = await showPhoneCandidatePicker(
          context,
          candidates: candidates,
          partyName: widget.partyName,
          clientId: widget.clientId,
          onViewParty: widget.onViewParty,
          viewPartyLabelKey: widget.viewPartyLabelKey,
        );
        if (chosen == null) return;
        picked = chosen;
      }
      // This context, never the picker's. `callPhoneNumber` re-checks
      // `context.mounted` only *after* awaiting the timezone cascade, so
      // dialling from a route that is mid-pop silently drops the call along
      // with its confirm dialog — a race against the exit animation.
      if (!context.mounted) return;
      await callPhoneNumber(
        context,
        picked.phone,
        subject: _labelOf(context, picked),
        clientId: widget.clientId,
      );
    } finally {
      _busy = false;
    }
  }
}

/// Asks which of [candidates] to dial, returning the choice (or null).
///
/// A bottom sheet on touch, a centered dialog with a pointer — the split
/// `showLineItemPickerSheet` already makes, and not cosmetic:
/// `showModalBottomSheet` defaults to `useRootNavigator: false`, so on a wide
/// layout it mounts on the master-detail pane's nested navigator and would be
/// a full-width slab pinned to the bottom of a ~500 px column.
///
/// Returns rather than dialling: see `_PhoneCallButtonState._onTap`.
Future<PhoneCandidate?> showPhoneCandidatePicker(
  BuildContext context, {
  required List<PhoneCandidate> candidates,
  required String partyName,
  String? clientId,
  VoidCallback? onViewParty,
  String viewPartyLabelKey = 'view_client',
}) {
  // Re-provided rather than inherited: the picker is a *route*, so its
  // subtree hangs off a `Navigator` that may sit above whatever
  // `Provider<Services>` the caller is under. `ContactLocalTime` reads it, and
  // "providers are scoped to routes" would otherwise make the local-time line
  // throw wherever `Services` isn't installed above `MaterialApp` — same
  // reason `Notify.capture` grabs its host before the first await.
  final services = context.read<Services>();
  Widget body(BuildContext ctx) => Provider<Services>.value(
    value: services,
    child: _PickerBody(
      candidates: candidates,
      partyName: partyName,
      clientId: clientId,
      onViewParty: onViewParty,
      viewPartyLabelKey: viewPartyLabelKey,
    ),
  );

  if (Env.isTouchPrimary) {
    return showModalBottomSheet<PhoneCandidate>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            InSpacing.lg(ctx),
            InSpacing.sm,
            InSpacing.lg(ctx),
            InSpacing.lg(ctx),
          ),
          child: body(ctx),
        ),
      ),
    );
  }
  return showDialog<PhoneCandidate>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: math.min(560, MediaQuery.of(ctx).size.height * 0.85),
        ),
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(ctx)),
          child: body(ctx),
        ),
      ),
    ),
  );
}

class _PickerBody extends StatelessWidget {
  const _PickerBody({
    required this.candidates,
    required this.partyName,
    required this.clientId,
    required this.onViewParty,
    required this.viewPartyLabelKey,
  });

  final List<PhoneCandidate> candidates;
  final String partyName;
  final String? clientId;
  final VoidCallback? onViewParty;
  final String viewPartyLabelKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final call = context.tr('call');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: InSpacing.sm),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  // "Call" alone is a verb with no object, and this is the
                  // surface built to say which party is being rung.
                  partyName.isEmpty ? call : '$call $partyName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Client only. With a null `clientId` the cascade resolves the
              // *company's* zone, which is a fair per-number fallback but
              // becomes a false claim about the vendor's local time once
              // hoisted under "Call <vendor>".
              if (clientId != null) ContactLocalTime(clientId: clientId),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: DetailRowStack(
              children: [
                for (final candidate in candidates)
                  _CandidateRow(candidate: candidate),
              ],
            ),
          ),
        ),
        if (onViewParty != null) ...[
          const SizedBox(height: InSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: contactActionButtonStyle,
              icon: const Icon(Icons.open_in_new, size: 14),
              label: Text(context.tr(viewPartyLabelKey)),
              onPressed: () {
                // Pop first, then navigate with the *button's* context, which
                // `onViewParty` closed over and which stays mounted.
                Navigator.of(context).pop();
                onViewParty!();
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.candidate});

  final PhoneCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final label = candidate.label.isEmpty
        ? context.tr('no_name_fallback')
        : candidate.label;
    return InkWell(
      onTap: () => Navigator.of(context).pop(candidate),
      // Redundant alias for the explicit copy button — a long-press inside a
      // sheet is doubly invisible, so the button is what makes it learnable.
      onLongPress: () => copyToClipboard(context, candidate.phone),
      child: ConstrainedBox(
        // `minHeight`, never a fixed height: a tight box slices Inter Tight's
        // descenders past ~1.14x text scale.
        constraints: BoxConstraints(minHeight: actionButtonSize()),
        child: Row(
          children: [
            Icon(
              // Distinguishes the party's own line, whose label is otherwise
              // identical to the picker's title.
              candidate.isPartyOwnLine
                  ? Icons.business_outlined
                  : Icons.person_outline,
              size: 16,
              color: tokens.ink3,
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      // The same marker the client contacts card uses.
                      if (candidate.isPrimary)
                        Padding(
                          padding: const EdgeInsets.only(left: InSpacing.sm),
                          child: Icon(
                            Icons.star,
                            size: 14,
                            color: tokens.accent,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    candidate.phone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: InSpacing.sm),
            _CopyButton(value: candidate.phone),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final size = actionButtonSize();
    return Tooltip(
      message: context.tr('copy'),
      child: InkWell(
        onTap: () => copyToClipboard(context, value),
        borderRadius: BorderRadius.circular(InRadii.r1),
        child: Semantics(
          button: true,
          label: context.tr('copy'),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.content_copy, size: 14, color: tokens.ink3),
          ),
        ),
      ),
    );
  }
}

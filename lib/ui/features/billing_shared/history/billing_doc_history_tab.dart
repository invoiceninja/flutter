import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/data/services/document_versions_api.dart';
import 'package:admin/data/static/activity_types_catalog.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/party_contacts_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_list_card.dart';
import 'package:admin/ui/features/billing_shared/history/document_version_view_model.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/utils/formatting.dart';

/// The History tab on a billing document's detail screen: every saved version
/// of the document, newest first, each opening that version's PDF.
///
/// Shared by all five document types. Everything entity-specific arrives as a
/// parameter, because the two things a tab normally reads from context are
/// both unreliable here:
///
/// * `FormatterScope` is mounted by only three of the five detail screens —
///   purchase order and recurring invoice thread their `Formatter` by hand —
///   and `Formatter.money` on a null formatter silently renders `''`.
/// * The currency is resolved asynchronously from the *party* row, and it is
///   the **vendor's** on a purchase order. It is not a field on the document.
///
/// See `docs/document-version-history.md` for what the server does and does
/// not store.
class BillingDocHistoryTab extends StatefulWidget {
  const BillingDocHistoryTab({
    super.key,
    required this.api,
    required this.basePath,
    required this.entityId,
    required this.contacts,
    required this.userNames,
    required this.currentAmount,
    required this.currentUpdatedAt,
    required this.onOpenVersion,
    this.formatter,
    this.currencyId,
    this.isVendorParty = false,
    this.selectedActivityId,
    this.showSelection = false,
    this.planBlocksBackups = false,
  });

  final DocumentVersionsApi api;

  /// The entity's collection path, e.g. `/api/v1/invoices`.
  final String basePath;
  final String entityId;

  /// Pre-resolved `contactId → (name, email)` for the document's party, used
  /// to name a portal contact who approved or rejected. Supplied by the
  /// screen via [PartyContactsBuilder] rather than watched here, so one
  /// subscription serves the whole detail screen.
  final PartyContacts contacts;

  /// Pre-resolved `userId → display name` for the company roster, which is
  /// bundled at login and needs no fetch. A map rather than `UserNameLabel`
  /// because the name is one segment of a joined meta string, not a slot.
  final Map<String, String> userNames;

  /// The live document's total and last-modified stamp, for the anchor row.
  final Decimal currentAmount;
  final DateTime? currentUpdatedAt;

  /// Null selects the live document.
  final void Function(String? activityId) onOpenVersion;

  /// Pre-resolved, never read from `FormatterScope` — see the class doc.
  final Formatter? formatter;
  final String? currencyId;

  /// Purchase orders price in the vendor's currency, every other document in
  /// the client's.
  final bool isVendorParty;

  /// Highlighted row, when the wide layout is showing a version in its pane.
  final String? selectedActivityId;

  /// Whether a selection exists to highlight at all.
  ///
  /// False on narrow, where tapping a row *navigates* and nothing ever writes
  /// the notifier — so without this the anchor row would sit permanently
  /// filled and announced `Semantics(selected: true)` on a list where nothing
  /// is selected.
  final bool showSelection;

  /// True when this account's plan produces no backups at all, so the empty
  /// state can say why instead of implying the document was never edited.
  final bool planBlocksBackups;

  @override
  State<BillingDocHistoryTab> createState() => _BillingDocHistoryTabState();
}

class _BillingDocHistoryTabState extends State<BillingDocHistoryTab> {
  late DocumentVersionViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = _build()..kick();
  }

  DocumentVersionViewModel _build() => DocumentVersionViewModel(
    api: widget.api,
    basePath: widget.basePath,
    entityId: widget.entityId,
  );

  @override
  void didUpdateWidget(BillingDocHistoryTab old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId || old.basePath != widget.basePath) {
      _vm.dispose();
      _vm = _build()..kick();
      return;
    }
    // A save writes a new server-side version, but this tab's State outlives
    // an edit round trip (the edit route is a child, so the detail page stays
    // mounted underneath). Without this the list keeps the old rows while the
    // Current row's amount — which comes from the watched entity — updates,
    // so the card visibly contradicts itself.
    if (old.currentUpdatedAt != widget.currentUpdatedAt) {
      unawaited(_vm.refresh());
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Padding → Column(min) → card, not a ListView: `EntityDetailTabs` bodies
    // grow to their intrinsic height inside the detail screen's own
    // scroll view, where an unbounded-height viewport throws.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => ActivityListCard(child: _body(context)),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final error = _vm.error;
    if (error != null && _vm.versions.isEmpty) {
      return ErrorView(
        // The server's own message survives here, which matters for the one
        // 404 on this API that is a real data condition rather than a bad
        // URL: "No backup exists for this activity".
        message: context.tr('failed_to_load_with_error', {
          'error': formatNotifyError(error),
        }),
        onRetry: _vm.refresh,
      );
    }
    // `isLoading`, not just `hasLoaded`: `refresh()` clears the error
    // synchronously while `_loaded` is still true from the failed attempt, so
    // gating on `hasLoaded` alone drops a retry straight into the empty state
    // and asserts the document has no history for the whole round trip — the
    // normal retry experience on a slow link.
    if (!_vm.hasLoaded || (_vm.isLoading && _vm.versions.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_vm.versions.isEmpty) return _emptyState(context);

    final rows = <Widget>[
      _CurrentVersionRow(
        amount: widget.currentAmount,
        updatedAt: widget.currentUpdatedAt,
        formatter: widget.formatter,
        currencyId: widget.currencyId,
        isVendorParty: widget.isVendorParty,
        selected: widget.showSelection && widget.selectedActivityId == null,
        onTap: () => widget.onOpenVersion(null),
      ),
    ];
    for (var i = 0; i < _vm.versions.length; i++) {
      final version = _vm.versions[i];
      // The predecessor is the next row down (the list is newest-first). The
      // OLDEST row deliberately gets none: its real predecessor may exist on
      // the server beyond the 50-activity window, so a delta there would be
      // measured against a version we simply do not hold.
      final previous = i + 1 < _vm.versions.length
          ? _vm.versions[i + 1].amount
          : null;
      rows.add(
        _VersionRow(
          version: version,
          previousAmount: previous,
          contacts: widget.contacts,
          userNames: widget.userNames,
          formatter: widget.formatter,
          currencyId: widget.currencyId,
          isVendorParty: widget.isVendorParty,
          isLast: i == _vm.versions.length - 1 && !_vm.truncated,
          selected:
              widget.showSelection &&
              widget.selectedActivityId == version.activityId,
          onTap: () => widget.onOpenVersion(version.activityId),
        ),
      );
    }
    if (_vm.truncated) rows.add(const _TruncationFooter());

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _emptyState(BuildContext context) {
    if (widget.planBlocksBackups) {
      // The server skips `createBackup()` entirely for a free or lapsed
      // hosted account, so this list can never fill. Saying "no records"
      // there would be a confident falsehood.
      // NOT `PlanGateBanner`: it self-hides on `hasProAccess`, which is
      // trial-aware, while the gate that got us here is slug-only — matching
      // the server's `isFreeHostedClient()`, which has no trial branch. A
      // trialing user would therefore read "available on a paid plan" with
      // the CTA silently gone, and `EmptyState` would still reserve the 24px
      // gap in front of it.
      return EmptyState(
        icon: Icons.layers_outlined,
        title: context.tr('history'),
        subtitle: context.tr('document_history_requires_plan'),
        action: FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => unawaited(openUpgradeFlow(context)),
          child: Text(context.tr('upgrade')),
        ),
      );
    }
    return EmptyState(
      icon: Icons.layers_outlined,
      // NOT `no_history`: fr.json carries that key as Greek and zh_CN as
      // English, and `_app_pending.json` can only add a key, never override a
      // present-but-wrong locale value.
      // The unsynced sentence goes in the *subtitle*, like every other empty
      // state — it is a sentence, and `title` renders at `titleMedium`.
      title: context.tr('no_records_found'),
      subtitle: context.tr(
        _vm.isUnsyncedRecord
            ? 'sync_first_generic'
            : 'document_history_explainer',
      ),
    );
  }
}

/// Money for a version row, honouring the vendor/client split.
String _money(
  Decimal amount, {
  required Formatter? formatter,
  required String? currencyId,
  required bool isVendorParty,
  bool zeroIsNull = false,
}) =>
    formatter?.money(
      amount,
      clientCurrencyId: isVendorParty ? null : currencyId,
      vendorCurrencyId: isVendorParty ? currencyId : null,
      zeroIsNull: zeroIsNull,
    ) ??
    '';

/// Absolute timestamp, plus a relative one while the event is fresh.
///
/// The UTC instant is handed to `Formatter.date` **unconverted** on the
/// `showTime: true` branch — that branch localizes itself, and a pre-localized
/// value would be offset twice.
String _timestamp(BuildContext context, DateTime at, Formatter? formatter) {
  final absolute =
      formatter?.date(
        at.toIso8601String(),
        showTime: true,
        showSeconds: false,
      ) ??
      at.toIso8601String();
  final elapsed = DateTime.now().difference(at);
  if (elapsed.isNegative || elapsed.inHours >= 24) return absolute;
  return '$absolute · ${formatRelativeTime(context, elapsed)}';
}

/// Shared chrome for both row kinds: badge, two text lines, chevron, hover.
class _HistoryRowShell extends StatefulWidget {
  const _HistoryRowShell({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.meta,
    required this.semanticsLabel,
    required this.onTap,
    required this.isLast,
    required this.selected,
    this.trailingTitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? trailingTitle;
  final String meta;
  final String semanticsLabel;
  final VoidCallback onTap;
  final bool isLast;
  final bool selected;

  @override
  State<_HistoryRowShell> createState() => _HistoryRowShellState();
}

class _HistoryRowShellState extends State<_HistoryRowShell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);

    final titleRow = Row(
      children: [
        Flexible(
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (widget.trailingTitle != null) ...[
          const SizedBox(width: 6),
          // Plain ink, never a paid/overdue tint: a total going up is not
          // good news and going down is not bad, and those two colours are
          // already semantic on this screen.
          Text(
            widget.trailingTitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.iconBg,
              borderRadius: BorderRadius.circular(InRadii.r2),
            ),
            child: Icon(widget.icon, size: 16, color: widget.iconFg),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleRow,
                const SizedBox(height: 2),
                Text(
                  widget.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.ink3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // No hand-mirroring for RTL — `chevron_right` declares
          // `matchTextDirection: true`.
          Icon(Icons.chevron_right, size: 16, color: tokens.ink3),
        ],
      ),
    );

    // `MaterialType.transparency`, and *inside* the decorated box: the nearest
    // ancestor Material sits above `ActivityListCard`'s opaque fill, so an ink
    // feature registered there paints under the card and is invisible.
    final tappable = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.onTap,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) return tokens.border;
          if (states.contains(WidgetState.focused)) return tokens.surfaceAlt;
          return Colors.transparent;
        }),
        child: content,
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: ConstrainedBox(
        // A floor, never a fixed height: a fixed one clamps the label's line
        // box and slices descenders at large text scale.
        constraints: const BoxConstraints(minHeight: kEntityListRowHeight),
        child: Container(
          decoration: BoxDecoration(
            color: widget.selected
                ? tokens.accentSoft
                : (_hovered ? tokens.surfaceAlt : null),
            border: widget.isLast
                ? null
                : Border(bottom: BorderSide(color: tokens.border)),
          ),
          // `onTap` and `button` are re-declared over the exclusion: excluding
          // the subtree drops `InkResponse`'s own `Semantics(onTap:)`, which
          // is where the tap action lives — without it the row announces as a
          // button that TalkBack and switch access cannot invoke.
          child: Semantics(
            button: true,
            selected: widget.selected,
            label: widget.semanticsLabel,
            onTap: widget.onTap,
            child: ExcludeSemantics(child: tappable),
          ),
        ),
      ),
    );
  }
}

/// The live document — the anchor the deltas are measured back from, and the
/// only way back to "now" once a version is open.
class _CurrentVersionRow extends StatelessWidget {
  const _CurrentVersionRow({
    required this.amount,
    required this.updatedAt,
    required this.formatter,
    required this.currencyId,
    required this.isVendorParty,
    required this.selected,
    required this.onTap,
  });

  final Decimal amount;
  final DateTime? updatedAt;
  final Formatter? formatter;
  final String? currencyId;
  final bool isVendorParty;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final title = context.tr('current_version');
    final money = _money(
      amount,
      formatter: formatter,
      currencyId: currencyId,
      isVendorParty: isVendorParty,
    );
    final at = updatedAt;
    final meta = [
      if (money.isNotEmpty) money,
      if (at != null) _timestamp(context, at, formatter),
    ].join(' · ');
    return _HistoryRowShell(
      icon: Icons.layers_outlined,
      // `surface`, not `accentSoft`: this row's own selected background is
      // `accentSoft`, so a matching badge disappears into it in the default
      // state — which is the state it is in most of the time.
      iconBg: tokens.surface,
      iconFg: tokens.accent,
      title: title,
      meta: meta,
      semanticsLabel: '$title $meta',
      onTap: onTap,
      isLast: false,
      selected: selected,
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.version,
    required this.previousAmount,
    required this.contacts,
    required this.userNames,
    required this.formatter,
    required this.currencyId,
    required this.isVendorParty,
    required this.isLast,
    required this.selected,
    required this.onTap,
  });

  final DocumentVersion version;
  final Decimal? previousAmount;
  final PartyContacts contacts;
  final Map<String, String> userNames;
  final Formatter? formatter;
  final String? currencyId;
  final bool isVendorParty;
  final bool isLast;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final typeId = int.tryParse(version.activityTypeId) ?? 0;
    final tone = activityToneFor(typeId);
    final (bg, fg) = activityToneColors(tokens, tone);

    // `kActivityTypeLabelKeys`, not `buildActivitySpans`: the templated
    // sentences substitute `:token`s from `Activity.refs`, which this payload
    // does not carry, so `activity_5` would render as the literal
    // "User updated invoice Invoice". These short labels are already
    // user-facing in the Reports activity filter, so they cost no new strings.
    final labelKey = kActivityTypeLabelKeys[typeId];
    final title = labelKey != null
        ? context.tr(labelKey)
        // `:id`, matching the key's own placeholder — `activity_description`
        // and `activity_formatter` both spell it that way. A mismatched name
        // substitutes nothing and prints the raw token.
        : context.tr('activity_unknown', {'id': '$typeId'});

    final delta = _delta(context);
    final meta = [
      _actor(context),
      _timestamp(context, version.createdAt, formatter),
    ].where((s) => s.isNotEmpty).join(' · ');

    return _HistoryRowShell(
      icon: activityIconFor(tone),
      iconBg: bg,
      iconFg: fg,
      title: title,
      trailingTitle: delta,
      meta: meta,
      semanticsLabel: [title, delta, meta].whereType<String>().join(' '),
      onTap: onTap,
      isLast: isLast,
      selected: selected,
    );
  }

  /// The change in the document's total since the previous version.
  ///
  /// **Blank when nothing moved.** Most events — mark sent, archive, restore,
  /// a reminder — leave the total alone, and this is an unlabelled slot, so a
  /// column of `$0.00` down the list would claim a change that did not happen.
  /// A blank delta is itself the signal.
  String? _delta(BuildContext context) {
    final previous = previousAmount;
    if (previous == null) return null;
    final diff = version.amount - previous;
    final text = _money(
      diff,
      formatter: formatter,
      currencyId: currencyId,
      isVendorParty: isVendorParty,
      zeroIsNull: true,
    );
    if (text.isEmpty) return null;
    // `Formatter.money` already emits an ASCII `-`; match it rather than
    // mixing in a typographic minus.
    return diff > Decimal.zero ? '+$text' : text;
  }

  /// Who made the change.
  ///
  /// Never an em dash for an unresolved id: an edit *was* made by somebody, so
  /// this follows `UserAvatar`'s rule rather than `UserNameLabel`'s. A portal
  /// contact is checked before the user, because an approval or rejection from
  /// the other side is the change users least expect to find.
  String _actor(BuildContext context) {
    if (version.isSystem) return context.tr('system');
    if (version.contactId.isNotEmpty) {
      return partyContactLabel(
        contacts,
        version.contactId,
        fallback: context.tr('contact'),
      );
    }
    if (version.userId.isNotEmpty) {
      final name = userNames[version.userId];
      return (name != null && name.isNotEmpty) ? name : context.tr('user');
    }
    return '';
  }
}

/// Names the server's 50-activity window rather than letting the list imply it
/// is complete. `Invoice::activities()` is `->take(50)` with no pagination.
class _TruncationFooter extends StatelessWidget {
  const _TruncationFooter();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: 12,
      ),
      child: Text(
        // No count: the server's window is 50 *activities*, and filtering
        // then drops backup-less rows and view events — so naming a number
        // here would claim "50 versions" above a three-row list.
        context.tr('document_history_truncated'),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
      ),
    );
  }
}

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/entity_links.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recent_record.dart';
import 'package:admin/data/models/domain/search_result.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';

/// Search-result group key for a pasted record deep link. Renders as its own
/// header via `context.tr` — `link` is an existing translated key.
const String kDeepLinkSearchGroup = 'link';

/// A record deep link the user pasted into the palette, as a single hit — or
/// null when [query] isn't one.
///
/// This is the only way to follow a shared link on **web and Linux**, where
/// the OS never hands the app a custom-scheme URI, and the fallback anywhere a
/// messenger renders `invoiceninja://…` as inert text rather than a tappable
/// link. Pure + unit-tested.
SearchResult? deepLinkSearchHit(String query, EntityRegistry registry) {
  final raw = query.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final target = parseAppDeepLink(uri, registry);
  if (target == null) return null;
  // `path` carries the ORIGINAL uri, not the resolved route: activation hands
  // it back to `DeepLinkRouter` so a cross-company link still switches company
  // (the resolved route alone has no company on it).
  return SearchResult(
    group: kDeepLinkSearchGroup,
    name: target.path,
    id: '',
    path: raw,
  );
}

/// Maps a `POST /api/v1/search` response group key to an [EntityType] so
/// the hit routes through the entity registry (module-enabled + permission
/// gated). `settings` (and any unknown group) → null: the caller falls
/// back to the server-supplied `path`. Pure + unit-tested.
EntityType? entityTypeForSearchGroup(String group) {
  switch (group) {
    case 'clients':
    case 'client_contacts':
      return EntityType.client;
    case 'invoices':
      return EntityType.invoice;
    case 'quotes':
      return EntityType.quote;
    case 'credits':
      return EntityType.credit;
    case 'payments':
      return EntityType.payment;
    case 'recurrings':
    case 'recurring_invoices':
      return EntityType.recurringInvoice;
    case 'projects':
      return EntityType.project;
    case 'tasks':
      return EntityType.task;
    case 'products':
      return EntityType.product;
    case 'expenses':
      return EntityType.expense;
    case 'vendors':
    case 'vendor_contacts':
      return EntityType.vendor;
    case 'purchase_orders':
      return EntityType.purchaseOrder;
    default:
      return null; // settings + anything unknown → use server path
  }
}

/// Groups whose row describes a **contact**, not the record it routes to.
///
/// `SearchController::mapResults` puts the CONTACT's `hashed_id` in `id` and
/// the parent in `path` (`/clients/{client_id}`), so routing by `id` opens a
/// client/vendor that doesn't exist — the detail screen resolves nothing and
/// renders its empty state. Only the Elasticsearch branch does this; the
/// non-ES `clientMap` fallback happens to put the parent id in BOTH fields, so
/// reading the parent out of `path` is correct on either backend.
const _contactGroups = {'client_contacts', 'vendor_contacts'};

/// The id to route a hit by: the parent's id for a contact row (parsed out of
/// the server `path`), otherwise the hit's own `id`.
///
/// Falls back to `id` when `path` is empty or has no trailing segment, so an
/// unexpected server shape degrades to today's behavior rather than to nothing.
String recordIdForSearchHit(SearchResult r) {
  if (!_contactGroups.contains(r.group)) return r.id;
  final segments = Uri.parse(
    r.path,
  ).pathSegments.where((s) => s.isNotEmpty).toList();
  return segments.isEmpty ? r.id : segments.last;
}

/// Cmd/Ctrl+/ global command palette. Server-backed search
/// (`SearchApi`) across all entities + settings; arrow/enter/escape
/// keyboard nav; selection routes via the entity registry (or the
/// server path for settings).
Future<void> showCommandPalette(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (ctx) {
      final tokens = ctx.inTheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(
          top: 120,
          left: 24,
          right: 24,
          bottom: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 520),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(InRadii.r4),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surface.withValues(alpha: isDark ? 0.86 : 0.92),
                  border: Border.all(
                    color: tokens.border.withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(InRadii.r4),
                  boxShadow: tokens.shadow2,
                ),
                child: const _CommandPalette(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette();

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _selRowKey = GlobalKey();
  Timer? _debounce;
  List<SearchResult> _results = const [];
  bool _loading = false;
  int _selected = 0;
  int _reqSeq = 0;

  /// Snapshot of the recently-viewed list, read once per build. Surfaced as
  /// the "Recent" group while the query is empty — the same Cmd+K surface,
  /// no separate drawer to discover.
  List<RecentRecord> _recents = const [];

  /// True when the palette is at rest (no query, no results) and there are
  /// recents to show — keyboard nav + Enter then operate on [_recents].
  bool get _recentMode =>
      !_loading &&
      _results.isEmpty &&
      _controller.text.trim().isEmpty &&
      _recents.isNotEmpty;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Keeps the keyboard/hover selection visible after [_move] or a
  /// fresh result set. Runs post-frame so [_selRowKey] is attached.
  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selRowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(q));
  }

  Future<void> _run(String q) async {
    final seq = ++_reqSeq;
    // A pasted deep link resolves locally — no round-trip, and no other hit
    // could be what the user meant.
    final link = deepLinkSearchHit(q, context.read<Services>().entityRegistry);
    if (link != null) {
      setState(() {
        _results = [link];
        _selected = 0;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await context.read<Services>().search.search(q);
      if (!mounted || seq != _reqSeq) return;
      // Server `settings` hits are dropped in favour of the local catalog —
      // see [_localSettingsHits]. Everything else routes by entity group.
      final merged = [
        ...r.where((hit) => !hit.isSettings),
        ..._localSettingsHits(q),
      ];
      setState(() {
        _results = merged;
        _selected = 0;
        _loading = false;
      });
      _revealSelected();
    } catch (_) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  /// Settings hits, served from the app's own catalog instead of the server's.
  ///
  /// `POST /api/v1/search` builds its `settings` group from `settingsMap($user)`,
  /// which never sees the query — it returns the WHOLE catalogue (~92 rows) on
  /// every request and expects the client to filter. Worse, those rows carry
  /// React web routes (`/settings/subscriptions`, `…/create`,
  /// `/settings/user_details/accent_color`, …); ~19 of them match no route
  /// here, and `errorBuilder` is registered at the ROOT, so selecting one
  /// replaced the entire app — sidebar included — with the route-error screen.
  ///
  /// `kSettingsSearchCatalog` is route-correct by construction (a consistency
  /// test binds it to the real screens), so this filters properly, never
  /// dead-ends, and works offline. Gating mirrors the settings screen's own
  /// search (`settings_screen.dart`) so a module-disabled or admin-only page
  /// can't surface as a dead link.
  ///
  /// Navigates to the section root rather than the exact tab: catalog entries
  /// carry no per-field route, and this matches in-app settings search.
  List<SearchResult> _localSettingsHits(String query) {
    // An empty query must stay empty — `searchSettings('')` returns the full
    // catalogue by design, which would bury the Recents resting state.
    if (query.trim().isEmpty) return const [];
    final l10n = Localization.of(context);
    if (l10n == null) return const [];
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final me = session?.currentCompany;
    final modules = me?.enabledModules ?? 0;
    final isAdminOrOwner = me?.isAdmin == true || me?.isOwner == true;
    // Fail open on a not-yet-loaded session, matching the settings screen.
    final isHosted = session?.isHosted ?? true;
    final level = services.settingsLevel;
    final isCascade = level.isClient || level.isGroup;
    return [
      for (final hit in searchSettings(query, l10n))
        if ((!isCascade || hit.section.clientEditable) &&
            hit.section.isVisibleFor(modules) &&
            (!hit.section.adminOnly || isAdminOrOwner) &&
            (isHosted || !kHostedOnlySettingsFields.contains(hit.fieldKey)))
          SearchResult(
            group: 'settings',
            name: l10n.lookup(hit.fieldKey),
            id: '',
            path: hit.section.route,
          ),
    ];
  }

  void _move(int delta) {
    final n = _recentMode ? _recents.length : _results.length;
    if (n == 0) return;
    setState(() {
      _selected = (_selected + delta) % n;
      if (_selected < 0) _selected += n;
    });
    _revealSelected();
  }

  Future<void> _select() async {
    // The palette navigates away from whatever is on screen, so it owes the
    // same unsaved-changes prompt the sidebar / branch switcher gives. Without
    // it, a dirty editor was left behind unprompted and then tripped the guard
    // later, on an unrelated (clean) screen.
    final services = context.read<Services>();
    if (_recentMode) {
      if (_selected < 0 || _selected >= _recents.length) return;
      final r = _recents[_selected];
      if (!await services.unsavedChangesGuard.confirmIfDirty(context)) return;
      if (!mounted) return;
      Navigator.of(context).pop();
      goEntityRecord(context, r.type, r.id);
      return;
    }
    if (_selected < 0 || _selected >= _results.length) return;
    final r = _results[_selected];
    if (!await services.unsavedChangesGuard.confirmIfDirty(context)) return;
    if (!mounted) return;
    Navigator.of(context).pop();
    if (r.group == kDeepLinkSearchGroup) {
      // Back through the same choreography an OS-delivered link gets, so a
      // pasted cross-company link switches company before it navigates.
      unawaited(services.deepLinks.open(Uri.parse(r.path)));
      return;
    }
    final type = entityTypeForSearchGroup(r.group);
    final recordId = recordIdForSearchHit(r);
    if (type != null && recordId.isNotEmpty) {
      goEntityRecord(context, type, recordId);
    } else if (r.path.isNotEmpty) {
      context.go(r.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = context.read<Services>();
    final registry = services.entityRegistry;
    _recents = services.recentlyViewed.items;
    final hasResults = _results.isNotEmpty;
    final resting =
        !_loading && _results.isEmpty && _controller.text.trim().isEmpty;
    final showRecent = resting && _recents.isNotEmpty;

    // Flatten the (already group-ordered) results into a render list:
    // a String marks a category header, an int indexes into _results.
    final items = <Object>[];
    String? lastGroup;
    for (var i = 0; i < _results.length; i++) {
      final g = _results[i].group;
      if (g != lastGroup) {
        items.add(g);
        lastGroup = g;
      }
      items.add(i);
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.go,
            onChanged: _onChanged,
            onSubmitted: (_) => _select(),
            style: TextStyle(fontSize: 22, color: tokens.ink),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, size: 26, color: tokens.ink3),
              hintText: context.tr('search'),
              hintStyle: TextStyle(fontSize: 22, color: tokens.ink3),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KeyCap(
                      label: '${platformModifierLabel()}/',
                      color: tokens.ink3,
                    ),
                  ],
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
            ),
          ),
          if (!resting) ...[
            Container(height: 1, color: tokens.border.withValues(alpha: 0.6)),
            SizedBox(
              height: 2,
              child: _loading
                  ? const LinearProgressIndicator(minHeight: 2)
                  : null,
            ),
            Flexible(
              child: hasResults
                  ? ListView.builder(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        if (item is String) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                            child: Text(
                              context.tr(item),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: tokens.ink3,
                              ),
                            ),
                          );
                        }
                        final i = item as int;
                        final r = _results[i];
                        final sel = i == _selected;
                        final type = entityTypeForSearchGroup(r.group);
                        final icon = r.group == kDeepLinkSearchGroup
                            ? Icons.link
                            : (type != null
                                      ? registry[type]?.effectiveOutlinedIcon
                                      : null) ??
                                  Icons.settings_outlined;
                        return MouseRegion(
                          onEnter: (_) {
                            if (_selected != i) {
                              setState(() => _selected = i);
                            }
                          },
                          child: Semantics(
                            button: true,
                            selected: sel,
                            label: r.name,
                            child: Padding(
                              key: sel ? _selRowKey : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() => _selected = i);
                                  _select();
                                },
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? tokens.accentSoft
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      InRadii.r2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          icon,
                                          size: 20,
                                          color: sel
                                              ? tokens.accentInk
                                              : tokens.ink2,
                                        ),
                                        SizedBox(width: InSpacing.md(context)),
                                        Expanded(
                                          child: Text(
                                            r.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Center(
                        child: Text(
                          context.tr('no_records_found'),
                          style: TextStyle(color: tokens.ink3),
                        ),
                      ),
                    ),
            ),
            Container(height: 1, color: tokens.border.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DefaultTextStyle(
                style: TextStyle(fontSize: 11, color: tokens.ink3),
                child: const Row(
                  children: [
                    Text('↑↓'),
                    Text('   ·   '),
                    Text('↵'),
                    Text('   ·   '),
                    Text('esc'),
                  ],
                ),
              ),
            ),
          ],
          if (showRecent) ...[
            Container(height: 1, color: tokens.border.withValues(alpha: 0.6)),
            Flexible(
              child: ListView(
                controller: _scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      context.tr('recently_viewed'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: tokens.ink3,
                      ),
                    ),
                  ),
                  for (var i = 0; i < _recents.length; i++)
                    Builder(
                      builder: (context) {
                        final r = _recents[i];
                        final sel = i == _selected;
                        final icon =
                            registry[r.type]?.effectiveOutlinedIcon ??
                            Icons.history;
                        return MouseRegion(
                          onEnter: (_) {
                            if (_selected != i) {
                              setState(() => _selected = i);
                            }
                          },
                          child: Semantics(
                            button: true,
                            selected: sel,
                            label: r.label,
                            child: Padding(
                              key: sel ? _selRowKey : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() => _selected = i);
                                  _select();
                                },
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? tokens.accentSoft
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(
                                      InRadii.r2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          icon,
                                          size: 20,
                                          color: sel
                                              ? tokens.accentInk
                                              : tokens.ink2,
                                        ),
                                        SizedBox(width: InSpacing.md(context)),
                                        Expanded(
                                          child: Text(
                                            r.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: tokens.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Container(height: 1, color: tokens.border.withValues(alpha: 0.6)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DefaultTextStyle(
                style: TextStyle(fontSize: 11, color: tokens.ink3),
                child: const Row(
                  children: [
                    Text('↑↓'),
                    Text('   ·   '),
                    Text('↵'),
                    Text('   ·   '),
                    Text('esc'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

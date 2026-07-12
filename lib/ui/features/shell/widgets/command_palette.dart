import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recent_record.dart';
import 'package:admin/data/models/domain/search_result.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';

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
    default:
      return null; // settings + anything unknown → use server path
  }
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
    setState(() => _loading = true);
    try {
      final r = await context.read<Services>().search.search(q);
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _results = r;
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

  void _move(int delta) {
    final n = _recentMode ? _recents.length : _results.length;
    if (n == 0) return;
    setState(() {
      _selected = (_selected + delta) % n;
      if (_selected < 0) _selected += n;
    });
    _revealSelected();
  }

  void _select() {
    if (_recentMode) {
      if (_selected < 0 || _selected >= _recents.length) return;
      final r = _recents[_selected];
      Navigator.of(context).pop();
      goEntityRecord(context, r.type, r.id);
      return;
    }
    if (_selected < 0 || _selected >= _results.length) return;
    final r = _results[_selected];
    Navigator.of(context).pop();
    final type = entityTypeForSearchGroup(r.group);
    if (type != null && r.id.isNotEmpty) {
      goEntityRecord(context, type, r.id);
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
                        final icon =
                            (type != null
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

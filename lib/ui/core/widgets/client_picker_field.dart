import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/escape_observer.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_edit_field_decoration.dart';

/// Searchable client picker with an inline "create client" affordance.
///
/// Deliberately **not** built on [SearchableDropdownField], for two reasons
/// that are both silent failures rather than compile errors:
///
///  1. Flutter's `RawAutocomplete` only mounts its options overlay while the
///     option list is non-empty (`_canShowOptionsView`, `autocomplete.dart`),
///     so that widget's `footerBuilder` is unreachable for a name that matches
///     nothing — the one case inline-create exists for. This widget keeps the
///     list non-empty by always appending a synthetic create row (the same
///     trick the desktop line-item product picker uses).
///  2. `SearchableDropdownField` renders a *disabled* placeholder when its
///     item list is empty, so a company with no clients yet — the account that
///     most needs "create" — would get a dead field.
///
/// It also owns its committed [Client] rather than deriving it from a
/// caller-supplied `initialValue`. A just-created client carries a `tmp_` id
/// and isn't in the Drift watch stream yet, so a stream-derived selection
/// would render blank for a frame or two after the create.
///
/// Layering: this reads [Services] (as other `core/widgets` entries do) but
/// takes the create UI as an injected callback, so `core/` never imports a
/// feature package.
class ClientPickerField extends StatefulWidget {
  const ClientPickerField({
    super.key,
    required this.companyId,
    required this.selectedClientId,
    required this.onSelected,
    this.label,
    this.errorText,
    this.enabled = true,
    this.onCreateRequested,
  });

  final String companyId;

  /// Id only — the widget resolves the [Client] itself and caches it, so a
  /// `tmp_` client stays visible until the watch stream catches up.
  final String selectedClientId;

  final ValueChanged<Client?> onSelected;

  /// Resolved (already-translated) label. Defaults to `tr('client')`.
  final String? label;

  /// Server-side validation error to surface beneath the field.
  final String? errorText;

  final bool enabled;

  /// Opens the create UI seeded with the typed text and resolves to the
  /// created client (already written to Drift) or null if cancelled. Null
  /// hides the affordance entirely — ANDed with the `create_client`
  /// permission check.
  final Future<Client?> Function(BuildContext context, String initialName)?
  onCreateRequested;

  @override
  State<ClientPickerField> createState() => _ClientPickerFieldState();
}

/// Display label for a client row.
///
/// Falls through to the primary contact because a just-created client has no
/// server-computed `display_name`, and an inline create may have collected
/// only a contact name — without the fallback its row renders blank.
String clientPickerLabel(Client c) {
  if (c.displayName.isNotEmpty) return c.displayName;
  if (c.name.isNotEmpty) return c.name;
  for (final contact in c.contacts) {
    final full = [
      contact.firstName,
      contact.lastName,
    ].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    if (contact.email.isNotEmpty) return contact.email;
  }
  return c.id;
}

sealed class _ClientOption {}

class _ClientExisting implements _ClientOption {
  _ClientExisting(this.client);
  final Client client;
}

class _ClientCreate implements _ClientOption {
  _ClientCreate(this.query);

  /// The trimmed text typed so far. Empty renders a plain "New Client" row.
  final String query;
}

class _ClientPickerFieldState extends State<ClientPickerField> {
  static const double _optionExtent = 40.0;
  static const int _idleResults = 20;
  static const int _maxResults = 50;
  static const Duration _searchDebounce = Duration(milliseconds: 280);

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ScrollController _optionsScroll = ScrollController();

  /// Resolves the *selected* client by id, independently of whatever the
  /// current query happens to match — otherwise a document whose client sorts
  /// outside the search results renders a blank field.
  StreamSubscription<Client?>? _selectedWatch;
  Timer? _warmTimer;

  /// Supersede guard: an older async `optionsBuilder` run must not overwrite a
  /// newer one's results.
  int _searchSeq = 0;

  Client? _committed;
  bool _creating = false;
  bool _searching = false;
  bool _suppressBlurSnap = false;
  bool _canCreateClients = false;
  bool _wired = false;

  /// The live highlight from the options overlay. Captured as the *notifier*
  /// rather than its value: `AutocompleteHighlightedOption` is an
  /// `InheritedNotifier`, so a build-captured index lags a frame behind the
  /// arrow keys and an Enter in the same event batch would act on the wrong
  /// row.
  ValueNotifier<int>? _highlight;
  int _optionCount = 0;

  /// True while the options overlay is mounted. Cleared on blur, on commit,
  /// and on Escape — Flutter's `DismissIntent` hides the overlay *without*
  /// touching focus, so nothing else would notice.
  bool _optionsVisible = false;

  bool get _showCreate =>
      widget.onCreateRequested != null && _canCreateClients && widget.enabled;

  /// The create row is always last, so this is the only index it can hold.
  bool get _highlightIsCreateRow =>
      _showCreate &&
      _optionsVisible &&
      _optionCount > 0 &&
      (_highlight?.value ?? 0) == _optionCount - 1;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    _readPermission();
    _watchSelected();
  }

  /// Admin / owner bypass and `create_all` expansion are handled inside `can`.
  /// Re-read on a company switch — permissions are per company-user.
  void _readPermission() {
    _canCreateClients =
        context.read<Services>().auth.session.value?.currentCompany?.can(
          'create_client',
        ) ??
        false;
  }

  /// Track the selected client by id. Independent of the query, so a client
  /// that no current search would return still renders in the field —
  /// otherwise opening a document whose client sits outside the first page
  /// shows an empty Client field on a document that has one.
  void _watchSelected() {
    _selectedWatch?.cancel();
    _selectedWatch = null;
    final id = widget.selectedClientId;
    if (id.isEmpty) {
      _committed = null;
      _syncTextIfIdle();
      return;
    }
    if (_committed != null && _committed!.id != id) {
      // Drop the stale name immediately; the watch fills in the real one.
      _committed = null;
      _syncTextIfIdle();
    }
    _selectedWatch = context
        .read<Services>()
        .clients
        .watch(companyId: widget.companyId, id: id)
        .listen((client) {
          if (!mounted || client == null) return;
          setState(() => _committed = client);
          _syncTextIfIdle();
        });
  }

  @override
  void didUpdateWidget(ClientPickerField old) {
    super.didUpdateWidget(old);
    final companyChanged = old.companyId != widget.companyId;
    if (companyChanged) {
      // Permissions are per company-user, so the create affordance must be
      // re-evaluated — not left reflecting the previous company.
      _readPermission();
      _committed = null;
      _syncTextIfIdle();
    }
    if (!companyChanged && old.selectedClientId == widget.selectedClientId) {
      return;
    }
    // We just committed this ourselves (including a `tmp_` client that hasn't
    // synced yet) — leave the field text alone.
    if (!companyChanged && widget.selectedClientId == (_committed?.id ?? '')) {
      return;
    }
    _watchSelected();
  }

  void _syncTextIfIdle() {
    // Never yank the caret mid-edit, and never fight the dialog for the text.
    if (_focusNode.hasFocus || _creating) return;
    final want = _committed == null ? '' : clientPickerLabel(_committed!);
    if (_controller.text != want) _controller.text = want;
  }

  void _onFocusChange() {
    _optionsVisible = false;
    if (_focusNode.hasFocus) return;
    if (_suppressBlurSnap) return;
    // Snap back to the committed client so half-typed text can't linger in a
    // field whose value is an id.
    _syncTextIfIdle();
  }

  /// Local rows for [query], narrowed by the SAME query the server fetch uses.
  /// Reading through an unfiltered window instead would defeat the whole
  /// point: rows the fetch just landed would still fall outside it.
  Future<List<Client>> _localClients(String query) => context
      .read<Services>()
      .clients
      .watchPage(
        companyId: widget.companyId,
        search: query.isEmpty ? null : query,
        loadedPages: 1,
      )
      .first;

  /// Warm the next keystroke's local results without blocking this one.
  void _scheduleWarmFetch(String query) {
    _warmTimer?.cancel();
    if (query.isEmpty) return;
    _warmTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      unawaited(_fetch(query));
    });
  }

  Future<bool> _fetch(String query) => context
      .read<Services>()
      .clients
      .ensurePageLoaded(companyId: widget.companyId, page: 1, search: query)
      .catchError((_) => false);

  /// True while the field still shows the committed client's own name — the
  /// user has typed nothing, so there is no query.
  bool _isPristine(String query) {
    final committed = _committed;
    if (committed == null) return query.isEmpty;
    return query == clientPickerLabel(committed).trim();
  }

  /// Reopen the options on a tap that isn't editing anything.
  ///
  /// `RawAutocomplete` recomputes only when the field TEXT changes, so a tap
  /// after a selection (focus never left) reopens nothing. Bounce the value
  /// through a different string and back in the same frame — the newer build
  /// supersedes the older and the visible text never changes. Guarded on
  /// [_isPristine] so it can't clobber a half-typed query or an in-flight
  /// create.
  void _reopenOptions() {
    if (_creating || !widget.enabled) return;
    if (!_isPristine(_controller.text.trim())) return;
    if (_controller.value.isComposingRangeValid) return;
    final text = _controller.text;
    _controller.value = TextEditingValue(text: text.isEmpty ? ' ' : '');
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  }

  /// Options for [query]: local rows first, and when nothing matches locally
  /// ask the server before concluding the client doesn't exist. Without that
  /// round-trip a large account silently offers "create" for a client it
  /// already has, which is how duplicates get made.
  Future<Iterable<_ClientOption>> _buildOptions(String rawQuery) async {
    if (!widget.enabled) return const <_ClientOption>[];
    // Searching for the committed client's own name would offer only that one
    // client back — the value the user already has — so tapping a populated
    // field would look broken (invoiceninja/flutter#34, same defect as
    // `SearchableDropdownField`). An untouched field means "show me the list".
    final query = _isPristine(rawQuery) ? '' : rawQuery;
    final seq = ++_searchSeq;
    var rows = await _localClients(query);
    if (!mounted || seq != _searchSeq) return const <_ClientOption>[];

    if (query.isNotEmpty && rows.isEmpty) {
      setState(() => _searching = true);
      await _fetch(query);
      if (!mounted || seq != _searchSeq) return const <_ClientOption>[];
      rows = await _localClients(query);
      if (!mounted || seq != _searchSeq) return const <_ClientOption>[];
      setState(() => _searching = false);
    } else if (query.isNotEmpty) {
      _scheduleWarmFetch(query);
    }

    final limit = query.isEmpty ? _idleResults : _maxResults;
    return <_ClientOption>[
      for (final c in rows.take(limit)) _ClientExisting(c),
      // Always last, so the default highlight is the best real match and a
      // plain Enter never hijacks into create.
      if (_showCreate) _ClientCreate(query),
    ];
  }

  void _commit(Client client) {
    _committed = client;
    _optionsVisible = false;
    _controller.text = clientPickerLabel(client);
    widget.onSelected(client);
  }

  Future<void> _handleCreate(String rawQuery) async {
    final onCreate = widget.onCreateRequested;
    if (onCreate == null || _creating || !widget.enabled) return;
    final query = rawQuery.trim();
    final restoreText = _controller.text;

    setState(() => _creating = true);
    // Hand focus to the dialog. Unfocusing also collapses the options overlay
    // so it can't paint against the barrier, and drops the soft keyboard
    // before the dialog's own field claims it. The blur snap-back has to be
    // suppressed or the half-typed query is wiped before the cancel branch
    // can restore it.
    _suppressBlurSnap = true;
    _focusNode.unfocus();

    Client? created;
    try {
      created = await onCreate(context, query);
    } catch (error, stack) {
      // Both call sites discard this future, so without a catch a throwing
      // create UI surfaces as an unhandled async error instead of a failed
      // create the user can retry.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'client_picker_field',
          context: ErrorDescription('opening the inline client-create UI'),
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
      _suppressBlurSnap = false;
    }
    if (!mounted) return;

    if (created == null) {
      _controller.text = restoreText;
      _controller.selection = TextSelection.collapsed(
        offset: restoreText.length,
      );
      _focusNode.requestFocus();
      return;
    }

    setState(() => _commit(created!));
    // Deliberately not refocusing: create is terminal, and refocusing would
    // immediately reopen the popover over the value just chosen (our option
    // list is never empty, so it always reopens on focus).
  }

  void _scrollHighlightedIntoView(int highlightedIndex, int optionCount) {
    if (highlightedIndex < 0 || highlightedIndex >= optionCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_optionsScroll.hasClients) return;
      final position = _optionsScroll.position;
      final target = highlightedIndex * _optionExtent;
      final viewport = position.viewportDimension;
      final current = position.pixels;
      double? newOffset;
      if (target < current) {
        newOffset = target;
      } else if (target + _optionExtent > current + viewport) {
        newOffset = target + _optionExtent - viewport;
      }
      if (newOffset != null) {
        _optionsScroll.jumpTo(
          newOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
        );
      }
    });
  }

  @override
  void dispose() {
    _warmTimer?.cancel();
    _selectedWatch?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _optionsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final label = widget.label ?? context.tr('client');

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final popoverWidth = math.min(fieldWidth, 360.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: RawAutocomplete<_ClientOption>(
            textEditingController: _controller,
            focusNode: _focusNode,
            // Only reached via `RawAutocomplete._select`, which normally never
            // sees a `_ClientCreate` (see `onSelected`).
            displayStringForOption: (o) => o is _ClientExisting
                ? clientPickerLabel(o.client)
                : (o as _ClientCreate).query,
            optionsBuilder: (value) => _buildOptions(value.text.trim()),
            onSelected: (o) {
              if (o is _ClientCreate) {
                // The pointer path calls `_handleCreate` from `InkWell.onTap`
                // and the keyboard path is intercepted in `onSubmitted`, so
                // this is a backstop for the case where both key events land
                // in one batch and the interceptor's highlight read lags.
                // Handling it here (rather than dropping it) matters because
                // `_select` has already latched this instance as its
                // selection — ignoring it would strand the row.
                unawaited(_handleCreate(o.query));
                return;
              }
              setState(() => _commit((o as _ClientExisting).client));
            },
            fieldViewBuilder:
                (context, textController, focusNode, onFieldSubmitted) {
                  // `RawAutocomplete` (unlike `Autocomplete`) wraps its field
                  // in no Material, so hosts without one would throw.
                  return Material(
                    type: MaterialType.transparency,
                    child: EscapeObserver(
                      // `DismissIntent` hides the options overlay without
                      // touching focus, so nothing else would tell us it is
                      // gone — and a stale "visible" flag makes the next Enter
                      // fire create on a popover the user just dismissed.
                      onEscape: () => _optionsVisible = false,
                      child: TextField(
                        controller: textController,
                        focusNode: focusNode,
                        enabled: widget.enabled,
                        onTap: _reopenOptions,
                        onSubmitted: (_) {
                          if (_highlightIsCreateRow) {
                            // Seed with the same query the options were built
                            // from, so Enter and a tap on the create row agree:
                            // on an untouched field that's "" ("New Client"),
                            // not the committed client's own name.
                            final text = textController.text;
                            unawaited(
                              _handleCreate(
                                _isPristine(text.trim()) ? '' : text,
                              ),
                            );
                            return; // never reaches `_select`
                          }
                          onFieldSubmitted();
                        },
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.ink,
                        ),
                        decoration:
                            billingFieldDecoration(
                              context,
                              label: label,
                              errorText: widget.errorText,
                            ).copyWith(
                              suffixIcon: _buildSuffix(
                                context,
                                tokens,
                                textController,
                              ),
                            ),
                      ),
                    ),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              final highlightedIndex = AutocompleteHighlightedOption.of(
                context,
              );
              // Hold the notifier, not the index: it is an `InheritedNotifier`,
              // so a value captured here is a frame behind the arrow keys, and
              // an Enter in the same event batch would act on the wrong row.
              _highlight = context
                  .dependOnInheritedWidgetOfExactType<
                    AutocompleteHighlightedOption
                  >()
                  ?.notifier;
              _optionCount = options.length;
              _optionsVisible = true;
              _scrollHighlightedIntoView(highlightedIndex, options.length);
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 280,
                      maxWidth: popoverWidth,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      controller: _optionsScroll,
                      itemExtent: _optionExtent,
                      itemCount: options.length,
                      itemBuilder: (context, i) {
                        final opt = options.elementAt(i);
                        final isHighlighted = i == highlightedIndex;
                        if (opt is _ClientCreate) {
                          return _CreateRow(
                            query: opt.query,
                            highlighted: isHighlighted,
                            onTap: () => _handleCreate(opt.query),
                          );
                        }
                        final client = (opt as _ClientExisting).client;
                        return Container(
                          color: isHighlighted ? tokens.accentSoft : null,
                          child: InkWell(
                            onTap: () => onSelected(opt),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: InSpacing.md(context),
                                ),
                                child: Text(
                                  clientPickerLabel(client),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: tokens.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Search glyph / clear button / busy spinner.
  ///
  /// Rebuilt from the controller rather than the enclosing build:
  /// `RawAutocomplete` does not `setState` when the text changes (it drives the
  /// overlay through an `OverlayPortalController` and passes the same field
  /// widget straight through), so a suffix chosen during the parent build stays
  /// on the magnifier while the user types and there is no way to clear the
  /// field.
  Widget _buildSuffix(
    BuildContext context,
    InTheme tokens,
    TextEditingController textController,
  ) {
    return ListenableBuilder(
      listenable: textController,
      builder: (context, _) {
        if (_creating || _searching) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (textController.text.isEmpty) {
          return Icon(Icons.search, size: 18, color: tokens.ink3);
        }
        return IconButton(
          tooltip: context.tr('clear'),
          icon: Icon(Icons.close, size: 16, color: tokens.ink3),
          onPressed: widget.enabled
              ? () {
                  textController.clear();
                  setState(() {
                    _committed = null;
                    _optionsVisible = false;
                  });
                  widget.onSelected(null);
                }
              : null,
        );
      },
    );
  }
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.query,
    required this.highlighted,
    required this.onTap,
  });

  final String query;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = query.isEmpty
        ? context.tr('new_client')
        : '${context.tr('create')} "$query"';
    return Container(
      color: highlighted ? tokens.accentSoft : null,
      child: InkWell(
        onTap: onTap,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: InSpacing.md(context)),
            child: Row(
              children: [
                Icon(Icons.add, size: 16, color: tokens.accent),
                const SizedBox(width: InSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

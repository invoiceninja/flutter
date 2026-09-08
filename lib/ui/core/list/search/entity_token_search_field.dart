import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';

/// A live `id -> display name` map the filter keys close over, so chips render
/// names rather than raw hashids.
typedef NameMapSource =
    Stream<Map<String, String>> Function(Services services, String companyId);

/// Live `id -> name` lookups, one per entry in `nameSources`, indexed
/// positionally — the builder is written directly beside that list.
///
/// Deliberately a live view rather than a snapshot: the filter keys close over
/// it lazily, so a name arriving later is picked up WITHOUT rebuilding the key
/// list. That matters because rebuilding opens a fresh `TagFilterKey` Drift
/// subscription; see [filterKeySignature].
class LiveNameMaps {
  const LiveNameMaps(this._read);

  final List<Map<String, String>> Function() _read;

  /// The name for [id] in the [index]-th source, or null.
  ///
  /// Out-of-range returns null rather than throwing: [index] pairs positionally
  /// with `nameSources`, and the two live in different arguments of the same
  /// constructor, so nothing type-checks the pairing. A mismatch would
  /// otherwise surface as a `RangeError` from inside a chip's
  /// `displayValueFor` during paint. The assert keeps it loud in debug.
  String? lookup(int index, String id) {
    final maps = _read();
    assert(
      index < maps.length,
      'lookup($index) but only ${maps.length} nameSources were declared',
    );
    return index < maps.length ? maps[index][id] : null;
  }
}

/// Builds one entity's filter keys from everything they close over.
typedef FilterKeysBuilder =
    List<FilterKey> Function(
      Services services,
      String companyId,
      Company? company,
      LiveNameMaps names,
    );

/// Cache key for one entity's filter keys: every input they close over,
/// flattened to a string.
///
/// Pure and public so it can be unit-tested directly — the field itself
/// doesn't settle under `pumpAndSettle` (its `OverlayPortal` and
/// focus-driven subscriptions never quiesce), and this expression is the
/// whole bug surface. Miss an input and the keys go stale after a settings
/// change; make it too volatile and every Drift re-emit rebuilds the list,
/// leaking one `TagFilterKey` Drift subscription per rebuild.
///
/// **Name maps are deliberately absent.** They arrive as fresh instances on
/// every Drift emit, so including them would rebuild the key list — and open a
/// fresh `TagFilterKey` subscription — on every no-op re-emit. The keys read
/// names through [LiveNameMaps] instead, so a late-arriving name is picked up
/// without a rebuild. Task, Project and Expense already worked this way and
/// said so; the other ten folded the maps into their cache key and paid for it.
String filterKeySignature({
  required String companyId,
  required Company? company,
  String? customFieldPrefix,
  String extra = '',
}) {
  final labels = (company == null || customFieldPrefix == null)
      ? ''
      : [
          for (var i = 1; i <= 4; i++)
            company.customFieldLabel('$customFieldPrefix$i'),
        ].join('|');
  return '$companyId#$labels#$extra';
}

/// Wires [TokenSearchField] for one entity list: watches whatever the entity's
/// filter keys depend on, and rebuilds the key list only when a *shaping* input
/// actually changes.
///
/// The caching is the reason this is stateful and the reason it is shared.
/// `TagFilterKey` opens a Drift watch subscription in its constructor, so
/// rebuilding the list on every stream re-emit would leak one live query per
/// rebuild. Name maps are handled the other way round — they are read live through
/// [LiveNameMaps] and stay out of the cache key entirely; see [filterKeySignature].
///
/// Thirteen entities had a hand-written copy of this, and they had already
/// drifted into two different caching implementations — Products hoisted its
/// company stream inside `build` and cached on two separate fields, while
/// Invoices used a combined signature. Only the shape varied; the bug surface
/// was identical.
///
/// The three list screens whose keys need no streams at all (gateways, expense
/// categories, payment links) stay plain `StatelessWidget`s — there is nothing
/// here for them to reuse.
class EntityTokenSearchField extends StatefulWidget {
  const EntityTokenSearchField({
    required this.vm,
    required this.wide,
    required this.hintKey,
    required this.keysBuilder,
    this.nameSources = const [],
    this.customFieldPrefix,
    this.extraSignature,
    this.watchesCompany = true,
    super.key,
  });

  final GenericListViewModel<dynamic> vm;
  final bool wide;
  final String hintKey;
  final FilterKeysBuilder keysBuilder;

  /// Extra live name maps, resolved in order and handed to [keysBuilder].
  final List<NameMapSource> nameSources;

  /// Custom-field slot prefix whose configured labels shape the keys, e.g.
  /// `client` for `client1..4`. **Not the entity name**: quotes, credits,
  /// purchase orders and recurring invoices all read `invoice1..4`. Null when
  /// the entity's keys don't surface custom fields.
  final String? customFieldPrefix;

  /// Any further company field the keys close over — Products' `trackInventory`
  /// gates its stock filter. Folded into the cache key.
  final String Function(Company? company)? extraSignature;

  /// Whether to open a `watchCompany` subscription at all.
  ///
  /// False for the two entities whose keys ignore the company entirely
  /// (Expenses, Transactions) — they had no company stream before this widget
  /// existed, and opening one costs a live Drift query per mounted list plus a
  /// rebuild on every company emit, for a value nothing reads. Their
  /// `keysBuilder` receives null.
  final bool watchesCompany;

  @override
  State<EntityTokenSearchField> createState() => _EntityTokenSearchFieldState();
}

class _EntityTokenSearchFieldState extends State<EntityTokenSearchField> {
  Stream<Company?>? _companyStream;
  List<Stream<Map<String, String>>>? _nameStreams;
  String? _streamCompanyId;

  List<FilterKey>? _keys;
  String? _signature;

  /// Hoisted out of `build` so a parent rebuild doesn't swap the subscription
  /// — re-subscribing drops a frame of data and churns the Drift query.
  void _ensureStreams(Services services) {
    if (_streamCompanyId == widget.vm.companyId && _companyStream != null) {
      return;
    }
    _streamCompanyId = widget.vm.companyId;
    _companyStream = widget.watchesCompany
        ? services.company.watchCompany(widget.vm.companyId)
        : const Stream<Company?>.empty();
    _nameStreams = [
      for (final source in widget.nameSources)
        source(services, widget.vm.companyId),
    ];
  }

  String _sig(Company? company) => filterKeySignature(
    companyId: widget.vm.companyId,
    company: company,
    customFieldPrefix: widget.customFieldPrefix,
    extra: widget.extraSignature?.call(company) ?? '',
  );

  void _disposeKeys() {
    for (final k in _keys ?? const <FilterKey>[]) {
      k.dispose();
    }
    _keys = null;
  }

  /// Latest emission of each name source, read live by [LiveNameMaps] so the
  /// cached keys never go stale without being rebuilt.
  List<Map<String, String>> _names = const [];

  List<FilterKey> _keysFor(Services services, Company? company) {
    final signature = _sig(company);
    if (_keys != null && _signature == signature) return _keys!;
    _disposeKeys();
    _signature = signature;
    return _keys = widget.keysBuilder(
      services,
      widget.vm.companyId,
      company,
      LiveNameMaps(() => _names),
    );
  }

  @override
  void dispose() {
    _disposeKeys();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    _ensureStreams(services);
    return StreamBuilder<Company?>(
      stream: _companyStream,
      builder: (context, companySnap) => _NameMaps(
        streams: _nameStreams!,
        previous: _names,
        builder: (names) {
          _names = names;
          return TokenSearchField(
            vm: widget.vm,
            filterKeys: _keysFor(services, companySnap.data),
            wide: widget.wide,
            hintKey: widget.hintKey,
          );
        },
      ),
    );
  }
}

/// Nests one `StreamBuilder` per name source, each defaulting to an empty map.
///
/// Nested rather than combined: a `combineLatest` waits for every side before
/// emitting, which would hold the search field off screen until the last Drift
/// query answered. Each map independently falls back to `{}`, so the field
/// paints immediately and the chips fill in names as they arrive — which is
/// what all thirteen hand-written copies did.
class _NameMaps extends StatelessWidget {
  const _NameMaps({
    required this.streams,
    required this.previous,
    required this.builder,
  });

  final List<Stream<Map<String, String>>> streams;

  /// Last resolved maps, used only on an error frame — see below.
  final List<Map<String, String>> previous;

  final Widget Function(List<Map<String, String>> names) builder;

  @override
  Widget build(BuildContext context) => _nest(const []);

  Widget _nest(List<Map<String, String>> resolved) {
    if (resolved.length == streams.length) return builder(resolved);
    final i = resolved.length;
    return StreamBuilder<Map<String, String>>(
      stream: streams[i],
      builder: (context, snap) {
        // `AsyncSnapshot.withError` drops `data`, so a Drift error frame would
        // otherwise blank the map and fall every chip back to a raw hashid.
        // Task, Project and Expense kept the previous value before this widget
        // existed; the other ten reset. Keeping it is the better of the two.
        final fallback = i < previous.length
            ? previous[i]
            : const <String, String>{};
        return _nest([...resolved, snap.data ?? fallback]);
      },
    );
  }
}

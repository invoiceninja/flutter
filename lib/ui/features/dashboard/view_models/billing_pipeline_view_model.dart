import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/dashboard/billing_status_tabs.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('BillingPipelineViewModel');

/// Page bound on the per-tab top-up — the same bound (and the same literal)
/// every other bounded in-VM walk uses.
const int kBillingTabFetchMaxPages = 5;

/// One row of the consolidated panel: an invoice or a quote, flattened to the
/// handful of fields the row renders plus the keys it sorts on.
///
/// There is no shared supertype for `Invoice` and `Quote` — they are two
/// independent freezed classes — so the merge needs a carrier. Keeping it to a
/// projection (rather than a sealed union of the two models) is what lets the
/// row widget be written once.
@immutable
class BillingPipelineRow {
  const BillingPipelineRow({
    required this.type,
    required this.id,
    required this.number,
    required this.clientId,
    required this.statusId,
    required this.date,
    required this.amount,
    required this.hasBounce,
    required this.sortDate,
    required this.sortCreatedAt,
  });

  factory BillingPipelineRow.fromInvoice(Invoice e) => BillingPipelineRow(
    type: EntityType.invoice,
    id: e.id,
    number: e.number,
    clientId: e.clientId,
    statusId: e.calculatedStatusId,
    date: e.date,
    amount: e.amount,
    hasBounce: e.hasBouncedInvitation,
    sortDate: e.date?.toIso() ?? '',
    sortCreatedAt: e.createdAt.millisecondsSinceEpoch,
  );

  factory BillingPipelineRow.fromQuote(Quote e) => BillingPipelineRow(
    type: EntityType.quote,
    id: e.id,
    number: e.number,
    clientId: e.clientId,
    statusId: e.calculatedStatusId,
    date: e.date,
    amount: e.amount,
    hasBounce: e.hasBouncedInvitation,
    sortDate: e.date?.toIso() ?? '',
    sortCreatedAt: e.createdAt.millisecondsSinceEpoch,
  );

  final EntityType type;
  final String id;
  final String number;
  final String clientId;

  /// `calculatedStatusId`, so the pill gets past-due / expired / viewed right.
  final String statusId;
  final Object? date;
  final Object amount;
  final bool hasBounce;

  /// ISO date, `''` when absent — matching the Drift column, which is non-null
  /// TEXT defaulting to `''` and therefore sorts last under DESC.
  final String sortDate;

  /// Epoch millis. **0 means "created locally, not yet synced"**, and those must
  /// sort FIRST under DESC, not last — the Dart twin of the DAO's
  /// `CASE created_at WHEN 0 THEN <max>`. See [compareRows].
  final int sortCreatedAt;
}

/// The total order the DAO produces, restated for the cross-entity merge.
///
/// It has to match `watchRecent`'s `ORDER BY date DESC, created_at (epoch 0
/// first) DESC, id` exactly, or merging two correct top-Ns and truncating
/// stops being the overall top-N. The epoch-0 rule is the easy half to get
/// wrong: an offline create stamps `createdAt` to epoch 0, so a naive
/// `b.compareTo(a)` sorts the row the user just made LAST — on a panel whose
/// whole premise is "most recent at the top". `billing_recent_order_test`
/// pins the SQL half of the same rule.
@visibleForTesting
int compareRows(BillingPipelineRow a, BillingPipelineRow b) {
  final byDate = b.sortDate.compareTo(a.sortDate);
  if (byDate != 0) return byDate;
  final aNew = a.sortCreatedAt == 0;
  final bNew = b.sortCreatedAt == 0;
  // Unsynced leads, matching the DAO's `CASE created_at WHEN 0 THEN <max>`.
  if (aNew != bNew) return aNew ? -1 : 1;
  final byCreated = b.sortCreatedAt.compareTo(a.sortCreatedAt);
  if (byCreated != 0) return byCreated;
  return a.id.compareTo(b.id);
}

/// Drives the dashboard's consolidated Invoices & Quotes panel
/// (invoiceninja/flutter#155).
///
/// Drift-backed, like the task calendar: it watches the local tables and tops
/// the cache up per tab, rather than reading a `dashboard_cache` row.
class BillingPipelineViewModel extends ChangeNotifier {
  BillingPipelineViewModel({
    required this.invoices,
    required this.quotes,
    required this.companyId,
    required this.includeInvoices,
    required this.includeQuotes,
    required this.tabs,
    required this.rowLimit,
    BillingStatusTab? initialTab,
  }) : _tab = initialTab ?? (tabs.isEmpty ? null : tabs.first) {
    _subscribe();
    unawaited(ensureTabLoaded());
  }

  final InvoiceRepository invoices;
  final QuoteRepository quotes;
  final String companyId;
  final bool includeInvoices;
  final bool includeQuotes;
  final List<BillingStatusTab> tabs;
  final int rowLimit;

  BillingStatusTab? _tab;
  BillingStatusTab? get tab => _tab;

  List<BillingPipelineRow> _rows = const [];
  List<BillingPipelineRow> get rows => _rows;

  /// Whether the panel may make a claim about what the company has.
  ///
  /// A Drift watch emits within a frame of subscribing, so "the stream spoke"
  /// says nothing about whether the cache has been filled — and seven badges
  /// reading 0 on the app's landing route is seven simultaneous false claims.
  /// This flips only once the first top-up for the opening tab has finished (or
  /// failed), which is why `All` gets a fetch too: the login prefetch is
  /// fire-and-forget with no completion signal to wait on.
  bool get firstLoadResolved => _firstLoadResolved;
  bool _firstLoadResolved = false;

  // Not nullable: `_recompute` merges whatever each half has produced so far
  // and renders it, deliberately — see `_subscribe` on why a slow half must not
  // stall the panel. A "not loaded yet" null would encode a distinction nothing
  // reads.
  List<Invoice> _latestInvoices = const [];
  List<Quote> _latestQuotes = const [];
  StreamSubscription<List<Invoice>>? _invoiceSub;
  StreamSubscription<List<Quote>>? _quoteSub;

  /// Completed top-ups, keyed `<entity>:<modeId>`.
  final Set<String> _loadedTabs = <String>{};

  /// In-flight top-ups, tracked SEPARATELY from [_loadedTabs] — collapsing the
  /// two lets a re-arm landing mid-sweep start a second concurrent walk of the
  /// same key, whose failure arm then frees the claim the first is holding.
  final Map<String, Future<void>> _inFlightTabs = <String, Future<void>>{};

  bool _disposed = false;

  void _subscribe() {
    _invoiceSub?.cancel();
    _quoteSub?.cancel();
    _invoiceSub = null;
    _quoteSub = null;
    _latestInvoices = const [];
    _latestQuotes = const [];

    final tab = _tab;
    if (tab == null) return;

    // Each half is its own subscription rather than a `combineLatest2`: that
    // helper emits nothing until BOTH sides have produced a value, so pairing a
    // live stream with an absent one would stall the panel at empty forever.
    if (includeInvoices && tab.invoiceModeId != null) {
      _invoiceSub = invoices
          .watchRecent(
            companyId: companyId,
            limit: rowLimit,
            badgeModeId: _asBadgeFilter(tab.invoiceModeId!),
          )
          .listen((rows) {
            _latestInvoices = rows;
            _recompute();
          }, onError: _onStreamError);
    }
    if (includeQuotes && tab.quoteModeId != null) {
      _quoteSub = quotes
          .watchRecent(
            companyId: companyId,
            limit: rowLimit,
            badgeModeId: _asBadgeFilter(tab.quoteModeId!),
          )
          .listen((rows) {
            _latestQuotes = rows;
            _recompute();
          }, onError: _onStreamError);
    }
  }

  /// `total` means "no narrowing" to the DAO, which expects null for that.
  String? _asBadgeFilter(String modeId) =>
      modeId == kBadgeModeTotal ? null : modeId;

  void _onStreamError(Object e, StackTrace st) {
    _log.warning('billing pipeline stream failed', e, st);
  }

  void _recompute() {
    if (_disposed) return;
    final merged = <BillingPipelineRow>[
      for (final e in _latestInvoices) BillingPipelineRow.fromInvoice(e),
      for (final e in _latestQuotes) BillingPipelineRow.fromQuote(e),
    ]..sort(compareRows);
    _rows = merged.length > rowLimit
        ? List<BillingPipelineRow>.unmodifiable(merged.take(rowLimit))
        : List<BillingPipelineRow>.unmodifiable(merged);
    notifyListeners();
  }

  /// Select [next], re-subscribing the participating halves.
  ///
  /// A re-pick of the current tab is a real command, not a no-op: it is the
  /// user asking for that bucket again, and re-arming the fetch is the useful
  /// thing to do with it.
  void selectTab(BillingStatusTab next) {
    _tab = next;
    _rows = const [];
    _subscribe();
    notifyListeners();
    unawaited(ensureTabLoaded());
  }

  /// Top the local cache up for the selected tab — bounded, latched, silent.
  Future<void> ensureTabLoaded() async {
    final tab = _tab;
    if (tab == null) return;
    final futures = <Future<void>>[];
    if (includeInvoices && tab.invoiceModeId != null) {
      futures.add(_runTab(EntityType.invoice, tab.invoiceModeId!));
    }
    if (includeQuotes && tab.quoteModeId != null) {
      futures.add(_runTab(EntityType.quote, tab.quoteModeId!));
    }
    await Future.wait(futures);
    if (_disposed || !identical(tab, _tab)) return;
    if (!_firstLoadResolved) {
      _firstLoadResolved = true;
      notifyListeners();
    }
  }

  Future<void> _runTab(EntityType type, String modeId) {
    final key = '${type.name}:$modeId';
    if (_loadedTabs.contains(key)) return Future<void>.value();
    final inFlight = _inFlightTabs[key];
    if (inFlight != null) return inFlight;
    // The release is a `whenComplete` on the STORED future, not a `finally`
    // inside `_sweep`. `_sweep` is `async`, so a throw before its first
    // suspension runs its body — `catch` and `finally` included —
    // synchronously, i.e. BEFORE the assignment below: a `finally` that
    // removed the key would run first and this line would then store an
    // already-completed future forever, latching the tab's top-up off with
    // nothing able to recover it (`invalidateLoadedTabs` clears only
    // `_loadedTabs`). The identity check keeps a stale completion from
    // evicting a newer claim.
    late final Future<void> future;
    future = _sweep(type, modeId, key).whenComplete(() {
      if (identical(_inFlightTabs[key], future)) _inFlightTabs.remove(key);
    });
    _inFlightTabs[key] = future;
    return future;
  }

  Future<void> _sweep(EntityType type, String modeId, String key) async {
    final isAll = modeId == kBadgeModeTotal;
    // The server params this bucket translates to, or null for a local-only
    // tab — which still gets a sweep, just an unnarrowed one.
    final server = isAll ? null : statusTabServerFilters(type, modeId);
    // How far to walk, and the three cases are genuinely different costs:
    //
    //  * `All` — ONE page. It is the tab the panel opens on, so this runs on
    //    the app's landing route for both entities; a five-page walk each
    //    would add ten requests to the cold-start fan-out to fill five rows
    //    that page 1 (sorted newest-first) already contains. Its real job here
    //    is to give `firstLoadResolved` something to resolve on, since the
    //    login prefetch is fire-and-forget with no completion signal.
    //  * a server-narrowed tab — ONE page. The bucket is narrow by
    //    construction, so page 1 fills a five-row panel.
    //  * a LOCAL-ONLY tab — up to [kBillingTabFetchMaxPages]. Nothing narrows
    //    the fetch, so the tab's rows can sit arbitrarily deep; this is the
    //    only mechanism `Rejected` has to reach the cache at all.
    final maxPages = isAll || server != null ? 1 : kBillingTabFetchMaxPages;
    // `ignoreCursor` on EVERY call, including the unnarrowed ones. An
    // unnarrowed fetch is not a "narrowed fetch", so `shouldReadCursor` would
    // otherwise send the `updated_at >=` watermark and return the DELTA rather
    // than a true first page — and a quote rejected three months ago and
    // untouched since is not in the delta. That would make the top-up for
    // `Rejected` (local-only, so unnarrowed) do nothing at all.
    try {
      for (var page = 1; page <= maxPages; page++) {
        final more = type == EntityType.invoice
            ? await invoices.ensurePageLoaded(
                companyId: companyId,
                page: page,
                states: const {EntityState.active},
                extraFilters: server ?? const {},
                ignoreCursor: true,
              )
            : await quotes.ensurePageLoaded(
                companyId: companyId,
                page: page,
                states: const {EntityState.active},
                extraFilters: server ?? const {},
                ignoreCursor: true,
              );
        // `dispose` cancels the subscriptions but cannot interrupt a `for`, and
        // on a company switch the next page would go out under the NEW
        // company's token for the OLD company's bucket.
        if (_disposed || !more) break;
      }
      _loadedTabs.add(key);
    } on CompanySwitchedException catch (e) {
      _log.fine('billing pipeline tab abandoned: $e');
    } on NetworkException catch (e) {
      _log.fine('billing pipeline tab skipped: ${e.message}');
    } catch (e, st) {
      // Bare, not `on Exception`: nothing awaits this beyond `ensureTabLoaded`,
      // and the repository doubles in the widget suites raise
      // `UnimplementedError`, which is an Error.
      _log.warning('billing pipeline tab failed', e, st);
    }
  }

  /// Re-arm every bucket — the host calls this when the dashboard's
  /// pull-to-refresh completes, which otherwise refreshes only the
  /// server-cached panels and leaves this one untouched.
  ///
  /// Leaves [_inFlightTabs] alone: a sweep already on the wire is fresh data by
  /// definition, and dropping its claim would let a second walk start beside it.
  void invalidateLoadedTabs() => _loadedTabs.clear();

  @override
  void dispose() {
    _disposed = true;
    _invoiceSub?.cancel();
    _quoteSub?.cancel();
    super.dispose();
  }
}

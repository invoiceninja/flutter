import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/models/value/gateway.dart';
import 'package:admin/data/models/value/gateway_type.dart';
import 'package:admin/data/models/value/industry.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/data/models/value/size.dart';
import 'package:admin/data/models/value/static_template.dart';
import 'package:admin/data/models/value/timezone.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/utils/perf_trace.dart';

final _log = Logger('StaticsRepository');

/// Loads + caches `/api/v1/statics`. The cache is a single JSON blob in
/// Drift's `statics` table; typed lookups (`currency`, `country`,
/// `dateFormat`) are parsed lazily into immutable maps the first time
/// they're requested after a reload.
class StaticsRepository {
  StaticsRepository({
    required AppDatabase db,
    required StaticsService service,
    Duration ttl = const Duration(days: 7),
    DateTime Function()? now,
  }) : _db = db,
       _service = service,
       _ttl = ttl,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final StaticsService _service;
  final Duration _ttl;
  final DateTime Function() _now;

  Map<String, dynamic>? _memo;

  /// `fetched_at` of the stored row [_memo] matches — the row it was decoded
  /// from, or the one written alongside it. [ensureLoaded] compares it with
  /// the row's current stamp, which is how it notices a wipe (no row) without
  /// any hook having to tell it.
  int? _memoFetchedAt;

  /// The unforced [ensureLoaded] in flight, shared by concurrent callers.
  Future<void>? _loading;

  Map<String, Currency>? _currencies;
  Map<String, Country>? _countries;
  Map<String, DatetimeFormat>? _dateFormats;
  Map<String, Size>? _sizes;
  Map<String, Industry>? _industries;
  Map<String, Language>? _languages;
  Map<String, Timezone>? _timezones;
  Map<String, PaymentType>? _paymentTypes;
  Map<String, Gateway>? _gateways;
  Map<String, StaticTemplate>? _templates;

  /// Refresh the cache if it's empty or older than [_ttl]. Idempotent and
  /// cheap to call from app start + post-login.
  ///
  /// Cheap once warm: with the blob already in memory this reads one integer
  /// (the row's `fetched_at`) and returns. It used to read and decode the
  /// whole payload and rebuild every typed view on each call, and a cold start
  /// calls it several times over — boot, the locale resolver on every session
  /// change, each company's formatter.
  Future<void> ensureLoaded({bool force = false}) {
    if (force) return _load(force: true);
    return _loading ??= _load(force: false).whenComplete(() => _loading = null);
  }

  Future<void> _load({required bool force}) async {
    if (!force && _memo != null) {
      final stamp = await _db.staticsDao.fetchedAt();
      if (stamp != null &&
          stamp == _memoFetchedAt &&
          _now().millisecondsSinceEpoch - stamp < _ttl.inMilliseconds) {
        return;
      }
    }
    final cached = await _db.staticsDao.read();
    final nowMs = _now().millisecondsSinceEpoch;
    if (!force &&
        cached != null &&
        nowMs - cached.fetchedAt < _ttl.inMilliseconds) {
      _adoptCached(cached);
      return;
    }
    try {
      final fresh = await _service.fetch();
      await _db.staticsDao.write(payload: jsonEncode(fresh), fetchedAt: nowMs);
      _setMemo(fresh, fetchedAt: nowMs);
    } catch (e, st) {
      _log.warning('statics refresh failed; using stale cache if any', e, st);
      if (cached != null) _adoptCached(cached);
    }
    _warmTypedViews();
  }

  /// Decode the stored row into [_memo] and parse the typed views.
  void _adoptCached(({String payload, int fetchedAt}) cached) {
    traceSync('statics.decode', () {
      _setMemo(
        jsonDecode(cached.payload) as Map<String, dynamic>,
        fetchedAt: cached.fetchedAt,
      );
      _warmTypedViews();
    }, args: {'chars': cached.payload.length});
  }

  /// Seed the cache from a `/api/v1/refresh` `static` blob instead of an
  /// independent `/api/v1/statics` request — the refresh envelope already
  /// carries the full catalog when `include_static=true` was sent.
  ///
  /// No-op on a null/empty map: a *delta* refresh (no `include_static`)
  /// returns `static: {}` (freezed `@Default`); writing that would blank
  /// every currency / country / language dropdown. Mirrors [ensureLoaded]'s
  /// write path so the 7-day TTL keeps cold-start fallback intact.
  Future<void> applyStatic(Map<String, dynamic>? blob) async {
    if (blob == null || blob.isEmpty) return;
    final nowMs = _now().millisecondsSinceEpoch;
    await _db.staticsDao.write(payload: jsonEncode(blob), fetchedAt: nowMs);
    _setMemo(blob, fetchedAt: nowMs);
    _warmTypedViews();
  }

  /// Parse every typed view now, on the (already-awaited) boot path,
  /// instead of lazily on first getter access — which otherwise lands
  /// during the first list paint when a `Formatter` first reads
  /// `currencies`. Each getter memoizes, so this is a one-time cost moved
  /// off the render thread; a null `_memo` makes each a cheap no-op.
  void _warmTypedViews() {
    if (_memo == null) return;
    currencies;
    countries;
    dateFormats;
    sizes;
    industries;
    languages;
    timezones;
    paymentTypes;
    gateways;
    templates;
  }

  void _setMemo(Map<String, dynamic> blob, {required int fetchedAt}) {
    _memo = blob;
    _memoFetchedAt = fetchedAt;
    // Invalidate the typed views so the next read reparses.
    _currencies = null;
    _countries = null;
    _dateFormats = null;
    _sizes = null;
    _industries = null;
    _languages = null;
    _timezones = null;
    _paymentTypes = null;
    _gateways = null;
    _templates = null;
  }

  /// Get one entry from a top-level array (e.g. `currencies`) by `id`.
  /// Returns null if the bundle isn't loaded or the id is missing.
  Map<String, dynamic>? entry(String mapName, String id) {
    final m = _memo;
    if (m == null) return null;
    final arr = m[mapName];
    if (arr is! List) return null;
    for (final item in arr) {
      if (item is Map<String, dynamic> && item['id']?.toString() == id) {
        return item;
      }
    }
    return null;
  }

  /// Typed currency / country / date-format maps, keyed by string id. Empty
  /// until [ensureLoaded] completes.
  Map<String, Currency> get currencies =>
      _currencies ??= _parseMap('currencies', Currency.fromMap);

  Map<String, Country> get countries =>
      _countries ??= _parseMap('countries', Country.fromMap);

  Map<String, DatetimeFormat> get dateFormats =>
      _dateFormats ??= _parseMap('date_formats', DatetimeFormat.fromMap);

  Map<String, Size> get sizes => _sizes ??= _parseMap('sizes', Size.fromMap);

  Map<String, Industry> get industries =>
      _industries ??= _parseMap('industries', Industry.fromMap);

  Map<String, Language> get languages =>
      _languages ??= _parseMap('languages', Language.fromMap);

  Map<String, Timezone> get timezones =>
      _timezones ??= _parseMap('timezones', Timezone.fromMap);

  Map<String, PaymentType> get paymentTypes =>
      _paymentTypes ??= _parseMap('payment_types', PaymentType.fromMap);

  /// Server-provided default subject + body per email template type, keyed
  /// by template id (`invoice`, `quote`, `reminder1`, …). Unlike the rest
  /// of the statics catalog, `templates` ships as an *object* (not an
  /// array), so [_parseMap] doesn't apply — hand-rolled below.
  ///
  /// Used by Settings → Templates & Reminders to show factory-default
  /// placeholder hints. Empty map when statics hasn't loaded; missing
  /// keys (e.g. `quote_reminder1`, `payment_failed`) return null from
  /// [template] — callers fall back to an empty string.
  Map<String, StaticTemplate> get templates {
    if (_templates != null) return _templates!;
    final m = _memo;
    if (m == null) return _templates = const {};
    final raw = m['templates'];
    if (raw is! Map<String, dynamic>) return _templates = const {};
    final out = <String, StaticTemplate>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        out[entry.key] = StaticTemplate.fromMap(value);
      }
    }
    return _templates = out;
  }

  /// Gateway-provider catalog (Stripe, PayPal, Authorize.Net, …). Keyed by
  /// `Gateway.id` — the server's `key` field on the statics payload (a
  /// 32-char hash). Each entry describes one available provider; users
  /// create `CompanyGateway` rows against these via the gateway settings UI.
  ///
  /// Note: empty when the statics bundle hasn't loaded — call
  /// `ensureLoaded()` first on cold launches.
  ///
  /// Unlike the rest of the statics catalog, gateways do **not** carry their
  /// canonical id in the `id` JSON field — it lives in `key` (matches the
  /// legacy admin-portal's `gatewayMap`, which keys by `GatewayEntity.id` =
  /// `@BuiltValueField(wireName: 'key')`). The shared `_parseMap` helper
  /// keys by `id`, so we hand-roll the loop here to key by `key`. Without
  /// this, lookups by the hash (e.g. `statics.gateway(draft.gatewayKey)`
  /// from the edit screen) miss and the Credentials / Settings tabs stay
  /// stuck on the "Loading…" placeholder.
  Map<String, Gateway> get gateways {
    if (_gateways != null) return _gateways!;
    final m = _memo;
    if (m == null) return _gateways = const {};
    final arr = m['gateways'];
    if (arr is! List) {
      _log.warning(
        'statics["gateways"] missing or not a list; top-level keys=${m.keys.toList()}',
      );
      return _gateways = const {};
    }
    final out = <String, Gateway>{};
    for (final item in arr) {
      if (item is Map<String, dynamic>) {
        final key = item['key']?.toString();
        if (key != null && key.isNotEmpty) out[key] = Gateway.fromMap(item);
      }
    }
    return _gateways = out;
  }

  /// Payment-method types accepted by a gateway (credit_card, bank_transfer,
  /// paypal, sepa, …). Keyed by stable numeric id as a string.
  ///
  /// **Hardcoded — not server-driven.** Verified against the live demo API
  /// (`POST /api/v1/login?include_static=true&first_load=true`): the
  /// returned `static` blob does *not* include a `gateway_types` key, and
  /// `/api/v1/statics` doesn't either. The legacy admin-portal owns the
  /// equivalent catalog as `kGatewayTypes` in `lib/constants.dart` and
  /// never reads `gateway_types` from the server even when its mock data
  /// supplies one. We mirror that here: source from
  /// [kGatewayTypeLabelKey] (a compile-time constant). `GatewayType.name`
  /// is the localization key (`credit_card`, `bank_transfer`, …); UI
  /// call sites resolve via `context.tr(...)`.
  Map<String, GatewayType> get gatewayTypes => _kGatewayTypesCatalog;

  static final Map<String, GatewayType> _kGatewayTypesCatalog =
      Map.unmodifiable({
        for (final entry in kGatewayTypeLabelKey.entries)
          entry.key: GatewayType(id: entry.key, name: entry.value),
      });

  Currency? currency(String id) => currencies[id];
  Country? country(String id) => countries[id];
  DatetimeFormat? dateFormat(String id) => dateFormats[id];
  Size? size(String id) => sizes[id];
  Industry? industry(String id) => industries[id];
  Language? language(String id) => languages[id];
  Timezone? timezone(String id) => timezones[id];
  PaymentType? paymentType(String id) => paymentTypes[id];
  Gateway? gateway(String id) => gateways[id];
  GatewayType? gatewayType(String id) => gatewayTypes[id];
  StaticTemplate? template(String id) => templates[id];

  Map<String, T> _parseMap<T>(
    String key,
    T Function(Map<String, dynamic>) parse,
  ) {
    final m = _memo;
    if (m == null) return const {};
    final arr = m[key];
    if (arr is! List) {
      _log.warning(
        'statics["$key"] missing or not a list; top-level keys=${m.keys.toList()}',
      );
      return const {};
    }
    final out = <String, T>{};
    for (final item in arr) {
      if (item is Map<String, dynamic>) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) out[id] = parse(item);
      }
    }
    return out;
  }
}

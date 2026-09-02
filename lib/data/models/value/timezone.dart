/// Statics-bundle timezone. Wire shape matches
/// `admin-portal/lib/data/models/static/timezone_model.dart` — the server ships
/// `id`, `name` (IANA tzdb identifier, e.g. `Europe/London`), `location`
/// (the human-readable city/region, e.g. `London`) and `utc_offset`.
class Timezone {
  const Timezone({
    required this.id,
    required this.name,
    required this.location,
    this.utcOffset = 0,
  });

  final String id;
  final String name;
  final String location;

  /// Seconds east of UTC, straight off the server's `timezones.utc_offset`
  /// column (`app/Utils/Statics.php` returns bare Eloquent models, no
  /// transformer, so it has always been on the wire — this model simply used
  /// to drop it, and statics is cached as one raw JSON blob, so reading it now
  /// needs no schema change and no refetch).
  ///
  /// **Standard time only — it encodes no DST rule**, so a DST-observing zone
  /// is an hour out for half the year. Fine for the advisory
  /// outside-business-hours warning it was added for (`docs/tap-to-call.md`),
  /// which the user can always dismiss; do not build anything that needs an
  /// exact wall clock on it without a real tz database. [name] is the only
  /// DST-correct input here. Same limitation `lib/domain/tasks/task_day.dart`
  /// documents for task-day bucketing.
  final int utcOffset;

  factory Timezone.fromMap(Map<String, dynamic> json) => Timezone(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
    // Coerced rather than cast: the server writes an int, but this blob
    // bypasses read-time casts (see the raw-JSON note in CLAUDE.md) and a
    // string would otherwise throw on every statics parse.
    utcOffset: switch (json['utc_offset']) {
      final int v => v,
      final num v => v.toInt(),
      final Object v => int.tryParse(v.toString()) ?? 0,
      null => 0,
    },
  );
}

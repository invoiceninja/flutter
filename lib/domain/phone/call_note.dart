/// A manually-logged phone call, and the one place its activity-note string is
/// built and recognised (invoiceninja/flutter#120).
///
/// ## Where a logged call lives
///
/// There is no call-log table, client-side or server-side. A logged call is an
/// ordinary **user note** on the entity's activity feed: `POST
/// /api/v1/activities/notes` writes an `Activity` row with
/// `activity_type_id = 141` (`Activity::USER_NOTE`), rendered from the
/// already-translated `activity_141` template — *"User :user entered note:
/// :notes"*. The app reaches it through the outbox exactly like a comment
/// (`MutationKind.addComment`), so a call logged offline queues and syncs with
/// everything else, and a note logged against an invoice also lands on that
/// invoice's **client** feed because the server stamps `client_id` too.
///
/// That is not a workaround. Invoice Ninja's own Pancake importer stores
/// imported phone-call logs this way — `app/Import/Pancake/DatabaseSource.php`
/// flattens method / contact / sent-date / duration / body into the same
/// `notes` string — and [composeCallNote] mirrors its shape.
///
/// ## The consequences, which the whole design turns on
///
/// **`notes` is one free-text column and the only storage there is.** The wire
/// carries no direction, no duration, no contact id and no note subtype, so
/// every structured field here is flattened into the string at compose time and
/// **never read back out**. Do not parse [composeCallNote]'s output: a contact
/// name may legally contain the separator, the labels are in whatever locale
/// and date format the author had, and there is no version marker to migrate.
///
/// **The note is append-only.** The server exposes no `PUT` or `DELETE` for an
/// activity and the table has no `deleted_at`, so whatever is composed here is
/// permanent for every client, in every locale, for ever. Get it right once.
///
/// **[kCallNoteMarker] is cosmetic.** Its only consumers are the phone icon on
/// the activity row and the Calls lens on `/activity`. It is a display hint, not
/// a data model: a user who types the glyph themselves gets the icon (harmless),
/// a note written by React or the legacy app never carries it (also harmless).
/// Nothing load-bearing — no count, no report, no sync decision — may key off
/// it.
///
/// Deliberately a leaf: imports nothing, so `lib/data/**` may use it (see
/// `Activity.isCallNote`) without tripping `test/lint/layering_test.dart`, and
/// so it unit-tests without Drift, `Services` or a widget tree — the same
/// reasoning as its neighbours `phone_actions_settings.dart` and
/// `phone_candidates.dart`.
library;

/// Which way the call went. Two values on purpose: "missed" / "voicemail" and
/// friends belong in the summary the user types, not in a fixed vocabulary that
/// has to survive being flattened into a string for ever.
enum CallDirection { incoming, outgoing }

/// Prefixed to every note this app composes for a call.
///
/// U+1F4DE PHONE, chosen over U+260E BLACK TELEPHONE because U+260E defaults to
/// *text* presentation and routinely picks up a U+FE0F variation selector from
/// an input method — so the stored string's length would depend on who typed
/// it. Write this exact constant; read with [isCallNoteText], which is tolerant.
const String kCallNoteMarker = '\u{1F4DE}';

/// Separator between header segments. Chosen to match the app's other
/// one-line metadata joins, and never used as a parsing delimiter — see the
/// library doc.
const String _kSep = ' · ';

/// **Longest first.** The loop below returns on the first match, and a bare
/// `📞` is a prefix of `📞︎` — so listing the short form first would strip two
/// code units and leave the variation selector behind, which `trimLeft` cannot
/// remove (U+FE0F is not whitespace) and which then renders as an orphan glyph
/// at the head of the note.
const List<String> _kRecognisedMarkers = <String>[
  '\u{1F4DE}\u{FE0F}', // 📞 with a stray variation selector
  '\u{1F4DE}', // 📞 phone (what this app writes)
  '\u{260E}\u{FE0F}', // ☎️ emoji presentation
  '\u{260E}', // ☎ text presentation
];

/// Whether [notes] looks like a call this app (or a tolerantly-close sibling)
/// composed.
///
/// Deliberately forgiving on read and exact on write: a leading variation
/// selector or the older telephone glyph still lights up the phone icon, which
/// is the only thing that depends on it. A false positive costs one wrong icon;
/// a false negative costs nothing at all.
bool isCallNoteText(String notes) {
  final trimmed = notes.trimLeft();
  if (trimmed.isEmpty) return false;
  for (final marker in _kRecognisedMarkers) {
    if (trimmed.startsWith(marker)) return true;
  }
  return false;
}

/// [notes] with the leading marker (and the space after it) removed, for a
/// surface that renders its own phone icon and would otherwise print the glyph
/// twice. Returns [notes] unchanged when there is no marker.
String stripCallNoteMarker(String notes) {
  final trimmed = notes.trimLeft();
  for (final marker in _kRecognisedMarkers) {
    if (trimmed.startsWith(marker)) {
      return trimmed.substring(marker.length).trimLeft();
    }
  }
  return notes;
}

/// Builds the note body for a logged call.
///
/// Every argument is an **already-localized, already-`Formatter`-rendered**
/// string — this file holds no `BuildContext` and does no formatting, so the
/// caller owns the company's date format, its military-time choice and the
/// active locale. In particular the caller must render the time through
/// `formatTimeOfDay`, never `Formatter.date(..., showTime: true)`, which treats
/// its input as server UTC and would shift a locally-picked wall clock by the
/// device's offset.
///
/// Shape — the marker, a `·`-joined header of whichever segments are present,
/// then the summary on its own line:
///
/// ```
/// 📞 Outgoing · Jane Smith · +1 415 555 0123 · 12 Minutes · 3 Sep 2026 14:32
/// Discussed the overdue invoice; they'll pay Friday.
/// ```
///
/// Blank segments are dropped rather than emitted empty, so an absent duration
/// leaves `· ·` nowhere. [summary] is the only required part; the header alone
/// would be a record that a call happened and nothing about what was said,
/// which is the thing the feature exists for.
String composeCallNote({
  required String directionLabel,
  required String whenLabel,
  required String summary,
  String contact = '',
  String durationLabel = '',
}) {
  final header = <String>[
    directionLabel,
    contact,
    durationLabel,
    whenLabel,
  ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(_kSep);

  final body = summary.trim();
  final prefix = header.isEmpty ? kCallNoteMarker : '$kCallNoteMarker $header';
  return body.isEmpty ? prefix : '$prefix\n$body';
}

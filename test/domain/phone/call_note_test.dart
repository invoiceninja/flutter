import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/phone/call_note.dart';

/// The composed-note string behind "Log call" (invoiceninja/flutter#120).
///
/// Pure — no Drift, no `Services`, no widget tree — which is why the composer
/// takes already-localized, already-formatted strings and lives in
/// `lib/domain/`. The note is **append-only server-side**, so these assertions
/// are about a string that can never be corrected after the fact.
void main() {
  const summary = "Discussed the overdue invoice; they'll pay Friday.";

  group('composeCallNote', () {
    test('marker first, header joined, summary on its own line', () {
      final note = composeCallNote(
        directionLabel: 'Outgoing',
        contact: 'Jane Smith · +1 415 555 0123',
        durationLabel: '12 Minutes',
        whenLabel: '3 Sep 2026 14:32',
        summary: summary,
      );
      expect(
        note,
        '$kCallNoteMarker Outgoing · Jane Smith · +1 415 555 0123 · '
        '12 Minutes · 3 Sep 2026 14:32\n$summary',
      );
    });

    test('an absent segment leaves no doubled or dangling separator', () {
      for (final note in [
        composeCallNote(
          directionLabel: 'Incoming',
          whenLabel: '3 Sep 2026',
          summary: summary,
        ),
        composeCallNote(
          directionLabel: 'Incoming',
          contact: '',
          durationLabel: '',
          whenLabel: '3 Sep 2026',
          summary: summary,
        ),
        composeCallNote(
          directionLabel: 'Incoming',
          contact: '   ',
          durationLabel: '  ',
          whenLabel: '3 Sep 2026',
          summary: summary,
        ),
      ]) {
        expect(note, '$kCallNoteMarker Incoming · 3 Sep 2026\n$summary');
        expect(note.contains(' ·  · '), isFalse);
        expect(note.split('\n').first.endsWith('·'), isFalse);
      }
    });

    test('the marker survives the trim() the repository applies', () {
      // `<repo>.addComment` stores `text.trim()`, so a note whose marker only
      // survived untrimmed would light up in the composer's own test and
      // nowhere in the app.
      final note = composeCallNote(
        directionLabel: 'Outgoing',
        whenLabel: '3 Sep 2026',
        summary: summary,
      );
      expect(isCallNoteText(note.trim()), isTrue);
    });

    test('a summary carrying template tokens is not mangled', () {
      // `activity_141` is rendered by a single-pass regex tokenizer, so a
      // `:notes` inside the note text must never be re-substituted. Assert the
      // composer at least round-trips it verbatim.
      const tricky = 'They asked about :notes and :user — quoted verbatim.';
      final note = composeCallNote(
        directionLabel: 'Outgoing',
        whenLabel: '3 Sep 2026',
        summary: tricky,
      );
      expect(note.endsWith('\n$tricky'), isTrue);
    });

    test('a blank summary still yields a recognisable note', () {
      final note = composeCallNote(
        directionLabel: 'Outgoing',
        whenLabel: '3 Sep 2026',
        summary: '   ',
      );
      expect(note, '$kCallNoteMarker Outgoing · 3 Sep 2026');
      expect(isCallNoteText(note), isTrue);
    });
  });

  group('isCallNoteText', () {
    test(
      'true for what the composer writes, with or without leading space',
      () {
        final note = composeCallNote(
          directionLabel: 'Outgoing',
          whenLabel: '3 Sep 2026',
          summary: summary,
        );
        expect(isCallNoteText(note), isTrue);
        expect(isCallNoteText('  \n $note'), isTrue);
      },
    );

    test(
      'tolerant on read: the older glyph and a stray variation selector',
      () {
        // Written exactly, read forgivingly — a note composed by another build
        // (or hand-typed) should still light up the phone icon, which is the
        // only thing this drives.
        for (final marker in [
          '\u{1F4DE}',
          '\u{1F4DE}\u{FE0F}',
          '\u{260E}',
          '\u{260E}\u{FE0F}',
        ]) {
          expect(
            isCallNoteText('$marker Outgoing · x'),
            isTrue,
            reason: marker,
          );
        }
      },
    );

    test('false for an ordinary comment and for nothing at all', () {
      expect(isCallNoteText('Chasing this one up again'), isFalse);
      expect(isCallNoteText(''), isFalse);
      expect(isCallNoteText('   '), isFalse);
      // A phone *number* in a plain comment is not a logged call.
      expect(isCallNoteText('Rang +1 415 555 0123, no answer'), isFalse);
    });
  });

  group('stripCallNoteMarker', () {
    test('removes the marker and the space after it', () {
      expect(
        stripCallNoteMarker('$kCallNoteMarker Outgoing · x\n$summary'),
        'Outgoing · x\n$summary',
      );
    });

    test('leaves an unmarked note exactly as it is', () {
      const plain = 'Chasing this one up again';
      expect(stripCallNoteMarker(plain), plain);
    });

    test('strips every marker it claims to recognise, whole', () {
      // The list is scanned in order and returns on first match, so a bare
      // `📞` listed before `📞︎` would strip two code units and leave the
      // variation selector — which `trimLeft` cannot remove (U+FE0F is not
      // whitespace) and which then renders as an orphan mark at the head of the
      // note. `isCallNoteText` is order-insensitive, so its four-marker test
      // reads like coverage of this and is not.
      for (final marker in [
        '\u{1F4DE}',
        '\u{1F4DE}\u{FE0F}',
        '\u{260E}',
        '\u{260E}\u{FE0F}',
      ]) {
        final stripped = stripCallNoteMarker('$marker Outgoing · x');
        expect(stripped, 'Outgoing · x', reason: 'marker ${marker.codeUnits}');
        expect(
          stripped.codeUnits,
          isNot(contains(0xFE0F)),
          reason: 'a dangling variation selector survived',
        );
      }
    });
  });
}

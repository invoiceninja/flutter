import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/l10n/localization.dart';

/// The rendered sentence for an [Activity] plus the tap recognizers it
/// created. The host widget must [dispose] the recognizers (a `TextSpan`
/// recognizer is not auto-disposed).
class ActivitySpans {
  const ActivitySpans(this.spans, this.recognizers, this.refTokens);

  final List<InlineSpan> spans;
  final List<TapGestureRecognizer> recognizers;

  /// The template tokens that resolved to an [ActivityRef] — i.e. the records
  /// this sentence actually names. `activityRowTargetRef` filters the row's
  /// destination on it, because `Activity.refs` carries related ids the
  /// template never mentions and a row may only open a record it names
  /// (invoiceninja/flutter#143). Collected by the substitution loop itself, so
  /// nothing is parsed twice; empty for a missing template, which is what makes
  /// an `activity_unknown` row correctly inert.
  final Set<String> refTokens;

  void dispose() {
    for (final r in recognizers) {
      r.dispose();
    }
  }
}

/// Turn an [Activity] into a human-readable, link-bearing sentence by
/// substituting the `activity_<type>` localized template's `:token`s with
/// the record's resolved label objects — mirroring the React app and the
/// legacy admin-portal `getDescription`.
///
/// - type 10 → `activity_10_online` when a contact is present else
///   `activity_10_manual` (online payments are contact-initiated).
/// - type 54 with a contact → swap `:user`→`:contact` (contact-initiated).
/// - Routable refs render as accent links (tap → `goEntityRecord`) **when
///   [linkRefs]**; the acting `user` and amount tokens render bold-but-static;
///   `:notes` shows the raw note; a token the server omitted falls back to its
///   localized noun so a literal `:token` never leaks.
/// - Missing template → `activity_unknown` ("Activity #N").
///
/// [linkRefs] is false on touch, where an inline span link is unusable and the
/// row owns the tap instead (invoiceninja/flutter#143). `RenderParagraph`
/// dispatches a span's recognizer only when the pointer lands inside
/// `glyph.graphemeClusterLayoutBounds` — the font-metric line box, ~17 dp tall
/// for `bodyMedium` inside a 72 dp row — with no slop, and `hitTestSelf` then
/// swallows every miss, so a finger aimed at "0092" silently hit nothing at all.
/// A linked ref then renders in [strong] and carries no recognizer, so
/// [ActivitySpans.recognizers] is empty and there is nothing to dispose.
ActivitySpans buildActivitySpans(
  BuildContext context,
  Activity a, {
  required TextStyle base,
  required TextStyle link,
  required TextStyle strong,
  required bool linkRefs,
}) {
  final l = Localization.of(context);
  var key = 'activity_${a.activityTypeId}';
  if (a.activityTypeId == 10) {
    key = a.refs.containsKey('contact')
        ? 'activity_10_online'
        : 'activity_10_manual';
  }
  var raw = l?.lookup(key) ?? '';
  final hasTemplate = raw.isNotEmpty && raw != key;
  if (!hasTemplate) {
    return ActivitySpans(
      [
        TextSpan(
          text: context.tr('activity_unknown', {'id': '${a.activityTypeId}'}),
          style: base,
        ),
      ],
      const [],
      const {},
    );
  }
  if (a.activityTypeId == 54 && a.refs.containsKey('contact')) {
    raw = raw.replaceAll(':user', ':contact');
  }

  final spans = <InlineSpan>[];
  final recs = <TapGestureRecognizer>[];
  final tokens = <String>{};
  final re = RegExp(r':([a-z_]+)');
  var last = 0;
  for (final m in re.allMatches(raw)) {
    if (m.start > last) {
      spans.add(TextSpan(text: raw.substring(last, m.start), style: base));
    }
    final token = m.group(1)!;
    if (token == 'notes') {
      spans.add(TextSpan(text: a.notes, style: strong));
    } else {
      final ref = a.refs[token];
      if (ref == null) {
        // Server omitted this related entity — show its localized noun
        // (e.g. ":client" → "Client") instead of a raw token.
        spans.add(TextSpan(text: context.tr(token), style: base));
      } else if (ref.isLink && linkRefs) {
        tokens.add(token);
        final rec = TapGestureRecognizer()
          ..onTap = () => goEntityRecord(context, ref.type!, ref.id);
        recs.add(rec);
        spans.add(TextSpan(text: ref.label, style: link, recognizer: rec));
      } else {
        tokens.add(token);
        spans.add(TextSpan(text: ref.label, style: strong));
      }
    }
    last = m.end;
  }
  if (last < raw.length) {
    spans.add(TextSpan(text: raw.substring(last), style: base));
  }
  return ActivitySpans(spans, recs, tokens);
}

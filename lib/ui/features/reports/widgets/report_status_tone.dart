import 'package:flutter/widgets.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/l10n/localization.dart';

/// Whether [column] holds a record's status — the cells of one are drawn as
/// status pills, as that status is everywhere else in the app.
bool isReportStatusColumn(ReportColumn column) {
  final id = column.identifier.toLowerCase();
  final tail = id.contains('.') ? id.split('.').last : id;
  return tail == 'status' || tail == 'status_id';
}

enum _Tone { paid, partial, sent, overdue, draft }

/// Status words by the tone they wear, as localization keys.
///
/// Unpaid and pending are amber, not red: money that is merely outstanding
/// is not an alarm — the same call the dashboard's chart makes.
const Map<_Tone, List<String>> _kToneKeys = {
  _Tone.paid: [
    'paid',
    'completed',
    'approved',
    'applied',
    'accepted',
    'active',
    'converted',
    'invoiced',
  ],
  _Tone.partial: [
    'partial',
    'partially_refunded',
    'partially_unapplied',
    'viewed',
  ],
  _Tone.sent: ['sent', 'pending', 'unpaid', 'upcoming', 'logged'],
  _Tone.overdue: ['overdue', 'past_due', 'expired', 'failed'],
  _Tone.draft: [
    'draft',
    'cancelled',
    'paused',
    'refunded',
    'archived',
    'uninvoiced',
  ],
};

/// The colours a status [label] wears.
///
/// The server sends a status as a translated word, not an id, so the word is
/// what there is to go on: it is matched against each known status name in
/// the app's language and — because the server's language can differ from
/// the app's — in English. A word that matches nothing (a custom task
/// status, a language the two disagree on) is neutral, never a guess.
({Color fg, Color bg}) reportStatusTone(BuildContext context, String label) {
  final tokens = context.inTheme;
  final needle = label.trim().toLowerCase();
  _Tone tone = _Tone.draft;
  outer:
  for (final entry in _kToneKeys.entries) {
    for (final key in entry.value) {
      if (needle == context.tr(key).toLowerCase() ||
          needle == key.replaceAll('_', ' ')) {
        tone = entry.key;
        break outer;
      }
    }
  }
  return switch (tone) {
    _Tone.paid => (fg: tokens.paid, bg: tokens.paidSoft),
    _Tone.partial => (fg: tokens.partial, bg: tokens.partialSoft),
    _Tone.sent => (fg: tokens.sent, bg: tokens.sentSoft),
    _Tone.overdue => (fg: tokens.overdue, bg: tokens.overdueSoft),
    _Tone.draft => (fg: tokens.draft, bg: tokens.draftSoft),
  };
}

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/utils/formatting.dart';

/// Whether a record screen is laid out for a phone: the denser form of the
/// record layout (invoiceninja/flutter#187) — the standing card's secondary
/// figures on one line with its status, created / updated as one muted line at
/// the foot of the profile rather than two rows of a Details card, and no icons
/// in the tab strip.
///
/// The device, not the pane: a 440 px desktop pane keeps the pointer layout,
/// where none of it costs a thumb anything. One predicate, so the standing
/// card, the timestamps and the tabs can never disagree about which layout
/// they are in. → `docs/detail-screen-layout.md` § The phone record
/// layout.
bool isPhoneRecordLayout(BuildContext context) => Breakpoints.isPhone(context);

/// A server timestamp as the company writes a date, or null when there is
/// none (epoch 0) or the formatter has not loaded.
///
/// The local calendar day: these are UTC-backed server timestamps, and the
/// ISO date of the UTC instant is the wrong day across the boundary.
String? recordDay(DateTime dt, Formatter? formatter) {
  if (formatter == null || dt.millisecondsSinceEpoch == 0) return null;
  return formatter.date(dt.toLocal().toIso8601String().split('T').first);
}

/// Created / updated as two Details rows, at the foot of a Details card: the
/// two facts about a record a user wants least often.
///
/// **Empty on a phone**, where [RecordTimestampsLine] says the same thing in
/// one line under the profile — so a Details card that held nothing else is
/// not drawn at all (each card's `hasContent` is derived from its rows).
List<Widget> recordTimestampRows(
  BuildContext context, {
  required DateTime createdAt,
  required DateTime updatedAt,
  required Formatter? formatter,
}) {
  if (isPhoneRecordLayout(context)) return const [];
  final created = recordDay(createdAt, formatter);
  final updated = recordDay(updatedAt, formatter);
  return [
    if (created != null)
      DetailInfoRow(
        label: context.tr('created_at'),
        value: created,
        copyable: false,
      ),
    if (updated != null)
      DetailInfoRow(
        label: context.tr('updated_at'),
        value: updated,
        copyable: false,
      ),
  ];
}

/// "Created 17/05/2025 · Updated 25/11/2025", muted and centred, on a phone
/// only — the
/// [recordTimestampRows] twin. Placed by `EntityRecordColumn.timestamps`, last
/// above the tab strip.
///
/// **Owns its trailing gap**; the gap above is the profile's (see
/// `EntityRecordColumn`).
///
/// `ink2`, not `ink3`: at 12 px the muted tone is under the 4.5:1 floor on the
/// page in the default light theme.
class RecordTimestampsLine extends StatelessWidget {
  const RecordTimestampsLine({
    super.key,
    required this.createdAt,
    required this.updatedAt,
    required this.formatter,
    this.lastLogin,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final Formatter? formatter;

  /// A portal login (a vendor's), the same kind of fact: when, not what.
  /// The host's Details card leaves its row out on a phone.
  final DateTime? lastLogin;

  /// What the line says, or empty when it draws nothing — on a pointer, before
  /// the formatter loads, or for a record created offline (epoch-0 dates).
  List<String> _parts(BuildContext context) {
    if (!isPhoneRecordLayout(context)) return const [];
    final created = recordDay(createdAt, formatter);
    final updated = recordDay(updatedAt, formatter);
    final lastLogin = this.lastLogin;
    final login = lastLogin == null ? null : recordDay(lastLogin, formatter);
    return [
      if (created != null) context.tr('created_short', {'date': created}),
      if (updated != null) context.tr('updated_short', {'date': updated}),
      if (login != null) context.tr('last_login_short', {'date': login}),
    ];
  }

  /// Whether this line draws anything here. `EntityRecordColumn` asks before
  /// it has the profile pay the gap above the line: a gap paid for a line that
  /// then draws nothing stood above the tabs for as long as a record stayed
  /// unsynced.
  bool drawsIn(BuildContext context) => _parts(context).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final parts = _parts(context);
    if (parts.isEmpty) return const SizedBox.shrink();
    // No gap of its own above: `EntityRecordColumn` has the profile pay one
    // when it draws, and the standing card or comments already carry theirs.
    // Little below — the tab strip carries its own top inset. Centred: the
    // footer of everything above the tabs, not one more fact in it. Inset by
    // the cards' own padding both sides, so a wrapped line stays inside their
    // text column.
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: InSpacing.lg(context),
        end: InSpacing.lg(context),
        bottom: InSpacing.xs,
      ),
      child: Text(
        // Each part holds together ("Updated" never ends a line with its date
        // on the next); a narrow phone or a large text scale breaks between
        // parts.
        parts.map((p) => p.replaceAll(' ', '\u00A0')).join('  ·  '),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
      ),
    );
  }
}

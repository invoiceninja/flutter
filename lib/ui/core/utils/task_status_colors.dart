/// Colour resolution for a task status — the single path shared by the task
/// list pill, the kanban column header dot, the Settings → Task Statuses row
/// dot, and that screen's live preview. Never parse `TaskStatus.color` inline.
///
/// ## Why a status can have no colour
///
/// The server creates four task statuses for every new company
/// (`CreateCompanyTaskStatuses.php`: Backlog / Ready to do / In progress /
/// Done, named through `ctrans` in the company's locale) and **never sets a
/// colour** — `TaskStatus::insert()` bypasses Eloquent, so `color` falls to the
/// MySQL column default `'#fff'`. API-created statuses get `''` instead
/// (`TaskStatusFactory`, plus the store/update requests coerce `null` → `''`).
/// So `''`, `#fff` and `#ffffff` are all live "no colour chosen" sentinels, and
/// white is safe to read as unset: this app's picker writes only
/// `kStatusSwatches` values (none of them white) because the task-status swatch
/// grid passes no `allowCustom`. admin-portal applies the same `!= '#fff'`
/// rule.
///
/// Unset + a recognised built-in name ⇒ the matching invoice/quote status token
/// pair, so the four defaults read grey / blue / amber / green instead of one
/// undifferentiated grey (invoiceninja/flutter#33). Anything else unset keeps
/// the neutral `ink3`. A user-picked hex always wins.
library;

import 'package:flutter/material.dart';

import 'package:admin/app/color_hex.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Built-in status keys in the order the server creates them.
const _kBuiltInStatusKeys = <String>[
  'backlog',
  'ready_to_do',
  'in_progress',
  'done',
];

/// The English names the server stores for an English company — matched
/// alongside the active locale's translation of the same key, since the
/// company's creation locale needn't be the viewer's.
const _kBuiltInStatusEnglish = <String, String>{
  'backlog': 'backlog',
  'ready_to_do': 'ready to do',
  'in_progress': 'in progress',
  'done': 'done',
};

final _whitespaceRun = RegExp(r'\s+');

/// Lower-cased, whitespace-collapsed form used for name comparison, so
/// `'In Progress'`, `'in progress'` and `'  In  progress '` all match.
String _normalize(String s) =>
    s.trim().toLowerCase().replaceAll(_whitespaceRun, ' ');

/// The built-in status [name] corresponds to (`'backlog'`, `'ready_to_do'`,
/// `'in_progress'` or `'done'`), or null when it isn't one of them.
///
/// [tr] resolves a localization key — pass `context.tr` in the app. Matching is
/// case- and whitespace-insensitive against both the translated name and the
/// English one, because the server stores whatever the *company's* locale said
/// at creation time. A company created in a third language falls through to
/// null (neutral), by design.
String? builtInTaskStatusKey(
  String name, {
  required String Function(String) tr,
}) {
  final normalized = _normalize(name);
  if (normalized.isEmpty) return null;
  for (final key in _kBuiltInStatusKeys) {
    if (normalized == _kBuiltInStatusEnglish[key]) return key;
    if (normalized == _normalize(tr(key))) return key;
  }
  return null;
}

/// Foreground (dot + tint seed) and optional paired soft background for a task
/// status. A null `bg` means "let `StatusPill` derive the 15 % tint" — what a
/// per-company hex has always done, since it has no paired soft token.
({Color fg, Color? bg}) taskStatusColors(
  BuildContext context, {
  required String name,
  required String color,
}) {
  final tokens = context.inTheme;
  final explicit = _explicitColor(color);
  if (explicit != null) return (fg: explicit, bg: null);

  return switch (builtInTaskStatusKey(name, tr: context.tr)) {
    'backlog' => (fg: tokens.draft, bg: tokens.draftSoft),
    'ready_to_do' => (fg: tokens.partial, bg: tokens.partialSoft),
    'in_progress' => (fg: tokens.sent, bg: tokens.sentSoft),
    'done' => (fg: tokens.paid, bg: tokens.paidSoft),
    _ => (fg: tokens.ink3, bg: null),
  };
}

/// Every spelling of "no colour chosen": blank, plus white in each hex width
/// the parser accepts. Only `''` and `#fff` occur in practice (the API factory
/// and the MySQL default); the rest keep the check exhaustive so a normalizing
/// client can't sneak white past it.
const _kUnsetColors = <String>{'', 'fff', 'ffffff', 'ffffffff'};

/// The user-chosen colour, or null when [color] is unset (see [_kUnsetColors])
/// or unparseable. Parsing goes through the canonical [parseHexColor]
/// (`#RRGGBB` / `#AARRGGBB`) — 3-char shorthand stays unsupported on purpose:
/// the only shorthand in the wild is the `#fff` sentinel, and expanding it
/// would paint white on white.
Color? _explicitColor(String color) {
  final cleaned = color.trim().replaceAll('#', '').toLowerCase();
  if (_kUnsetColors.contains(cleaned)) return null;
  return parseHexColor(color);
}

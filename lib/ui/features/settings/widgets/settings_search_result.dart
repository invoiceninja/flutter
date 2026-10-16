import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/settings/state/settings_reveal_controller.dart';

// What a settings search row says and does, shared by the settings index and
// the command palette so the two can't describe or open a hit differently.

/// The line under a hit: "Company Details › Address" for a field on a tab,
/// the section alone for a field on a single-page section (or one every tab
/// carries), and the settings group for a section row.
String settingsHitSubtitle(SettingsSearchHit hit, Localization l10n) {
  final section = l10n.lookup(hit.section.titleKey);
  switch (hit.kind) {
    case SettingsSearchHitKind.section:
      return l10n.lookup(
        hit.section.isBasic ? 'basic_settings' : 'advanced_settings',
      );
    case SettingsSearchHitKind.tab:
      return section;
    case SettingsSearchHitKind.field:
      final tab = hit.tabTitleKey;
      return tab == null ? section : '$section › ${l10n.lookup(tab)}';
  }
}

/// [text] with every word of [query] in bold, case-insensitively — so a row
/// shows why it matched. Plain when the query matched only through context
/// (the section, a keyword, the English label).
TextSpan highlightedMatch(String text, String query, {TextStyle? base}) {
  final words = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final lower = text.toLowerCase();
  // A few characters change length when lower-cased (`İ`), which would put
  // the bold in the wrong place; better none than a wrong one.
  if (words.isEmpty || lower.length != text.length) {
    return TextSpan(text: text, style: base);
  }
  final bold = List<bool>.filled(text.length, false);
  for (final w in words) {
    final at = lower.indexOf(w);
    if (at < 0) continue;
    for (var i = at; i < at + w.length; i++) {
      bold[i] = true;
    }
  }
  final strong = (base ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w700,
  );
  final spans = <TextSpan>[];
  var start = 0;
  for (var i = 1; i <= text.length; i++) {
    if (i == text.length || bold[i] != bold[start]) {
      spans.add(
        TextSpan(
          text: text.substring(start, i),
          style: bold[start] ? strong : null,
        ),
      );
      start = i;
    }
  }
  return TextSpan(style: base, children: spans);
}

/// Goes to [hit]'s page and, for a field, asks that page to scroll to and
/// flash it (`SettingsFormShell`). The caller runs the unsaved-changes guard
/// first.
///
/// The request goes in before the navigation: the page usually mounts
/// because of it and finds the request waiting.
void openSettingsSearchHit(BuildContext context, SettingsSearchHit hit) {
  final l10n = Localization.of(context);
  if (hit.revealsField && l10n != null) {
    context.read<SettingsRevealController?>()?.reveal(
      route: hit.route,
      label: l10n.lookup(hit.fieldKey),
    );
  }
  context.go(hit.route);
}

import 'package:flutter/foundation.dart';

import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';

/// One chip in the search box: an applied filter ([ActiveFilterChip]) or the
/// search set aside while a filter is built beside it ([SearchTermChip]).
///
/// Sealed so every place that renders, removes, edits or announces a chip has
/// to say what it does with the search chip — the places that would otherwise
/// silently treat it as a filter.
@immutable
sealed class BoxChip {
  const BoxChip();

  /// Stable while the chip is on screen: what the armed (Backspace / arrow
  /// key) highlight remembers. A filter chip is its key and value, an
  /// aggregate chip its key alone, so ticking another value into it does not
  /// make it a different chip.
  String get id;

  /// Changes whenever the chip's width can — what re-anchors the open menu.
  String get signature;
}

/// One chip in the applied-filter strip.
///
/// Most keys map 1:1 — one applied value → one chip ([aggregate] false,
/// [rawValues] a single element). `checkboxMultiSelect` keys with more than
/// one applied value collapse into a single [aggregate] chip whose [token]
/// carries a combined display value (`status draft, paid, sent`) and whose
/// [rawValues] lists every member so `×` can clear them in one write.
///
/// Named `ActiveFilterChip` (not `FilterChip`) to avoid colliding with
/// Material's `FilterChip` in files that import `package:flutter/material`.
final class ActiveFilterChip extends BoxChip {
  const ActiveFilterChip({
    required this.key,
    required this.token,
    required this.rawValues,
    required this.aggregate,
  });

  /// The filter dimension this chip belongs to.
  final FilterKey key;

  /// Display payload for [FilterTokenChip]. For an [aggregate] chip this is
  /// synthetic: real `displayKey`, combined `displayValue`, empty `rawValue`.
  final FilterToken token;

  /// Every applied raw value this chip stands for. Length 1 for a
  /// non-[aggregate] chip; the whole set for an aggregate one.
  final List<String> rawValues;

  /// True when this single chip represents more than one applied value.
  final bool aggregate;

  @override
  String get id => aggregate ? '${key.id}=*' : '${key.id}=${rawValues.single}';

  @override
  String get signature => '${key.id}=${rawValues.join(',')}';
}

/// The applied search, shown as a chip because the box is holding something
/// else — a filter being built, or text not yet committed. See
/// `TokenSearchController.searchInChip`.
final class SearchTermChip extends BoxChip {
  const SearchTermChip(this.term);

  final String term;

  @override
  String get id => '\u0000search';

  @override
  String get signature => '\u0000search=$term';
}

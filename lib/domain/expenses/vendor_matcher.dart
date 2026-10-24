/// Which of the company's vendors a receipt is from — or none. A leaf.
///
/// A wrong vendor is worse than no vendor: it brings its currency with it,
/// and nobody re-reads a field that already says something plausible. So
/// this only answers when one vendor is clearly meant:
/// * the cleaned receipt line *is* the vendor's name (folded), or
/// * the line *starts with* every word of the vendor's name — `Shell
///   Station Amsterdam` is `Shell Station`, `Blue Bottle Coffee #12` is
///   `Blue Bottle Coffee` — and no other vendor fits as well.
/// A name that merely contains another (`CAFE` in `Cafe Roma`) never counts,
/// and neither does a vendor whose name is shorter than three letters.
library;

import 'package:admin/utils/search_fold.dart';

List<String> _tokens(String s) => foldSearchText(s)
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((t) => t.isNotEmpty)
    .toList();

/// The id of the one active vendor [receiptName] names, or null. [vendors]
/// are the company's active vendors (`VendorRepository.watchActiveNames`).
String? matchVendor(
  String receiptName,
  Iterable<({String id, String name})> vendors,
) {
  final line = _tokens(receiptName);
  if (line.isEmpty) return null;
  final exact = <String>{};
  // id → number of the line's leading words the vendor's name covers.
  final prefix = <String, int>{};
  for (final v in vendors) {
    final name = _tokens(v.name);
    if (name.isEmpty || name.join().length < 3) continue;
    if (name.length == line.length && _startsWith(line, name)) {
      exact.add(v.id);
    } else if (name.length < line.length && _startsWith(line, name)) {
      prefix[v.id] = name.length;
    }
  }
  if (exact.length == 1) return exact.single;
  if (exact.length > 1) return null;
  if (prefix.isEmpty) return null;
  // The most specific name wins — `Shell Station` over `Shell` — but only
  // when nothing else is as specific.
  final best = prefix.values.reduce((a, b) => a > b ? a : b);
  final winners = prefix.entries.where((e) => e.value == best).toList();
  return winners.length == 1 ? winners.single.key : null;
}

bool _startsWith(List<String> line, List<String> name) {
  for (var i = 0; i < name.length; i++) {
    if (line[i] != name[i]) return false;
  }
  return true;
}

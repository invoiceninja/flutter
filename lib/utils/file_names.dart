import 'dart:convert';

/// Characters no platform this app shares files to will accept in a **file
/// name**, plus the ASCII control range.
///
/// `/` is the POSIX path separator and `\` the Windows one, so either turns a
/// name into a path and the write lands in a directory that does not exist. The
/// rest (`:*?"<>|`) are rejected outright by Win32.
final _kIllegal = RegExp(r'[/\\:*?"<>|\x00-\x1f]');

/// Runs of separator-ish characters left behind by the substitution.
final _kRuns = RegExp(r'[-\s_]{2,}');

/// Win32 reserved device names — a file called `NUL.pdf` cannot be created even
/// though every character in it is legal.
const _kReserved = <String>{
  'con',
  'prn',
  'aux',
  'nul',
  'com1',
  'com2',
  'com3',
  'com4',
  'com5',
  'com6',
  'com7',
  'com8',
  'com9',
  'lpt1',
  'lpt2',
  'lpt3',
  'lpt4',
  'lpt5',
  'lpt6',
  'lpt7',
  'lpt8',
  'lpt9',
};

/// Longest base name we will hand to a platform share sheet, **in UTF-8 bytes**.
///
/// Bytes, not characters: `NAME_MAX` is 255 *bytes* on ext4/f2fs and APFS, and 96
/// CJK characters is 288 of them — which fails the write, which `printing`
/// swallows, which is the exact silent failure this file exists to prevent.
/// Well under the limit because on some targets it applies to the whole *path*
/// and the temp directory we are writing into is not ours to measure.
const _kMaxBytes = 96;

/// Make [name] safe to use as a file name on macOS, iOS, Android, Windows and
/// Linux, falling back to [fallback] when nothing usable survives.
///
/// This is a **backstop at the point a name reaches the platform**, not a
/// validator for the caller to reason about — every producer here interpolates
/// something a user or a server controls:
///
///  * a document *number*, whose pattern is a company setting, so `INV/2026/0001`
///    is an ordinary European numbering scheme rather than an edge case;
///  * a saved-version timestamp, which is rendered through the company's
///    `date_format_id` and therefore carries `/` on four of the fourteen formats
///    (including the server's default, `dd/MMM/yyyy`) and a `:` on all of them.
///
/// Why it has to be here and cannot be left to `printing`: every one of that
/// package's native share implementations concatenates the name onto a temp
/// directory and **swallows the failure** — macOS/iOS `catch { print(…); return }`,
/// Android `catch (IOException e) { e.printStackTrace(); }`, Windows an
/// unchecked `ofstream` followed by a `ShellExecute` on a path that was never
/// written. So an illegal name is not an error the user sees; it is a Share
/// button that does nothing at all.
String sanitizeFileName(String name, {String fallback = 'document'}) {
  var out = name.replaceAll(_kIllegal, '-').replaceAll(_kRuns, '-');
  // Windows also refuses a trailing dot or space, and a leading dot would make
  // the file hidden on POSIX.
  out = out.replaceAll(RegExp(r'^[.\s-]+|[.\s-]+$'), '');
  // Rune by rune, and measured in bytes: `substring` counts UTF-16 code units,
  // so it both under-counts a CJK name against `NAME_MAX` and can cut a
  // surrogate pair in half — leaving an unpaired surrogate that the platform
  // channel turns into U+FFFD, and that the trailing strip below will not remove.
  if (utf8.encode(out).length > _kMaxBytes) {
    final kept = StringBuffer();
    var bytes = 0;
    for (final rune in out.runes) {
      final char = String.fromCharCode(rune);
      final width = utf8.encode(char).length;
      if (bytes + width > _kMaxBytes) break;
      kept.write(char);
      bytes += width;
    }
    out = kept.toString().replaceAll(RegExp(r'[.\s-]+$'), '');
  }
  if (out.isEmpty) return fallback;
  // Compared against the whole base name: `NUL` is reserved, `NUL-2` is not.
  if (_kReserved.contains(out.toLowerCase())) return '$out-file';
  return out;
}

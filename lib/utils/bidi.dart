/// Unicode bidi isolates, for mixed-direction text inside a right-to-left
/// paragraph — see docs/right-to-left-layout.md.
///
/// An isolate makes the run between it and [kPdi] lay out on its own, as one
/// unit, in its own direction, so the surrounding Arabic or Hebrew can't pull
/// its neutrals apart: `-$1,234.50` stays one token instead of reading
/// `$1,234.50-`, and an English sentence keeps its full stop at its end.
library;

/// LEFT-TO-RIGHT ISOLATE.
const String kLri = '\u2066';

/// FIRST STRONG ISOLATE: the run takes the direction of its first strong
/// character — right for an Arabic name, left for an amount or an English one.
const String kFsi = '\u2068';

/// POP DIRECTIONAL ISOLATE: closes [kLri] / [kFsi].
const String kPdi = '\u2069';

/// [s] laid out left-to-right as a unit.
String ltrIsolate(String s) => '$kLri$s$kPdi';

/// [s] laid out as a unit, in the direction of its first strong character.
String firstStrongIsolate(String s) => '$kFsi$s$kPdi';

final RegExp _bidiControls = RegExp('[\u200E\u200F\u202A-\u202E\u2066-\u2069]');

/// [s] without directional marks, embeddings or isolates — for text that
/// leaves the screen (a file name, a comparison against stored data).
String stripBidiControls(String s) =>
    s.contains(_bidiControls) ? s.replaceAll(_bidiControls, '') : s;

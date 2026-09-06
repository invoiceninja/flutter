import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// Parse a `#RRGGBB` / `#RGB` hex string (case-insensitive). Returns
/// [fallback] for empty or malformed input (matches the server's color regex
/// + the slate fallback React uses for tags without a color).
Color parseTagColor(String hex, {required Color fallback}) {
  var raw = hex.trim().replaceFirst('#', '');
  if (raw.length == 3) {
    raw = raw.split('').map((c) => '$c$c').join();
  }
  if (raw.length == 6) {
    final v = int.tryParse(raw, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return fallback;
}

/// Rendered in place of a tag whose id resolves to nothing — a tag another
/// user deleted, or the frame between the create's tmp row being deleted and
/// its `id_remap` alias landing (one transaction writes both, and their
/// watches fire in no guaranteed order). Never render the id itself.
const String kUnresolvedTagLabel = '—';

/// A single tag chip — colored dot + name on a tinted rounded rectangle
/// (never a stadium pill — see CLAUDE.md). Pass [onRemove] to show a trailing
/// "×" (the editable form of the chip, used by the tag picker); omit it for
/// read-only display on detail screens and list cells.
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.name,
    this.colorHex = '',
    this.onRemove,
    this.semanticsLabel,
  });

  /// What the chip shows. An unresolvable tag renders [kUnresolvedTagLabel]
  /// here — never the raw id, per `ClientNameLabel`'s rule that a hashid is
  /// meaningless to the user in every state.
  final String name;
  final String colorHex;
  final VoidCallback? onRemove;

  /// Overrides the screen-reader / `debugDumpApp` label. Used when [name] is
  /// the em-dash placeholder, so the id a sighted user must not see is still
  /// available to assistive tech and to a debug dump.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final color = parseTagColor(colorHex, fallback: tokens.ink3);
    return Semantics(
      label: semanticsLabel ?? name,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 3, onRemove == null ? 8 : 4, 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(InRadii.r1),
                child: Icon(Icons.close, size: 13, color: tokens.ink3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

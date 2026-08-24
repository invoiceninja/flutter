import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/avatar_tint.dart';

/// Tinted rounded-square identity badge with initials.
///
/// The shared body behind every initials avatar in the app — Clients and
/// Vendors list rows, and the assigned-user badge on Task rows. The tint comes
/// from [avatarTintFor], so one seed always yields the same colour app-wide;
/// seed on the entity **id**, never the display name, or a rename would change
/// the colour.
///
/// Always a rounded rectangle, never a circle or a pill (see CLAUDE.md
/// § Design system). The 32 px default matches `kColLeadingWidth`, the width
/// [LeadingSelectSlot] reserves on every entity list row.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.seed,
    required this.label,
    this.size = 32,
    this.radius,
    this.fontSize,
  });

  /// Stable identity key hashed into the palette — an entity id.
  final String seed;

  /// Already-extracted initials. Use [initialsFor] to derive them.
  final String label;

  final double size;

  /// Corner radius; defaults to [InRadii.r1], right for the 32 px list size.
  final double? radius;

  /// Defaults to a size-proportional value that lands on exactly 13 at the
  /// 32 px list size — the long-standing metric for Client / Vendor rows.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarTintFor(seed),
        borderRadius: BorderRadius.circular(radius ?? InRadii.r1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize ?? size * 0.40625,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          height: 1,
        ),
      ),
    );
  }
}

/// Initials for an avatar, or null when [name] carries no letters (a
/// number-only identity like `#0009`) — the caller then picks its own fallback
/// (an entity icon on the detail header, a literal `?` on list rows).
///
/// Unicode-aware on purpose: `\P{L}` ("not a Letter") strips punctuation and
/// digits without mangling Cyrillic / CJK / Arabic names into `?`.
String? initialsFor(String name) {
  final nonLetter = RegExp(r'\P{L}', unicode: true);
  final words = name
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(nonLetter, ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return (words.first.characters.first + words.last.characters.first)
      .toUpperCase();
}

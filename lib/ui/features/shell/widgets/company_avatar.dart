import 'package:flutter/material.dart';

import 'package:admin/ui/core/widgets/avatar_tint.dart';
import 'package:admin/utils/url_safety.dart';

/// Small rounded square showing the first letters of [name], tinted with a
/// stable colour derived from [seed]. Used wherever the design system shows
/// a company "logo" — the sidebar header, the picker rows, and the
/// single-company drawer's footer action. (Not the mobile top bar: flutter#50
/// retitled that to the page name.)
///
/// When [logoUrl] is non-null the uploaded logo is drawn on its own (its
/// transparent pixels composite over the surrounding surface, not the tint);
/// the initials only stand in when there is no logo or the load fails.
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({
    required this.name,
    required this.seed,
    this.size = 28,
    this.logoUrl,
    super.key,
  });

  /// Source for the initials. Falls back to '?' when empty.
  final String name;

  /// Stable input for the tint colour. Usually the company id.
  final String seed;

  final double size;

  /// Optional uploaded logo URL. The initials are shown when the image fails to
  /// load or no logo is set; while a logo is (re)loading, `gaplessPlayback`
  /// keeps the current frame painted, so the initials don't flash in.
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final tint = avatarTintFor(seed);
    final initials = _initialsFor(name);
    final radius = BorderRadius.circular(size * 0.32);

    Widget initialsBox() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tint, borderRadius: radius),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
    );

    // Treat unsafe URLs as if no logo was set — the initials fallback handles
    // both "no logo" and "server returned a hostile URL" the same way.
    if (!isSafeHttpsUrl(logoUrl)) return initialsBox();

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          logoUrl!,
          // Keyed by company id so switching companies tears the image down (no
          // stale logo retained), while a same-company re-emit — e.g. the `?v=`
          // cache-bust bump written by the 5-minute background refresh — reuses
          // this element so `gaplessPlayback` keeps the current frame painted
          // until the new (identical) bytes decode. That kills the
          // logo->initials->logo flash without dropping to initials mid-reload
          // (the old `loadingBuilder` is intentionally gone).
          key: ValueKey(seed),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Initials are the fallback for "no logo" / load failure only — never
          // a layer *behind* the logo, so a transparent logo composites over the
          // surrounding surface instead of the tinted avatar.
          errorBuilder: (_, _, _) => initialsBox(),
        ),
      ),
    );
  }
}

String _initialsFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    final s = parts.first;
    return s.characters
        .take(s.runes.length >= 2 ? 2 : 1)
        .toString()
        .toUpperCase();
  }
  return (parts.first.characters.first + parts[1].characters.first)
      .toUpperCase();
}

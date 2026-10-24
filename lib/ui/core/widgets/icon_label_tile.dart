import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// An icon above a label in a bordered, rounded tile — a touch surface with a
/// single job: the dashboard's create sheet (`QuickCreateSheet`) and a phone's
/// Camera / Photos / Files row on a documents surface (`FileDropZone`).
///
/// Sized to its content with a [InSizes.touchTarget] floor, never a fixed
/// height, so the label grows with the text scale (two lines, then an
/// ellipsis). A null [onTap] dims the tile and takes it out of the tap order.
/// [busy] swaps the icon for a spinner — the tile whose work is under way.
class IconLabelTile extends StatelessWidget {
  const IconLabelTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r2);
    final enabled = onTap != null;
    // The busy tile stays at full strength: it is the one doing something.
    final dimmed = !enabled && !busy;
    // `InkWell` gives the tap action only: without this, VoiceOver / TalkBack
    // read "Camera" with no "button", and a dimmed tile as plain text.
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: busy,
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        // The fill is on the Material and the border is on a transparent
        // Container inside the InkWell, so the ripple paints over the fill and
        // stays visible. This is the idiom `no_ink_widget_test.dart` enforces.
        child: Material(
          color: tokens.surface,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              // A floor, not a fixed height: the label must be able to grow
              // with the text scale.
              constraints: const BoxConstraints(minHeight: InSizes.touchTarget),
              decoration: BoxDecoration(
                border: Border.all(color: tokens.border),
                borderRadius: radius,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: InSpacing.xs,
                vertical: InSpacing.md(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox.square(
                      dimension: 22,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.ink2,
                        ),
                      ),
                    )
                  else
                    Icon(icon, size: 22, color: tokens.ink2),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      color: tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Overlays a small red alert badge on the top-end corner of [child] when
/// [hasBounce] is true. Shared by every billing-doc status pill
/// (invoice / quote / credit / purchase order / recurring invoice) so a
/// bounced/errored send is visible in list rows without opening the doc —
/// mirrors admin-portal's `entity_status_chip` alert overlay.
///
/// `clipBehavior: none` lets the badge sit slightly outside the pill's
/// bounds without being clipped by the surrounding row.
class StatusBounceOverlay extends StatelessWidget {
  const StatusBounceOverlay({
    super.key,
    required this.child,
    required this.hasBounce,
  });

  final Widget child;
  final bool hasBounce;

  @override
  Widget build(BuildContext context) {
    if (!hasBounce) return child;
    final tokens = context.inTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          top: -3,
          end: -3,
          child: Tooltip(
            message: context.tr('email_bounced'),
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: tokens.overdue,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.surface, width: 1.5),
              ),
              child: const Icon(
                Icons.priority_high,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

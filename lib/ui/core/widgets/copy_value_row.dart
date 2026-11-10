import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';

/// A value the user will type somewhere else — an email, a server address —
/// in a bordered box with an always-visible Copy button, so it can be read,
/// selected or copied — `CopyableValue`'s hover-only icon can't be reached on
/// a touch browser. Copies through
/// [copyToClipboard], the app's one copy path.
///
/// Used by the mobile-app promo's sign-in step and the API Tokens page's
/// WordPress card.
class CopyValueRow extends StatelessWidget {
  const CopyValueRow({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.only(top: InSpacing.xs),
      child: Container(
        padding: EdgeInsetsDirectional.only(start: InSpacing.md(context)),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        child: Row(
          children: [
            Expanded(
              // A value, so it reads left to right in every locale
              // (docs/right-to-left-layout.md), and it wraps rather than
              // clipping when large text leaves it no room on one line.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SelectableText(
                  value,
                  textDirection: TextDirection.ltr,
                  textAlign: physicalTextAlign(
                    TextAlign.start,
                    Directionality.of(context),
                  ),
                  style: TextStyle(fontSize: 13, color: tokens.ink),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.standard,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(InSizes.touchTarget),
              ),
              tooltip: context.tr('copy'),
              icon: Icon(Icons.copy_outlined, size: 18, color: tokens.ink3),
              onPressed: () => unawaited(copyToClipboard(context, value)),
            ),
          ],
        ),
      ),
    );
  }
}

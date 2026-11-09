import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/dashed_border.dart';

/// A small invoice, live with what the wizard has been told so far: the
/// business name as it is typed, the logo once picked, and a total formatted
/// in the chosen currency — so "$1,250.00" vs "1.250,00 €" quietly confirms
/// the region (docs/first-run-welcome.md).
///
/// It is a picture of paper, so it is painted like paper in both themes (the
/// light palette on white, as the invoice designer's page is) and laid out
/// left-to-right in every locale, like the printed document.
class SetupInvoicePreview extends StatelessWidget {
  const SetupInvoicePreview({
    super.key,
    required this.businessName,
    required this.total,
    this.logo,
    this.onTapLogo,
    this.width = 360,
  });

  final String businessName;

  /// The formatted total, or null while the currency is not known yet.
  final String? total;
  final Uint8List? logo;

  /// When set, the logo slot is the way to add one (the phone layout).
  final VoidCallback? onTapLogo;
  final double width;

  @override
  Widget build(BuildContext context) {
    final motion = InMotion.of(context);
    // The paper's ink: always the light palette, whatever the app's theme.
    const paperInk = InTheme.light;
    final accent = context.inTheme.accent;
    final name = businessName.trim();
    final scale = width / 360;
    final bar = BorderRadius.circular(InRadii.r1);

    Widget line(double w) => Container(
      width: w * scale,
      height: 6 * scale,
      decoration: BoxDecoration(color: paperInk.border, borderRadius: bar),
    );

    final logoSlot = AnimatedSwitcher(
      duration: motion(const Duration(milliseconds: 260)),
      switchInCurve: InMotion.out,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: logo != null
          ? ConstrainedBox(
              key: const ValueKey('logo'),
              constraints: BoxConstraints(
                maxWidth: 120 * scale,
                maxHeight: 48 * scale,
              ),
              child: Image.memory(logo!, fit: BoxFit.contain),
            )
          : DashedBorder(
              key: const ValueKey('placeholder'),
              color: paperInk.borderStrong,
              radius: InRadii.r1,
              child: SizedBox(
                width: 96 * scale,
                height: 40 * scale,
                child: Center(
                  // Where the slot is the way to add one (a phone), it says
                  // so with a glyph — a dashed box alone reads as decoration.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onTapLogo != null) ...[
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 14 * scale,
                          color: paperInk.ink3,
                        ),
                        SizedBox(width: 4 * scale),
                      ],
                      Flexible(
                        child: Text(
                          context.tr('setup_preview_logo'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11 * scale,
                            color: paperInk.ink3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );

    final paper = Container(
      width: width,
      padding: EdgeInsets.all(24 * scale),
      decoration: BoxDecoration(
        color: Colors.white, // paper
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: context.inTheme.border),
        boxShadow: context.inTheme.shadow2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? context.tr('setup_preview_placeholder') : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16 * scale,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: name.isEmpty ? paperInk.ink4 : paperInk.ink,
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              if (onTapLogo != null)
                Semantics(
                  button: true,
                  label: context.tr('setup_add_logo'),
                  excludeSemantics: true,
                  onTap: onTapLogo,
                  // At least a 44 px target, whatever the slot's drawn size.
                  child: GestureDetector(
                    onTap: onTapLogo,
                    behavior: HitTestBehavior.opaque,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: InSizes.touchTarget,
                        minHeight: InSizes.touchTarget,
                      ),
                      child: Center(child: logoSlot),
                    ),
                  ),
                )
              else
                logoSlot,
            ],
          ),
          SizedBox(height: 20 * scale),
          // As written, not upper-cased and letter-spaced: tracking pulls
          // Arabic and Persian joined letters apart, and Greek capitals drop
          // the accents `toUpperCase` keeps.
          Text(
            context.tr('invoice'),
            style: TextStyle(
              fontSize: 11 * scale,
              fontWeight: FontWeight.w600,
              color: paperInk.ink3,
            ),
          ),
          SizedBox(height: 10 * scale),
          line(180),
          SizedBox(height: 8 * scale),
          line(140),
          SizedBox(height: 20 * scale),
          Divider(height: 1, color: paperInk.border),
          SizedBox(height: 12 * scale),
          for (final w in const [210.0, 170.0, 190.0]) ...[
            Row(children: [line(w), const Spacer(), line(44)]),
            SizedBox(height: 10 * scale),
          ],
          SizedBox(height: 8 * scale),
          Row(
            children: [
              Text(
                context.tr('total'),
                style: TextStyle(
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w600,
                  color: paperInk.ink2,
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: motion(InMotion.fast),
                child: total == null
                    ? Container(
                        key: const ValueKey('total-pending'),
                        width: 72 * scale,
                        height: 12 * scale,
                        decoration: BoxDecoration(
                          color: paperInk.surfaceAlt,
                          borderRadius: bar,
                        ),
                      )
                    : Container(
                        key: ValueKey(total),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8 * scale,
                          vertical: 4 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: bar,
                        ),
                        child: Text(
                          total!,
                          style: moneyTextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w700,
                            color: paperInk.ink,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );

    return Semantics(
      label: context.tr('setup_preview_label'),
      container: true,
      // rtl: physical — a picture of the printed page, which reads
      // left-to-right in every locale, like the invoice designer's page.
      child: Directionality(textDirection: TextDirection.ltr, child: paper),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';

/// "We're waiting on this address to be confirmed" — with the Resend action
/// attached to the notice itself.
///
/// Shared by the user detail and user edit screens, which each carried a
/// private copy that had already drifted on its margins. Unlike
/// [SaveFailedBanner] — the house pattern for a banner carrying actions — this
/// one lives *inside* a card ([FormSection] child on both screens), so it keeps
/// the rounded `overdueSoft` box rather than painting a full-bleed strip.
///
/// It is a [Material] and not a `Container` for the same reason
/// [SaveFailedBanner] is one: an ink splash paints on the nearest `Material`
/// ancestor, and [FormSection]'s transparency Material sits *below* this fill —
/// a `Container` would paint its decoration over the splash and the button
/// would give no touch feedback at all.
///
/// Pass [onResend] to hang Resend Email off the notice. Until
/// invoiceninja/flutter#48 the only Resend was a `ListTile` at the bottom of the
/// detail page's Actions section: the notice stated a problem whose fix was a
/// full page-scroll away. Pass null to render the notice alone — the *edit*
/// screen does, because a typed-but-unsaved email change would otherwise mail
/// the previously saved address.
///
/// Deliberately **not** self-gating on `isEmailUnconfirmed`: the edit screen
/// additionally suppresses it in create mode, so the check stays at the call
/// site.
class UnconfirmedEmailBanner extends StatefulWidget {
  const UnconfirmedEmailBanner({super.key, this.onResend});

  /// Enqueue the resend. The caller's `resendEmail` only writes an outbox row,
  /// so this resolves almost immediately — see [_busy].
  final Future<void> Function()? onResend;

  /// Below this *content* width the action moves under the message instead of
  /// beside it. The same 480 the Details rows switch on in
  /// `user_detail_screen.dart`; this LayoutBuilder sits 24px inside that box
  /// (its own padding), so the two flip within 24px of each other and the rule
  /// reads as one: phones stack, tablets and desktop don't.
  static const double _stackBelow = 480;

  @override
  State<UnconfirmedEmailBanner> createState() => _UnconfirmedEmailBannerState();
}

class _UnconfirmedEmailBannerState extends State<UnconfirmedEmailBanner> {
  /// Belt-and-braces against a double-tap. The real protection is
  /// `UserRepository.resendEmail`, which dedups pending `inviteUser` rows so N
  /// taps are one email; this only keeps the button honest while the enqueue
  /// is in flight.
  bool _busy = false;

  Future<void> _resend() async {
    final onResend = widget.onResend;
    if (onResend == null || _busy) return;
    setState(() => _busy = true);
    try {
      await onResend();
    } finally {
      // `finally`, so a throwing enqueue doesn't leave the button dead.
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final showAction = widget.onResend != null;

    return Material(
      color: tokens.overdueSoft,
      borderRadius: BorderRadius.circular(InRadii.r2),
      // Keep the splash inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Padding(
        // 12, not `InSpacing.lg(context)`: this is a nested notice inside a
        // card that has already applied the card inset, and 12 is what both
        // private copies rendered before the extraction.
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Beside the message only when there is genuinely room: wide
            // enough *and* at ordinary text scale. In the wide branch the
            // button is a non-flex `Row` child, so `Expanded` on the message
            // cannot protect the row from a button that outgrows it — and
            // `composeTextScaler` multiplies the in-app factor (max 1.4) by the
            // OS scaler, so real users reach well past it. 14 -> 20 is scale
            // <= 1.43, so the whole in-app range still gets side-by-side.
            final beside =
                constraints.maxWidth >= UnconfirmedEmailBanner._stackBelow &&
                MediaQuery.textScalerOf(context).scale(14) <= 20;

            final iconAndMessage = Row(
              // `start`, not the default `center`: with the message wrapped to
              // two lines a centred icon floats against the middle of the
              // paragraph instead of leading it.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Hold the icon on the first line once the message wraps.
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.email_outlined,
                    size: 20,
                    color: tokens.overdue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('email_sent_to_confirm_email'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.overdue,
                    ),
                  ),
                ),
              ],
            );

            if (!showAction) return iconAndMessage;
            if (beside) {
              // The action is deliberately *not* inside `iconAndMessage`'s
              // Row: that one aligns to `start` so the icon leads line one,
              // and a 48px-tall button under that rule renders its label a
              // half-line below the message. Centred here, the text block and
              // the button read as one line.
              return Row(
                children: [
                  Expanded(child: iconAndMessage),
                  SizedBox(width: InSpacing.md(context)),
                  _action(context, tokens),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                iconAndMessage,
                // No explicit gap: the button's own tap-target padding already
                // separates it from the message, and adding one on top reads
                // as a stray block of empty red.
                Align(
                  alignment: Alignment.centerRight,
                  child: _action(context, tokens),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _action(BuildContext context, InTheme tokens) => TextButton(
    onPressed: _busy ? null : _resend,
    style: TextButton.styleFrom(
      // A floor, never a fixed size: `minimumSize` lets the box grow with the
      // text scaler, where `fixedSize` or a wrapping `SizedBox(height:)` would
      // clamp the line box and slice Inter Tight's descenders. The explicit
      // *width* term is mandatory too — the button themes default to
      // `Size.fromHeight(44)`, i.e. infinite width, which blows up a `Row`.
      // 36 (below M3's 40 default) matches `SaveFailedBanner`'s pointer metric.
      minimumSize: Size(64, Env.isTouchPrimary ? InSizes.touchTarget : 36),
      foregroundColor: tokens.overdue,
    ),
    child: Text(context.tr('resend_email')),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mobile_app_promo_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/qr_code_image.dart';

/// How the promo was closed — the host snoozes the schedule only on
/// [snoozed], and on a bare `null` while it is still mounted (Esc).
enum MobilePromoResult {
  /// Remind me later, ✕ or Esc without engaging.
  snoozed,

  /// Don't show again.
  dismissed,

  /// Closed after copying the link, opening the store or saying it's
  /// installed — the controller has already been told.
  engaged,

  /// Done on the sign-in step.
  done,
}

/// Opens the "get the mobile app" promo (docs/mobile-app-promo.md) for this
/// build's surface and the signed-in account. [isManual] is an open the user
/// asked for — About, the sidebar card, Device Settings — which never moves
/// the automatic schedule.
Future<MobilePromoResult?> showMobileAppPromoDialog(
  BuildContext context, {
  bool isManual = false,
}) {
  final session = context.read<Services>().auth.session.value;
  final controller = context.read<MobileAppPromoController?>();
  final router = GoRouter.maybeOf(context);
  return showDialog<MobilePromoResult>(
    context: context,
    // A stray click beside the card isn't an answer; ✕, Esc and the footer
    // are.
    barrierDismissible: false,
    builder: (_) => MobileAppPromoDialog(
      targets: currentMobilePromoTargets(),
      presentation: currentMobilePromoPresentation(),
      account: MobilePromoAccount.fromSession(session),
      controller: controller,
      isManual: isManual,
      onSetPassword: router == null
          ? null
          : () => router.go('/settings/user_details/password'),
    ),
  );
}

/// The promo card. Every store rule it must keep is decided before it is
/// built: [targets] is iPhone-only on native macOS (Apple guideline 2.3.10),
/// so this widget never names a phone it wasn't handed — the tests pump it
/// with each surface's targets directly, since `kIsWeb` is const under test.
class MobileAppPromoDialog extends StatefulWidget {
  const MobileAppPromoDialog({
    required this.targets,
    required this.presentation,
    required this.account,
    this.controller,
    this.isManual = false,
    this.onSetPassword,
    super.key,
  }) : assert(targets.length > 0);

  final List<MobilePromoTarget> targets;
  final MobilePromoPresentation presentation;
  final MobilePromoAccount account;

  /// Told about engagement and "Don't show again" as they happen. Null in a
  /// harness without one.
  final MobileAppPromoController? controller;
  final bool isManual;

  /// Opens the set-password screen. Null hides the link.
  final VoidCallback? onSetPassword;

  @override
  State<MobileAppPromoDialog> createState() => _MobileAppPromoDialogState();
}

class _MobileAppPromoDialogState extends State<MobileAppPromoDialog> {
  /// How long a click or a key press is ignored after the card appears. It
  /// opens on its own, often under a pointer mid-click or a finger on Enter,
  /// and a reflex there would spend one of the three reminders.
  static const Duration _armDelay = Duration(milliseconds: 500);

  late MobilePromoTarget _target = widget.targets.first;
  bool _armed = false;
  bool _engaged = false;
  bool _signInStep = false;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _armTimer = Timer(_armDelay, () => _armed = true);
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  bool get _isLastReminder => widget.controller?.isLastReminder ?? false;

  /// The native macOS surface — the only one offered just Apple's phones
  /// with a QR code (a phone browser gets a store button).
  bool get _isAppleOnlyQr =>
      widget.presentation == MobilePromoPresentation.qr &&
      widget.targets.length == 1 &&
      widget.targets.first == MobilePromoTarget.ios;

  /// Wraps every action so it does nothing until the card is armed. The
  /// buttons stay enabled — greying them out for half a second would read as
  /// a glitch.
  VoidCallback _guard(VoidCallback action) => () {
    if (_armed) action();
  };

  void _engage() {
    if (!_engaged) setState(() => _engaged = true);
    unawaited(widget.controller?.markEngaged());
  }

  void _pop(MobilePromoResult result) => Navigator.of(context).pop(result);

  void _dismiss() => _pop(
    _engaged || _signInStep
        ? MobilePromoResult.engaged
        : MobilePromoResult.snoozed,
  );

  void _dontShowAgain() {
    unawaited(widget.controller?.finish());
    _pop(MobilePromoResult.dismissed);
  }

  void _done() {
    unawaited(widget.controller?.finish());
    _pop(MobilePromoResult.done);
  }

  Future<void> _copyLink() async {
    _engage();
    await copyToClipboard(context, _target.url);
  }

  Future<void> _openStore() async {
    _engage();
    final opened = await openExternalUrl(context, _target.url);
    if (opened && mounted) setState(() => _signInStep = true);
  }

  void _installed() {
    _engage();
    setState(() => _signInStep = true);
  }

  void _setPassword() {
    final go = widget.onSetPassword;
    _pop(MobilePromoResult.engaged);
    go?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // 720 for the two columns plus the dialog's 40-px insets either side.
    final wide = size.width >= 800 && size.height >= 560 && scale < 1.3;
    // Only when the card has height to spare: the QR code is what the user
    // came for, and it must never fall below the fold for a picture.
    final showsPhone = wide && size.height >= 800;
    final tokens = context.inTheme;
    final close = PositionedDirectional(
      top: InSpacing.xs,
      end: InSpacing.xs,
      child: IconButton(
        // The desktop theme is compact, which would take the 44 down to 36
        // (docs/touch-targets.md, trap 2).
        visualDensity: VisualDensity.standard,
        // Material 3's own floor is 40.
        style: IconButton.styleFrom(
          minimumSize: const Size.square(InSizes.touchTarget),
        ),
        tooltip: context.tr('close'),
        icon: Icon(Icons.close, color: tokens.ink3),
        onPressed: _guard(_dismiss),
      ),
    );
    final panel = _signInStep
        ? _signIn(context)
        : _getIt(context, showsPhone: showsPhone);
    final Widget body;
    if (wide) {
      // The panel's tint is painted behind the row rather than sized with
      // it: the row takes the taller column's height, and an
      // `IntrinsicHeight` can't measure the QR code (`QrImageView` lays out
      // through a `LayoutBuilder`).
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrolls on a short window rather than overflowing; the footer
          // stays pinned, so the way out is always on screen.
          Flexible(
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: 320,
                    child: ColoredBox(color: tokens.accentSoft),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 400,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            InSpacing.xl,
                            InSpacing.xl,
                            InSpacing.xl,
                            InSpacing.sm,
                          ),
                          child: _pitch(context),
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            InSpacing.xl,
                            InSpacing.xxl + InSpacing.sm,
                            InSpacing.xl,
                            InSpacing.xl,
                          ),
                          child: panel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: tokens.border),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: InSpacing.xl,
              vertical: InSpacing.md(context),
            ),
            child: _footer(context),
          ),
        ],
      );
    } else {
      body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          InSpacing.xl,
          InSpacing.xl,
          InSpacing.xl,
          InSpacing.lg(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pitch(context),
            SizedBox(height: InSpacing.md(context)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(InSpacing.lg(context)),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(InRadii.r3),
              ),
              child: panel,
            ),
            const SizedBox(height: InSpacing.xl),
            _footer(context),
          ],
        ),
      );
    }
    // Esc. The route's own handler is off whenever the barrier isn't
    // dismissible (`_DismissModalAction.isEnabled`), so the card brings its
    // own — guarded like every other way out.
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            _guard(_dismiss)();
            return null;
          },
        ),
      },
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: EdgeInsets.symmetric(
          horizontal: size.width < 600 ? 16 : 40,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 720 : 480),
          child: Stack(children: [body, close]),
        ),
      ),
    );
  }

  Widget _pitch(BuildContext context) {
    final tokens = context.inTheme;
    final a = widget.account;
    final features = <(IconData, String, String)>[
      if (a.expensesEnabled)
        (
          Icons.receipt_long_outlined,
          'mobile_app_promo_receipts_title',
          'mobile_app_promo_receipts_body',
        ),
      (
        Icons.call_outlined,
        'mobile_app_promo_calls_title',
        'mobile_app_promo_calls_body',
      ),
      (
        Icons.contact_phone_outlined,
        'mobile_app_promo_caller_id_title',
        'mobile_app_promo_caller_id_body',
      ),
      if (!a.expensesEnabled)
        (
          Icons.cloud_off_outlined,
          'mobile_app_promo_offline_title',
          'mobile_app_promo_offline_body',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Not on native macOS: it labels the phone app, but in a Mac App
        // Store build it can read as this app calling itself a beta
        // (guideline 2.2). The TestFlight caption says so anyway.
        if (!_isAppleOnlyQr) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(InRadii.r1),
            ),
            child: Text(
              context.tr('beta').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
                color: tokens.accentInk,
              ),
            ),
          ),
          SizedBox(height: InSpacing.md(context)),
        ],
        Semantics(
          header: true,
          namesRoute: true,
          child: Text(
            context.tr('mobile_app_promo_title'),
            style: TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: tokens.ink,
            ),
          ),
        ),
        const SizedBox(height: InSpacing.xs + 2),
        Text(
          context.tr('mobile_app_promo_subtitle'),
          style: TextStyle(fontSize: 14, height: 1.4, color: tokens.ink2),
        ),
        const SizedBox(height: InSpacing.xl),
        for (final (icon, title, body) in features)
          _FeatureRow(
            icon: icon,
            title: context.tr(title),
            body: context.tr(body),
          ),
      ],
    );
  }

  Widget _getIt(BuildContext context, {required bool showsPhone}) {
    final tokens = context.inTheme;
    final isQr = widget.presentation == MobilePromoPresentation.qr;
    final isIos = _target == MobilePromoTarget.ios;
    final scanKey = switch (_target) {
      // Only native macOS narrows the offer to Apple's phones, and there the
      // iPad is as good a scanner as the iPhone.
      MobilePromoTarget.ios when _isAppleOnlyQr =>
        'mobile_app_promo_scan_apple_devices',
      MobilePromoTarget.ios => 'mobile_app_promo_scan_iphone',
      MobilePromoTarget.android => 'mobile_app_promo_scan_android',
    };
    final stepKey = isIos
        ? 'mobile_app_promo_testflight_step'
        : 'mobile_app_promo_play_step';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.targets.length > 1) ...[
          SegmentedButton<MobilePromoTarget>(
            showSelectedIcon: false,
            segments: [
              for (final t in widget.targets)
                ButtonSegment(
                  value: t,
                  icon: Icon(
                    t == MobilePromoTarget.ios
                        ? Icons.phone_iphone
                        : Icons.phone_android,
                    size: 18,
                  ),
                  label: Text(
                    context.tr(
                      t == MobilePromoTarget.ios ? 'iphone_app' : 'android_app',
                    ),
                  ),
                ),
            ],
            selected: {_target},
            onSelectionChanged: (s) => setState(() => _target = s.first),
          ),
          SizedBox(height: InSpacing.lg(context)),
        ],
        if (isQr) ...[
          if (showsPhone) const _PhonePeek(),
          QrCodeImage(
            data: _target.url,
            size: 176,
            semanticsLabel: context.tr(
              isIos
                  ? 'mobile_app_promo_qr_iphone'
                  : 'mobile_app_promo_qr_android',
            ),
          ),
          SizedBox(height: InSpacing.md(context)),
          Semantics(
            liveRegion: true,
            child: Text(
              context.tr(scanKey),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
        ] else
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: _guard(() => unawaited(_openStore())),
            icon: Icon(isIos ? Icons.phone_iphone : Icons.phone_android),
            label: Text(
              context.tr(
                isIos ? 'download_iphone_app' : 'download_android_app',
              ),
            ),
          ),
        const SizedBox(height: InSpacing.xs),
        Text(
          context.tr(stepKey),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: tokens.ink3),
        ),
        const SizedBox(height: InSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: InSpacing.xs,
          children: [
            if (isQr)
              TextButton.icon(
                onPressed: _guard(() => unawaited(_copyLink())),
                icon: const Icon(Icons.link, size: 18),
                label: Text(context.tr('copy_link')),
              ),
            TextButton(
              onPressed: _guard(_installed),
              child: Text(context.tr('mobile_app_promo_installed')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _signIn(BuildContext context) {
    final tokens = context.inTheme;
    final a = widget.account;
    final gap = a.providerGaps[_target];
    final small = TextStyle(fontSize: 13, height: 1.4, color: tokens.ink2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('mobile_app_promo_sign_in_title'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        Text(context.tr('mobile_app_promo_sign_in_with'), style: small),
        if (a.email.isNotEmpty) _CopyRow(value: a.email),
        if (a.serverUrl case final url?) ...[
          const SizedBox(height: InSpacing.sm),
          Text(context.tr('mobile_app_promo_server_url_line'), style: small),
          _CopyRow(value: url),
        ],
        if (a.privateNetwork) ...[
          const SizedBox(height: InSpacing.sm),
          Text(
            context.tr('mobile_app_promo_same_network'),
            style: TextStyle(fontSize: 12, height: 1.4, color: tokens.ink3),
          ),
        ],
        if (gap != null) ...[
          SizedBox(height: InSpacing.md(context)),
          Text(
            context.tr('mobile_app_promo_password_hint', {
              'provider': oauthProviderDisplayName(gap),
            }),
            style: small,
          ),
          if (widget.onSetPassword != null) ...[
            // A button, not inline link text: on a phone browser a link
            // needs a visible affordance and a finger-sized target.
            TextButton(
              onPressed: _guard(_setPassword),
              child: Text(context.tr('set_password')),
            ),
          ],
        ],
        const SizedBox(height: InSpacing.sm),
        TextButton.icon(
          onPressed: _guard(() => setState(() => _signInStep = false)),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(context.tr('back')),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final tokens = context.inTheme;
    if (_signInStep) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: PrimaryDialogAction(
          label: context.tr('done'),
          onPressed: _guard(_done),
        ),
      );
    }
    final controller = widget.controller;
    // Snoozing only means something on an automatic open that still has one
    // to come; anywhere else the same button is just Close.
    final snoozes = !widget.isManual && !_isLastReminder && !_engaged;
    // "Don't show again" beside a Close that already ends it would be two
    // buttons for one answer — so only where it says something more: the
    // automatic opens still to come, or a sidebar card that would remain.
    final offersDontShow =
        controller != null &&
        !_engaged &&
        (widget.isManual ? controller.showsSidebarCard : !_isLastReminder);
    final dismiss = OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      autofocus: true,
      onPressed: _guard(_dismiss),
      child: Text(
        context.tr(snoozes ? 'mobile_app_promo_remind_later' : 'close'),
        overflow: TextOverflow.ellipsis,
      ),
    );
    // Both may shrink: a narrow window at a large text size has room for
    // neither label in full, and side by side still beats stacked.
    return Row(
      mainAxisAlignment: offersDontShow
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      children: [
        if (offersDontShow) ...[
          Flexible(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: tokens.ink3),
              onPressed: _guard(_dontShowAgain),
              child: Text(
                context.tr('mobile_app_promo_dont_show_again'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
        ],
        Flexible(child: dismiss),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(InRadii.r2),
            ),
            child: Icon(icon, size: 18, color: tokens.accentInk),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: tokens.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone app's dashboard in a plain frame, peeking above the QR code.
/// Decorative: a screen reader skips it. App UI only — no OS status bar and
/// no device trademark — so it shows no other platform (2.3.10).
class _PhonePeek extends StatelessWidget {
  const _PhonePeek();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.md(context)),
      child: Container(
        width: 150,
        height: 150,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.border),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(InRadii.r4),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(InRadii.r3),
          ),
          child: Image.asset(
            dark
                ? 'assets/images/mobile_promo_phone_dark.png'
                : 'assets/images/mobile_promo_phone_light.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// A value to type on the phone, with a copy button that is always visible —
/// `CopyableValue`'s hover-only icon can't be reached on a touch browser.
class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.value});

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
              child: SelectableText(
                value,
                maxLines: 1,
                style: TextStyle(fontSize: 13, color: tokens.ink),
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

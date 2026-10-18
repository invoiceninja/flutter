import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/mobile_app_promo_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';

/// Opens the mobile-app promo on its own when it is due, and counts the days
/// this device is used (docs/mobile-app-promo.md).
///
/// Mounted inside the authenticated shell (`ScaffoldWithNav`), so it can
/// never land over `/login`, `/lock` or `/setup`. It waits for the landing
/// screen to settle, then for a quiet moment ([QuietMomentCheck]) — and gives
/// up for the launch if none comes within [_giveUpAfter]. A launch that
/// already showed another automatic dialog ([AutomaticDialogs]) is left
/// alone, and so is any while the What's New dialog holds it back
/// ([MobileAppPromoController.isDue]).
///
/// Inert without a [MobileAppPromoController] provider or with its
/// `promote` off — every harness that pumps the shell.
class MobileAppPromoHost extends StatefulWidget {
  const MobileAppPromoHost({required this.child, super.key});

  final Widget child;

  @override
  State<MobileAppPromoHost> createState() => _MobileAppPromoHostState();
}

class _MobileAppPromoHostState extends State<MobileAppPromoHost> {
  static const Duration _settle = Duration(seconds: 4);
  static const Duration _retry = Duration(seconds: 3);
  static const Duration _giveUpAfter = Duration(seconds: 60);

  MobileAppPromoController? _controller;
  ValueListenable<AuthSession?>? _session;
  Timer? _timer;

  /// Quiet-moment checks left this launch; null until armed. Counted rather
  /// than timed against the wall clock, which a test's fake time can't move.
  int? _checksLeft;

  /// Made when the open is armed, so input during the settle counts.
  QuietMomentCheck? _quiet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = context.read<MobileAppPromoController?>();
    if (controller == null || !controller.promote) return;
    _controller = controller;
    _session = context.read<Services>().auth.session..addListener(_onSession);
    // After the frame: recording the day notifies the controller, and its
    // root provider must not hear that in the middle of this build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  @override
  void dispose() {
    _session?.removeListener(_onSession);
    _timer?.cancel();
    super.dispose();
  }

  bool get _eligible =>
      mobilePromoEligible(_session?.value) &&
      currentMobilePromoTargets().isNotEmpty;

  void _onSession() {
    final controller = _controller;
    if (controller == null || !mounted || !_eligible) return;
    unawaited(controller.recordUseDay(Date.today()));
    // Armed once per shell; [MobileAppPromoController.shownThisLaunch] keeps
    // a remounted shell from trying again.
    if (_checksLeft != null || controller.shownThisLaunch) return;
    if (AutomaticDialogs.shownThisLaunch) return;
    if (!controller.isDue(DateTime.now())) return;
    _checksLeft =
        1 + (_giveUpAfter - _settle).inMilliseconds ~/ _retry.inMilliseconds;
    _quiet = QuietMomentCheck();
    _timer = Timer(_settle, _tryShow);
  }

  void _tryShow() {
    _timer = null;
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (controller.shownThisLaunch || AutomaticDialogs.shownThisLaunch) return;
    if (!_eligible || !controller.isDue(DateTime.now())) return;
    final left = _checksLeft! - 1;
    _checksLeft = left;
    if (left < 0) return;
    if (!_quiet!.isQuiet(context)) {
      _timer = Timer(_retry, _tryShow);
      return;
    }
    unawaited(_show(controller));
  }

  Future<void> _show(MobileAppPromoController controller) async {
    controller.shownThisLaunch = true;
    AutomaticDialogs.noteShown();
    final result = await showMobileAppPromoDialog(context);
    // A `null` is Esc — or the shell page being replaced under the dialog (a
    // 401, the idle timeout, `/setup`), which unmounts this host too and is
    // not the user saying "later".
    if (result == MobilePromoResult.snoozed || (result == null && mounted)) {
      await controller.snooze(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

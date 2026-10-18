import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/features/whats_new/whats_new_dialog.dart';

/// Opens the What's New dialog on its own after an update
/// (docs/whats-new-dialog.md).
///
/// Mounted inside the authenticated shell, like `MobileAppPromoHost`, so it
/// never lands over `/login`, `/lock` or `/setup`. It waits for the landing
/// screen to settle, then for a quiet moment ([QuietMomentCheck]), and gives
/// up for the launch if none comes within [_giveUpAfter] — which counts
/// against the controller's attempts.
///
/// Unlike the promo it does not stand down for a launch that already showed
/// another automatic dialog: a user with no name gets that prompt on every
/// launch, and the notes would never come. It waits behind it instead — an
/// open dialog is not a quiet moment.
///
/// Inert without a [WhatsNewController] provider or with nothing pending —
/// every harness, since only `main()` arms the controller.
class WhatsNewHost extends StatefulWidget {
  const WhatsNewHost({required this.child, super.key});

  final Widget child;

  @override
  State<WhatsNewHost> createState() => _WhatsNewHostState();
}

class _WhatsNewHostState extends State<WhatsNewHost> {
  /// Sooner than the promo's: this belongs to the update just installed.
  static const Duration _settle = Duration(seconds: 2);
  static const Duration _retry = Duration(seconds: 3);
  static const Duration _giveUpAfter = Duration(seconds: 60);

  WhatsNewController? _controller;
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
    final controller = context.read<WhatsNewController?>();
    if (controller == null || !controller.autoOpens) return;
    _controller = controller;
    _session = context.read<Services>().auth.session..addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  @override
  void dispose() {
    _session?.removeListener(_onSession);
    _timer?.cancel();
    super.dispose();
  }

  /// A live session that isn't the demo account's.
  bool get _eligible {
    final session = _session?.value;
    return session != null && !session.isDemo;
  }

  bool get _mayOpen {
    final controller = _controller;
    return controller != null &&
        controller.autoOpens &&
        !controller.shownThisLaunch &&
        _eligible;
  }

  void _onSession() {
    if (!mounted || _checksLeft != null || !_mayOpen) return;
    _checksLeft =
        1 + (_giveUpAfter - _settle).inMilliseconds ~/ _retry.inMilliseconds;
    _quiet = QuietMomentCheck();
    _timer = Timer(_settle, _tryShow);
  }

  void _tryShow() {
    _timer = null;
    if (!mounted || !_mayOpen) return;
    final left = _checksLeft! - 1;
    _checksLeft = left;
    if (left < 0) {
      unawaited(_controller!.noteGaveUp());
      return;
    }
    if (!_quiet!.isQuiet(context)) {
      _timer = Timer(_retry, _tryShow);
      return;
    }
    unawaited(_show(_controller!));
  }

  Future<void> _show(WhatsNewController controller) async {
    controller.shownThisLaunch = true;
    AutomaticDialogs.noteShown();
    final releases = controller.pending;
    unawaited(controller.noteOpened(DateTime.now()));
    final result = await showWhatsNewDialog(
      context,
      releases: releases,
      since: controller.state.seenVersion,
    );
    // A `null` is the shell page replaced under the dialog — a 401, the idle
    // timeout, `/setup` — which unmounts this host too: not read, so it comes
    // back next launch.
    if (!mounted || result == null) return;
    await controller.markSeen();
    if (!mounted) return;
    await followWhatsNewResult(context, result);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

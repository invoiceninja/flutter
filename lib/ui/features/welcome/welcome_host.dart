import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/welcome.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/features/welcome/welcome_dialog.dart';

/// Opens the first-run Welcome on its own (docs/first-run-welcome.md).
///
/// Mounted outermost in the authenticated shell, so it never lands over
/// `/login`, `/lock` or `/setup`. Unlike What's New it does not hunt for a
/// quiet moment for a minute: a welcome that turns up forty seconds into
/// work is a pop-up. It opens [_arrive] after the shell's first frame, or —
/// if the user is already busy (input, a dialog, a form) — retries briefly
/// and then stands down for the launch, which counts as one of the
/// controller's attempts. A launch that arrived by a link stands down at
/// once and spends nothing: the user came for something specific.
///
/// Listens to the controller as well as checking at mount: the decision is
/// written at sign-in, which can land just after the shell mounts.
///
/// Inert without a [WelcomeController] provider — every harness, since only
/// `main()` wires the sign-in hook that arms it.
class WelcomeHost extends StatefulWidget {
  const WelcomeHost({required this.child, super.key});

  final Widget child;

  @override
  State<WelcomeHost> createState() => _WelcomeHostState();
}

class _WelcomeHostState extends State<WelcomeHost> {
  static const Duration _arrive = Duration(milliseconds: 400);
  static const Duration _retry = Duration(milliseconds: 500);

  /// How long the user may be busy before the Welcome gives up the launch.
  static const Duration _patience = Duration(seconds: 4);

  WelcomeController? _controller;
  ValueListenable<AuthSession?>? _session;
  Timer? _timer;
  int? _checksLeft;
  QuietMomentCheck? _quiet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    WelcomeController? controller;
    try {
      controller = context.read<WelcomeController?>();
    } on ProviderNotFoundException {
      controller = null;
    }
    if (controller == null) return;
    _controller = controller..addListener(_arm);
    _session = context.read<Services>().auth.session..addListener(_arm);
    WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
  }

  @override
  void dispose() {
    _controller?.removeListener(_arm);
    _session?.removeListener(_arm);
    _timer?.cancel();
    super.dispose();
  }

  bool get _mayOpen {
    final controller = _controller;
    final session = _session?.value;
    return controller != null &&
        controller.autoOpens &&
        !controller.shownThisLaunch &&
        !controller.stoodDownThisLaunch &&
        session != null &&
        !session.isDemo;
  }

  void _arm() {
    if (!mounted || _checksLeft != null || !_mayOpen) return;
    if (_arrivedByLink()) {
      // Spent nothing: the next launch without a link greets them.
      _checksLeft = 0;
      _controller!.stoodDownThisLaunch = true;
      return;
    }
    _checksLeft =
        1 + (_patience - _arrive).inMilliseconds ~/ _retry.inMilliseconds;
    _quiet = QuietMomentCheck();
    _timer = Timer(_arrive, _tryShow);
  }

  bool _arrivedByLink() {
    try {
      return context.read<Services>().deepLinks.arrivedThisLaunch;
    } catch (_) {
      return false;
    }
  }

  void _tryShow() {
    _timer = null;
    if (!mounted || !_mayOpen) return;
    final left = _checksLeft! - 1;
    _checksLeft = left;
    if (left < 0) {
      _controller!.stoodDownThisLaunch = true;
      unawaited(_controller!.noteGaveUp());
      return;
    }
    if (_arrivedByLink() || !_quiet!.isQuiet(context)) {
      if (_arrivedByLink()) {
        _controller!.stoodDownThisLaunch = true;
        return;
      }
      _timer = Timer(_retry, _tryShow);
      return;
    }
    unawaited(_show(_controller!));
  }

  Future<void> _show(WelcomeController controller) async {
    controller.shownThisLaunch = true;
    AutomaticDialogs.noteShown();
    unawaited(controller.noteOpened());
    var swiped = false;
    final result = await showWelcomeDialog(
      context,
      kind: controller.currentKind ?? WelcomeKind.existingAccount,
      onSwipeClosed: () => swiped = true,
    );
    // A `null` that wasn't a swipe is the shell page replaced under the
    // Welcome — a 401, the idle timeout — which unmounts this host too: not
    // read, so it comes back next launch.
    if (result == null && !swiped) return;
    await controller.markSeen();
    if (!mounted) return;
    await followWelcomeResult(context, result);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

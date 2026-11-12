import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:store_services/store_services.dart';

import 'package:admin/app/review_prompt_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/review_prompt.dart';
import 'package:admin/domain/sync/landed_mutation.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/features/review_prompt/review_prompt_dialog.dart';
import 'package:admin/ui/features/feedback/contact_us_dialog.dart';

/// Asks for a store review right after the user finishes something, and
/// counts the days and wins that earn the ask (docs/review-prompt.md).
///
/// Mounted inside the authenticated shell, so it never lands over `/login`,
/// `/lock` or `/setup`. A win the server just confirmed — an invoice
/// emailed, a payment recorded — arms it; it then waits for the outbox to
/// settle and for a quiet moment ([QuietMomentCheck]) and gives up on that
/// win after [ReviewPromptController.momentWindow]. On a store build it asks
/// the OS for its own sheet and shows nothing of its own; elsewhere it opens
/// the review card.
///
/// Inert without a [ReviewPromptController] provider or with its `autoAsk`
/// off — every harness that pumps the shell.
class ReviewPromptHost extends StatefulWidget {
  const ReviewPromptHost({
    required this.child,
    this.prepareNativeReview = StoreReview.prepare,
    this.requestNativeReview = StoreReview.requestReview,
    this.outboxCounts,
    this.isOnline,
    super.key,
  });

  final Widget child;

  /// The OS sheet's warm-up and request; injectable for tests.
  final Future<bool> Function() prepareNativeReview;
  final Future<bool> Function() requestNativeReview;

  /// The company's outbox — rows still to send, and rows waiting for the
  /// user. Null reads `Services.db`; a test passes its own, since a live
  /// Drift watch stream never settles under `pumpAndSettle`.
  final Future<({int pending, int attention})> Function(String companyId)?
  outboxCounts;

  /// Null reads `Services.connectivity`.
  final Future<bool> Function()? isOnline;

  @override
  State<ReviewPromptHost> createState() => _ReviewPromptHostState();
}

class _ReviewPromptHostState extends State<ReviewPromptHost>
    with WidgetsBindingObserver {
  /// Long enough for the success toast to be read before anything else.
  static const Duration _settle = Duration(seconds: 2);
  static const Duration _retry = Duration(seconds: 3);

  /// Consecutive checks with an empty outbox before asking — a bulk send
  /// still draining is not "done" yet.
  static const int _quietOutboxChecks = 2;

  ReviewPromptController? _controller;
  Services? _services;
  ValueListenable<AuthSession?>? _session;
  StreamSubscription<LandedMutation>? _landedSub;
  StreamSubscription<SyncEvent>? _eventsSub;
  Timer? _timer;
  QuietMomentCheck? _quiet;
  int _emptyOutboxChecks = 0;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = context.read<ReviewPromptController?>();
    if (controller == null || !controller.autoAsk) return;
    _controller = controller;
    final services = context.read<Services>();
    _services = services;
    _session = services.auth.session..addListener(_onSession);
    _landedSub = services.sync.landed.listen(_onLanded);
    _eventsSub = services.sync.events.listen(_onEvent);
    WidgetsBinding.instance.addObserver(this);
    // After the frame: recording the day notifies the controller, and its
    // root provider must not hear that in the middle of this build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.removeListener(_onSession);
    unawaited(_landedSub?.cancel());
    unawaited(_eventsSub?.cancel());
    _timer?.cancel();
    super.dispose();
  }

  bool get _eligibleSession {
    final s = _session?.value;
    return s != null && !s.isDemo;
  }

  void _onSession() {
    if (!mounted || !_eligibleSession) return;
    unawaited(_controller?.recordUseDay());
  }

  /// A phone app can sit suspended for days and come back without a new
  /// session; each return is a day of use too.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onSession();
  }

  void _onEvent(SyncEvent event) {
    final controller = _controller;
    if (controller == null || !_eligibleSession) return;
    // A rejected save waits in the outbox, which holds every ask until it
    // is cleared; only a failure the user wasn't shown in place is a reason
    // to stay away for days.
    final problem = switch (event) {
      DeadEvent(:final handledByCaller) => !handledByCaller,
      UnconfirmedEvent(:final handledByCaller) => !handledByCaller,
      ConflictEvent() => true,
      _ => false,
    };
    if (!problem) return;
    _cancel();
    unawaited(controller.noteProblem());
  }

  Future<void> _onLanded(LandedMutation m) async {
    final controller = _controller;
    if (controller == null || !mounted || !_eligibleSession) return;
    final armed = await controller.noteWin(m);
    if (!armed || !mounted || _showing || _timer != null) return;
    if (controller.askedThisLaunch || AutomaticDialogs.shownThisLaunch) return;
    if (!controller.isEligibleAt(controller.now)) return;
    _quiet = QuietMomentCheck();
    _emptyOutboxChecks = 0;
    // Warm Play's review flow now, so the sheet needs no round trip later.
    if (controller.channel.isNative) {
      unawaited(widget.prepareNativeReview());
    }
    _timer = Timer(_settle, _tryShow);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tryShow() async {
    _timer = null;
    final controller = _controller;
    final services = _services;
    if (!mounted || controller == null || services == null) return;
    if (controller.askedThisLaunch || AutomaticDialogs.shownThisLaunch) return;
    final armed = controller.armedAt;
    if (armed == null ||
        controller.now.difference(armed) >
            ReviewPromptController.momentWindow) {
      return; // The moment passed; the next win may bring another.
    }
    final companyId = _session?.value?.currentCompanyId;
    if (companyId == null || !_eligibleSession) return;
    if (services.auth.requiresBiometricUnlock.value) return _retryLater();

    final (:pending, :attention) = await (widget.outboxCounts ?? _outboxCounts)(
      companyId,
    );
    final online =
        await (widget.isOnline ?? () => services.connectivity.isOnline)();
    if (!mounted) return;
    _emptyOutboxChecks = pending == 0 ? _emptyOutboxChecks + 1 : 0;
    if (!controller.isDue(attentionCount: attention, online: online)) return;
    if (_emptyOutboxChecks < _quietOutboxChecks) return _retryLater();
    if (!_quiet!.isQuiet(context)) return _retryLater();
    await _show(controller);
  }

  Future<({int pending, int attention})> _outboxCounts(String companyId) async {
    final outbox = _services!.db.outboxDao;
    return (
      pending: await outbox.watchPendingCount(companyId: companyId).first,
      attention: await outbox.watchAttentionCount(companyId: companyId).first,
    );
  }

  void _retryLater() {
    if (mounted) _timer = Timer(_retry, _tryShow);
  }

  Future<void> _show(ReviewPromptController controller) async {
    _showing = true;
    controller.askedThisLaunch = true;
    AutomaticDialogs.noteShown();
    try {
      if (controller.channel.isNative) {
        if (await widget.requestNativeReview()) {
          await controller.noteNativeAsk();
        }
        return;
      }
      if (!controller.channel.usesCard) return;
      unawaited(controller.noteCardShown());
      final result = await showReviewPromptDialog(
        context,
        channel: controller.channel,
        isLastShow: controller.isLastCardShow,
      );
      // A `null` with the host gone is the shell being replaced under the
      // card (a 401, the idle timeout, `/setup`) — not an answer.
      if (result == null && !mounted) return;
      await controller.noteCardResult(result ?? ReviewCardResult.closed);
      if (result == ReviewCardResult.sendFeedback && mounted) {
        // Opened from here, after the card has closed, so it never stacks
        // over it and Send doesn't land back on "Are you enjoying the app?".
        await showContactUsDialog(
          context,
          intro: context.tr('review_sorry_title'),
        );
      }
    } finally {
      _showing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Debug Panel → Force review prompt: the ask itself, skipping every gate
/// and recording nothing. On a store build only a debug build may call the
/// OS sheet — the panel ships in release, and Google Play forbids a button
/// that triggers it — so the panel hides the row there ([canForceReviewPrompt]).
Future<void> forceReviewPrompt(BuildContext context) async {
  final channel =
      context.read<ReviewPromptController?>()?.channel ??
      currentReviewChannel();
  if (channel.isNative) {
    if (kDebugMode) await StoreReview.requestReview();
    return;
  }
  if (!channel.usesCard) return;
  final result = await showReviewPromptDialog(context, channel: channel);
  if (result == ReviewCardResult.sendFeedback && context.mounted) {
    await showContactUsDialog(context, intro: context.tr('review_sorry_title'));
  }
}

/// Whether the Debug Panel offers [forceReviewPrompt] on this build.
bool canForceReviewPrompt(ReviewChannel channel) =>
    channel.usesCard || (channel.isNative && kDebugMode);

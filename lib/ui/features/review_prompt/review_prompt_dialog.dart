import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/review_prompt_controller.dart';
import 'package:admin/domain/review_prompt.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/review_prompt/review_listing.dart';

/// Opens the review card — the builds no store review system covers (web,
/// Linux, F-Droid, Windows; docs/review-prompt.md). Never on a store build:
/// there only the OS's own sheet may ask.
///
/// The card asks whether the user enjoys the app, then offers the review
/// page to **every** answer — a "Not really" adds Send feedback beside it
/// rather than replacing it, because sending only the happy ones to a review
/// site is review gating, which Capterra's rules and the FTC forbid.
Future<ReviewCardResult?> showReviewPromptDialog(
  BuildContext context, {
  required ReviewChannel channel,
  bool isLastShow = false,
}) {
  assert(channel.usesCard, 'a store build asks only through the OS sheet');
  return showDialog<ReviewCardResult>(
    context: context,
    // A stray click beside the card isn't an answer; ✕, Esc and the buttons
    // are.
    barrierDismissible: false,
    builder: (_) => ReviewPromptDialog(
      channel: channel,
      isLastShow: isLastShow,
      openListing: openReviewListing,
    ),
  );
}

enum _Step { ask, happy, sorry }

/// The review card. Its steps share one ✕, which holds the focus — so Esc
/// always reaches the card's own dismiss and Enter on it is harmless.
class ReviewPromptDialog extends StatefulWidget {
  const ReviewPromptDialog({
    required this.channel,
    required this.openListing,
    this.isLastShow = false,
    super.key,
  });

  final ReviewChannel channel;

  /// The last automatic show: the decline reads "No thanks", not "Not now".
  final bool isLastShow;

  /// Opens the review page; injectable for tests.
  final Future<bool> Function(BuildContext context, ReviewChannel channel)
  openListing;

  @override
  State<ReviewPromptDialog> createState() => _ReviewPromptDialogState();
}

class _ReviewPromptDialogState extends State<ReviewPromptDialog> {
  /// How long a click or key press is ignored after the card appears and
  /// after each step change. It opens on its own, often under a pointer
  /// mid-click; and a double tap on Yes would otherwise land on the next
  /// step's button, which sits where Yes was.
  static const Duration armDelay = Duration(milliseconds: 500);

  final FocusNode _closeFocus = FocusNode(debugLabel: 'review card close');
  _Step _step = _Step.ask;
  bool _armed = false;
  bool _opening = false;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _closeFocus.dispose();
    super.dispose();
  }

  void _arm() {
    _armed = false;
    _armTimer?.cancel();
    _armTimer = Timer(armDelay, () => _armed = true);
  }

  VoidCallback _guard(VoidCallback action) => () {
    if (_armed && !_opening) action();
  };

  void _go(_Step step) {
    setState(() => _step = step);
    _arm();
    // The step's buttons were just replaced; without this the focus falls
    // to the scope and Esc stops reaching the card.
    _closeFocus.requestFocus();
  }

  /// What closing (✕, Esc, Not now) means at this step.
  ReviewCardResult get _closeResult => switch (_step) {
    _Step.ask => ReviewCardResult.closed,
    _Step.happy => ReviewCardResult.closedAfterYes,
    _Step.sorry => ReviewCardResult.unhappy,
  };

  void _pop(ReviewCardResult result) => Navigator.of(context).pop(result);

  void _close() => _pop(_closeResult);

  void _leaveReview() {
    // Launched first, inside the tap, so a browser's popup blocker lets it
    // through — nothing may be awaited before it.
    final opening = widget.openListing(context, widget.channel);
    setState(() => _opening = true);
    unawaited(
      opening.then((opened) {
        if (!mounted) return;
        if (!opened) {
          // The toast said why; the card stays so they can try again.
          setState(() => _opening = false);
          return;
        }
        Notify.success(context, context.tr('review_thanks'));
        _pop(ReviewCardResult.rated);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tokens = context.inTheme;
    final close = PositionedDirectional(
      top: InSpacing.xs,
      end: InSpacing.xs,
      child: IconButton(
        focusNode: _closeFocus,
        autofocus: true,
        // The desktop theme is compact, which would take the 44 down to 36
        // (docs/touch-targets.md, trap 2).
        visualDensity: VisualDensity.standard,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(InSizes.touchTarget),
        ),
        tooltip: context.tr('close'),
        icon: Icon(Icons.close, color: tokens.ink3),
        onPressed: _guard(_close),
      ),
    );
    final (String title, String? body) = switch (_step) {
      _Step.ask => (context.tr('are_you_enjoying_the_app'), null),
      _Step.happy => (
        context.tr('review_happy_title'),
        context.tr('review_helps_others'),
      ),
      _Step.sorry => (context.tr('review_sorry_title'), null),
    };
    final store = reviewDestinationName(context, widget.channel);
    final body0 = Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.xl,
        InSpacing.xl,
        InSpacing.xl,
        InSpacing.lg(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            // Clear of the ✕.
            padding: const EdgeInsetsDirectional.only(end: InSpacing.xl),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/icon.png',
                  width: 40,
                  height: 40,
                  excludeFromSemantics: true,
                ),
                SizedBox(width: InSpacing.md(context)),
                Expanded(
                  // Read out on each step change: the question is the only
                  // part that says the card moved on.
                  child: Semantics(
                    header: true,
                    headingLevel: 1,
                    namesRoute: true,
                    liveRegion: true,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (body != null) ...[
            SizedBox(height: InSpacing.md(context)),
            Text(
              body,
              style: TextStyle(fontSize: 14, height: 1.4, color: tokens.ink2),
            ),
          ],
          if (_step != _Step.ask) ...[
            const SizedBox(height: InSpacing.xs),
            Text(
              context.tr('review_opens_store', {'store': store}),
              style: TextStyle(fontSize: 12, height: 1.4, color: tokens.ink3),
            ),
          ],
          const SizedBox(height: InSpacing.xl),
          _buttons(context),
        ],
      ),
    );
    // Esc. The route's own handler is off whenever the barrier isn't
    // dismissible, so the card brings its own — guarded like every other
    // way out.
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            _guard(_close)();
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
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(child: Stack(children: [body0, close])),
        ),
      ),
    );
  }

  /// Two equal halves, labels free to wrap: side by side at any text size,
  /// never stacked and never cut to "Leave a re…".
  Widget _buttons(BuildContext context) {
    final decline = widget.isLastShow ? 'no_thanks' : 'not_now';
    final (String secondary, VoidCallback onSecondary) = switch (_step) {
      _Step.ask => (context.tr('not_really'), () => _go(_Step.sorry)),
      _Step.happy => (context.tr(decline), _close),
      _Step.sorry => (context.tr('leave_a_review'), _leaveReview),
    };
    final (String primary, VoidCallback onPrimary) = switch (_step) {
      _Step.ask => (context.tr('yes'), () => _go(_Step.happy)),
      _Step.happy => (context.tr('leave_a_review'), _leaveReview),
      _Step.sorry => (
        context.tr('send_feedback'),
        () => _pop(ReviewCardResult.sendFeedback),
      ),
    };
    Widget label(String text) => Text(
      text,
      textAlign: TextAlign.center,
      softWrap: true,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    // Equal heights when one label wraps and the other doesn't.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('review-card-secondary'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: _guard(onSecondary),
              child: label(secondary),
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            // Not `PrimaryDialogAction`: its autofocus and Enter hint are the
            // two things this card must not have — it opens unasked, so Enter
            // may not answer it (the ✕ holds the focus) — and its label
            // doesn't centre when it wraps.
            child: FilledButton(
              key: const ValueKey('review-card-primary'),
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: _guard(onPrimary),
              child: _opening && _step == _Step.happy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : label(primary),
            ),
          ),
        ],
      ),
    );
  }
}

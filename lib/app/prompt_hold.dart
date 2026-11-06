/// How long one automatic prompt keeps another away after it showed — the
/// mobile-app promo and the review prompt, each way (docs/review-prompt.md).
const Duration kAutomaticPromptGap = Duration(days: 7);

/// Whether a prompt last shown at [shownAt] still holds others back at
/// [now], for [span]. A stamp in the future — the clock moved back — holds
/// nothing, or it could hold for however long the jump was.
bool promptHoldsBack(DateTime? shownAt, Duration span, DateTime now) {
  if (shownAt == null) return false;
  final since = now.difference(shownAt);
  return !since.isNegative && since < span;
}

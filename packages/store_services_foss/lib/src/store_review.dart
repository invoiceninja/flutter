/// FOSS stub: the native review sheets need StoreKit or Play's review
/// library, which F-Droid forbids (docs/review-prompt.md).
///
/// [isStoreBuild] is false, so the app picks its own review card with a
/// link out instead, and [prepare] / [requestReview] are never reached.
class StoreReview {
  StoreReview._();

  static const bool isStoreBuild = false;

  static Future<bool> prepare() async => false;

  static Future<bool> requestReview() async => false;
}

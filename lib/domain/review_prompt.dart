import 'package:flutter/foundation.dart';

import 'package:admin/domain/sync/landed_mutation.dart';
import 'package:admin/domain/sync/mutation.dart';

/// The review prompt's pure rules — which store a build asks for, where its
/// listing is, and which confirmed changes are wins (docs/review-prompt.md).
/// A leaf: no Flutter widgets, no services, no store SDK.

/// Compile-time off switch, separate from `kAppIsBeta`: CI can build without
/// the prompt (`--dart-define=IN_REVIEW_PROMPT=false`).
const bool kReviewPromptEnabled = bool.fromEnvironment(
  'IN_REVIEW_PROMPT',
  defaultValue: true,
);

/// The App Store's numeric Apple ID (App Store Connect → General → App
/// Information). Null until the public listing exists; while it is, the
/// Apple builds offer no "Rate the app" link (the native sheet needs none).
const String? kAppStoreId = null;

/// The Android package, which is also the Play listing's id.
const String kPlayStorePackage = 'com.invoiceninja.admin';

/// The Microsoft Store's *Store ID* — not the Partner Center product id
/// (docs/setup.md).
const String kMicrosoftStoreId = '9NG93WNXN797';

/// Capterra's listing, where the builds with no store review system send
/// their reviews (the old app's `kCapterralUrl`).
const String kCapterraReviewUrl =
    'https://www.capterra.com/p/145215/Invoice-Ninja';

/// Where a build sends a review.
enum ReviewChannel {
  /// iOS and macOS store builds: StoreKit's own sheet.
  appleStore,

  /// The Play build: Play's In-App Review sheet.
  playStore,

  /// Windows (Microsoft Store only): our card, then the Store's review page.
  microsoftStore,

  /// Web, Linux and F-Droid: our card, then Capterra.
  capterra,

  /// Nowhere — the demo.
  none;

  /// The OS asks, through its own sheet; we never show a question first.
  bool get isNative => this == appleStore || this == playStore;

  /// We show our own card.
  bool get usesCard => this == microsoftStore || this == capterra;
}

/// The channel for a build. Keyed on [isStoreBuild] (the store package, not
/// its F-Droid twin) rather than on whether the native API answers: a Play
/// build on a phone without Play Services is still a Play build, and a store
/// build must never fall back to a custom prompt.
ReviewChannel resolveReviewChannel({
  required bool isWeb,
  required TargetPlatform platform,
  required bool isStoreBuild,
  required bool isDemo,
}) {
  if (isDemo) return ReviewChannel.none;
  if (isWeb) return ReviewChannel.capterra;
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS =>
      isStoreBuild ? ReviewChannel.appleStore : ReviewChannel.none,
    TargetPlatform.android =>
      isStoreBuild ? ReviewChannel.playStore : ReviewChannel.capterra,
    TargetPlatform.windows => ReviewChannel.microsoftStore,
    TargetPlatform.linux => ReviewChannel.capterra,
    _ => ReviewChannel.none,
  };
}

/// The page a "Rate the app" link opens — the same URLs the plugin's
/// `openStoreListing` builds, reachable from the F-Droid build too. Null
/// where there is none yet (Apple, until [appStoreId] is set).
Uri? reviewListingUri(
  ReviewChannel channel, {
  String? appStoreId = kAppStoreId,
}) => switch (channel) {
  ReviewChannel.appleStore =>
    appStoreId == null
        ? null
        : Uri.parse(
            'https://apps.apple.com/app/id$appStoreId?action=write-review',
          ),
  ReviewChannel.playStore => Uri.parse(
    'https://play.google.com/store/apps/details?id=$kPlayStorePackage',
  ),
  ReviewChannel.microsoftStore => Uri.parse(
    'ms-windows-store://review/?ProductId=$kMicrosoftStoreId',
  ),
  ReviewChannel.capterra => Uri.parse(kCapterraReviewUrl),
  ReviewChannel.none => null,
};

/// The web page to try when [reviewListingUri] is an app scheme the device
/// can't open (no Microsoft Store app).
Uri? reviewListingFallbackUri(ReviewChannel channel) => switch (channel) {
  ReviewChannel.microsoftStore => Uri.parse(
    'https://apps.microsoft.com/detail/$kMicrosoftStoreId',
  ),
  _ => null,
};

/// What a confirmed change says about the user's day.
enum ReviewWin {
  /// Nothing worth counting.
  none,

  /// Real work, counted toward the threshold — but the user's next step is
  /// probably Email or Download, so it is no moment to ask in.
  counts,

  /// A finishing action — sent, paid, a receipt filed. Counts, and may
  /// open the prompt a moment later.
  arms,
}

const _armingKinds = {
  MutationKind.emailEntity,
  MutationKind.sendEInvoice,
  MutationKind.markSent,
  MutationKind.markPaid,
  MutationKind.applyPayment,
  MutationKind.autoBill,
};

const _countingKinds = {
  MutationKind.convertToInvoice,
  MutationKind.approve,
  MutationKind.scheduleEmail,
  // Not queued by any screen today (recurring Send Now rides a save as
  // `send_now`, below), but a send all the same if one ever is.
  MutationKind.sendNow,
};

const _armingSaveParams = {'paid', 'mark_paid', 'mark_sent'};

/// Recurring Send Now and Start ride a save (`?send_now=true`,
/// `?start=true` — `recurring_invoice_actions.dart`), as do Approve and
/// Convert on a quote.
const _countingSaveParams = {
  'approve',
  'convert',
  'auto_bill',
  'send_now',
  'start',
};

const _billingDocs = {
  'invoice',
  'quote',
  'credit',
  'recurring_invoice',
  'purchase_order',
};

/// Classifies one confirmed change (docs/review-prompt.md § Wins).
ReviewWin classifyReviewWin(LandedMutation m) {
  final kind = m.kind;
  if (kind == null) return ReviewWin.none;
  if (_armingKinds.contains(kind)) return ReviewWin.arms;
  if (_countingKinds.contains(kind)) return ReviewWin.counts;
  final type = m.entityType;
  switch (kind) {
    // The list's bulk Start / Stop of a recurring invoice. (A task's timer
    // is a plain save of the task — the `update` case below.)
    case MutationKind.start:
      return type == 'recurring_invoice' ? ReviewWin.counts : ReviewWin.none;
    case MutationKind.create || MutationKind.update:
      final keys = m.saveQueryKeys;
      if (keys.contains('cancel')) return ReviewWin.none;
      if (keys.any(_armingSaveParams.contains)) return ReviewWin.arms;
      if (keys.any(_countingSaveParams.contains)) return ReviewWin.counts;
      // A task's timer starts and stops by saving the task
      // (`TaskRepository.startTimer` / `stopRunningTimer`), so every task save is
      // tracked time — the only win a time-tracking user ever lands.
      if (kind == MutationKind.update) {
        return type == 'task' ? ReviewWin.counts : ReviewWin.none;
      }
      if (type == 'payment' || type == 'expense') return ReviewWin.arms;
      if (type == 'task' || _billingDocs.contains(type)) {
        return ReviewWin.counts;
      }
      return ReviewWin.none;
    default:
      return ReviewWin.none;
  }
}

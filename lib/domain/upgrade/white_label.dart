import 'package:flutter/material.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/core/utils/external_url.dart';

/// Hosted-billing checkout for the self-hosted white-label license.
///
/// Verbatim from React `Licence.tsx:39-41`. admin-portal appends a fixed
/// `account_key` + `product_id=3` (`constants.dart:21-22`); neither belongs
/// here — `product_id` is what the *server* sends the license server while
/// claiming a key (`LicenseController::v5ClaimLicense`), not a checkout
/// parameter, and React ships the bare URL.
///
/// The previous constant (`https://invoiceninja.com/self-host-white-label/`,
/// on the Overview tab) was a marketing path that 404s — pinned by a test so
/// a dead purchase link can't ship silently again.
const String kWhiteLabelPurchaseUrl =
    'https://invoiceninja.invoicing.co/client/subscriptions/O5xe7Rwd7r/purchase';

/// Whether Account Management → Plan shows the White Label card at all:
/// a self-hosted, non-demo session. Buy / renew / re-apply are branches
/// *inside* the card, so a licensed install still gets it.
///
/// The `isHosted` clause is load-bearing and easy to lose: `white_label` is
/// **also a hosted slug** — it lives in `AuthSession._kProSlugs` /
/// `_kEnterpriseSlugs`, `planHeadlineKey` has a dedicated hosted case, and
/// hosted billing sells it (`BillingPortalPurchasev2`, `product_key ==
/// 'whitelabel'`). Gating on a bare `isWhiteLabeled` rendered this card on
/// hosted beside the upgrade card, where its Apply License would POST
/// `claim_license` — which the server hard-gates to self-host and 400s.
bool showWhiteLabelCard(AuthSession? session) {
  if (session == null || session.isHosted) return false;
  // The demo bootstrap logs in with `isHosted: false` (`main.dart`), so the
  // public GitHub Pages build satisfies `isSelfHosted`. Suppress the whole
  // card there, not just the checkout button: a demo account has no server of
  // its own to license, so Apply License is equally meaningless. React gates
  // the same way — `{isSelfHosted() && !isDemo() && <License />}`
  // (`Plan.tsx:70`).
  if (Env.demoMode || session.isDemo) return false;
  return true;
}

/// True when this session should be *offered* a license — [showWhiteLabelCard]
/// minus the installs that already hold one. Drives the purchase button and
/// (via [shouldNagForWhiteLabel]) the sidebar CTA.
bool canPurchaseWhiteLabel(AuthSession? session) =>
    showWhiteLabelCard(session) && !session!.isWhiteLabeled;

/// [canPurchaseWhiteLabel] plus the role check that only persistent chrome
/// needs: a user who can't act on the purchase shouldn't carry the nag on
/// every screen. Mirrors React's `useUnlockButtonForSelfHosted` (self-hosted +
/// unlicensed + admin-or-owner) and admin-portal's dashboard gate.
///
/// The settings card deliberately skips this — someone who navigated to
/// Account Management → Plan asked to see their license state.
bool shouldNagForWhiteLabel(AuthSession? session) {
  if (!canPurchaseWhiteLabel(session)) return false;
  final me = session!.currentCompany;
  // Fail closed on a not-yet-loaded company: an unsolicited upsell is worse
  // than a missing one, and the Plan tab still offers the purchase.
  return me != null && (me.isAdmin || me.isOwner);
}

/// Open the white-label checkout in the host browser.
///
/// Routed through `openExternalUrl` (`ui/core/utils/external_url.dart`) like
/// every other outbound link in the app: it validates the scheme, tries
/// `externalApplication` then `platformDefault`, and toasts
/// `failed_to_open_url` when neither opens. Deliberately the shared *core*
/// helper rather than `oauth_setup_launcher.dart`'s `openExternal` — reaching
/// into another feature package for it would be the wrong direction.
Future<void> launchWhiteLabelPurchase(BuildContext context) async {
  // Toasts on failure — no browser, or a sandbox restriction.
  await openExternalUrl(context, kWhiteLabelPurchaseUrl);
}

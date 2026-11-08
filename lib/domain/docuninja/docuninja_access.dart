/// Which DocuNinja screen a user is shown, as React decides it
/// (`DocuNinjaProvider.tsx`, `pages/documents/join/Join.tsx`,
/// `pages/documents/index/Documents.tsx`). docs/docuninja.md.
library;

/// Where the user stands with DocuNinja for the active company.
enum DocuNinjaAccess {
  /// Self-hosted: DocuNinja is a hosted service.
  unavailable,

  /// The login handshake has not answered yet.
  loading,

  /// No DocuNinja account: React's Join page.
  notJoined,

  /// The account has DocuNinja seats but none for this user. React's Join
  /// redirects such a user away and the module refuses them; the app says so.
  noAccess,

  /// DocuNinja knows the user but has no company paired with this Invoice
  /// Ninja company yet: React's company-setup step (`/api/docuninja/create`).
  companySetup,

  /// A DocuNinja admin on a plan other than `pro`: React's full-page
  /// upgrade wall.
  planWall,

  /// Everything is in place.
  ready,

  /// The handshake could not reach the server.
  offline,

  /// The handshake failed for another reason.
  failed,
}

/// Outcome of the login handshake, before it is mapped to [DocuNinjaAccess].
enum DnLoginOutcome { ok, refused, offline, failed }

/// Maps the handshake's outcome to the screen React would show.
///
/// [refused] is the handshake's 400 / 401, which React reads as "no DocuNinja
/// account" and answers with Join. [seatsBought] is IN's
/// `account.docuninja_num_users`: Join itself sends a user whose account
/// already has seats back to the module (`Join.tsx`, when not `ie`), so a
/// refusal with seats bought means this user was not given one.
DocuNinjaAccess resolveDocuNinjaAccess({
  required bool isHosted,
  required DnLoginOutcome outcome,
  int seatsBought = 0,
  bool companyMatched = false,
  bool dnAdmin = false,
  String dnPlan = '',
}) {
  if (!isHosted) return DocuNinjaAccess.unavailable;
  switch (outcome) {
    case DnLoginOutcome.offline:
      return DocuNinjaAccess.offline;
    case DnLoginOutcome.failed:
      return DocuNinjaAccess.failed;
    case DnLoginOutcome.refused:
      return seatsBought > 0
          ? DocuNinjaAccess.noAccess
          : DocuNinjaAccess.notJoined;
    case DnLoginOutcome.ok:
      if (!companyMatched) return DocuNinjaAccess.companySetup;
      if (dnAdmin && dnPlan != 'pro') return DocuNinjaAccess.planWall;
      return DocuNinjaAccess.ready;
  }
}

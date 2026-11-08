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
/// [refused] is the handshake's 400 / 401. React's provider sends every one
/// to Join with `ie=true`, which skips Join's "the account has seats"
/// redirect, so a refused owner or admin is still offered Create and
/// everyone else is told to ask their admin.
///
/// Once DocuNinja answers, the plan wall comes before company setup, in
/// `Documents.tsx`'s order.
DocuNinjaAccess resolveDocuNinjaAccess({
  required bool isHosted,
  required DnLoginOutcome outcome,
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
      return DocuNinjaAccess.notJoined;
    case DnLoginOutcome.ok:
      if (dnAdmin && dnPlan != 'pro') return DocuNinjaAccess.planWall;
      if (!companyMatched) return DocuNinjaAccess.companySetup;
      return DocuNinjaAccess.ready;
  }
}

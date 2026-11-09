import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/docuninja/docuninja_signed.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// Whether an invoice, quote or purchase order shows [SignedDocumentPill]:
/// DocuNinja reports every signer has signed (`sync.dn_completed`) and is
/// still active for the company. Otherwise the server serves a fresh render
/// rather than the signed copy (`CreateRawPdf` checks `docuninjaActive()`),
/// so the pill would open an unsigned PDF.
///
/// `docuninjaActive()` is the company's `enable_modules` *and*, on hosted,
/// a plan carrying `FEATURE_INVOICE_SETTINGS` (Pro, Enterprise or a trial);
/// [planActive] is that second half ([docuNinjaPlanActive]). A lapsed plan
/// leaves `enable_modules` on.
///
/// Callers pass the pill only when this holds, never a pill that hides
/// itself: the header lays its pills out in a `Wrap`, which spaces even a
/// zero-size child.
bool showSignedDocumentPill(
  Map<String, dynamic>? sync,
  Company? company, {
  required bool planActive,
}) =>
    planActive && (company?.enableModules ?? false) && isDocuNinjaSigned(sync);

/// The plan half of the server's `docuninjaActive()`: a hosted account on
/// Pro, Enterprise or a trial. DocuNinja is a hosted service.
bool docuNinjaPlanActive(AuthSession? session) =>
    session != null && session.isHosted && session.hasProAccess;

/// Whether "Authorized to sign" means anything for [company]: the server's
/// `docuninjaActive()` whole — `enable_modules` *and* a plan that still runs
/// DocuNinja. With the plan lapsed the server ignores `can_sign` on a saved
/// invitation, so a tick there would look saved and then revert; a
/// contact's own value would save, but means nothing until the plan comes
/// back, and is kept on save while hidden. React checks only
/// `enable_modules`. A self-hosted server counts as inactive too (the
/// server's `docuninjaActive()` is hosted, or a developer's local server).
///
/// A widget test whose `Services` fake has no `auth` gets the company flag
/// alone, as `intakeOf` reads its folder.
bool docuNinjaSigningActive(BuildContext context, Company? company) {
  if (!(company?.enableModules ?? false)) return false;
  try {
    return docuNinjaPlanActive(context.read<Services>().auth.session.value);
  } catch (_) {
    return true;
  }
}

/// React's green "Signed Document" badge, beside a signed invoice's, quote's
/// or purchase order's status pill (see [showSignedDocumentPill]).
///
/// A tap opens the document's PDF, which for a signed document is the signed
/// copy: the stored-PDF route serves it in place of a fresh render. React's
/// badge opens the DocuNinja document instead; the app keeps the PDF, which
/// needs no DocuNinja seat (docs/docuninja.md).
class SignedDocumentPill extends StatelessWidget {
  const SignedDocumentPill({super.key, this.onTap});

  /// Opens the signed PDF. Null leaves the pill as a plain label.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = context.tr('signed_document');
    return StatusPill(
      label: label,
      fgColor: tokens.paid,
      bgColor: tokens.paidSoft,
      dotSize: 8,
      textStyle: TextStyle(fontSize: 13, color: tokens.ink),
      onTap: onTap,
      semanticsLabel: label,
      semanticsHint: onTap == null ? null : context.tr('view_pdf'),
    );
  }
}

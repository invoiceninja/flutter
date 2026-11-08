import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/docuninja/docuninja_signed.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// Whether an invoice, quote or purchase order shows [SignedDocumentPill]:
/// DocuNinja reports every signer has signed (`sync.dn_completed`) and is
/// still on for the company. Without the second, the server serves a fresh
/// render rather than the signed copy (`CreateRawPdf` checks
/// `docuninjaActive()`), so the pill would open an unsigned PDF.
///
/// Callers pass the pill only when this holds, never a pill that hides
/// itself: the header lays its pills out in a `Wrap`, which spaces even a
/// zero-size child.
bool showSignedDocumentPill(Map<String, dynamic>? sync, Company? company) =>
    (company?.enableModules ?? false) && isDocuNinjaSigned(sync);

/// React's green "Signed Document" badge, beside a signed invoice's, quote's
/// or purchase order's status pill (see [showSignedDocumentPill]).
///
/// A tap opens the document's PDF, which for a signed document is the signed
/// copy: the stored-PDF route serves it in place of a fresh render. React's
/// badge opens the DocuNinja document instead; the app gains that link with
/// its DocuNinja screens.
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

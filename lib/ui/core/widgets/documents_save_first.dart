import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/attachments_plan_gate.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';

/// The body of the record screen's Documents tab while the record's create
/// has not synced (a `tmp_` id): "Save the record to upload documents". A
/// create FORM takes files itself (`CreateFormDocumentsPanel`,
/// docs/attaching-documents.md). On a hosted plan without attachments
/// (`AuthSession.canAttachDocuments`) saving would not help, so it shows the
/// Enterprise upgrade banner the record screen's own tab shows instead —
/// either way the user learns where documents went rather than finding
/// nothing.
class DocumentsSaveFirstNotice extends StatelessWidget {
  const DocumentsSaveFirstNotice({super.key, this.padding});

  /// Around the content. Null pads by `InSpacing.lg` on every side, as a tab
  /// body does; a card passes [EdgeInsets.zero] because it pads its own body.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final Widget child = !attachmentsAllowed(context)
        ? const PlanGateBanner(
            style: PlanGateStyle.inset,
            level: PlanGateLevel.enterprise,
          )
        : Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: tokens.ink3),
              const SizedBox(width: InSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('save_to_upload_documents'),
                  style: TextStyle(color: tokens.ink3),
                ),
              ),
            ],
          );
    return Padding(
      padding: padding ?? EdgeInsets.all(InSpacing.lg(context)),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment_term.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';

/// Search keys exported for the settings sidebar search. Colocated with the
/// screen so adding / renaming a field updates both ends in one place.
const kPaymentTermsSearchKeys = <String>[
  'payment_terms',
  'name',
  'number_of_days',
];

/// `/settings/payment_terms` — list every payment term. Tap a row to edit;
/// tap "+ New payment term" to create. Sorted by `num_days` ascending
/// (Net 7 before Net 30 before Net 60) — the repo's `watchAll` already
/// orders that way.
class PaymentTermsScreen extends StatelessWidget {
  const PaymentTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.paymentTerms;

    return SettingsEntityListScaffold<PaymentTerm>(
      titleKey: 'payment_terms',
      sectionTitleKey: 'payment_terms',
      newRoute: '/settings/payment_terms/new',
      newLabelKey: 'new_payment_term',
      emptyIcon: Icons.schedule_outlined,
      emptyTitleKey: 'no_payment_terms',
      emptyHintKey: 'no_payment_terms_hint',
      supportsArchive: true,
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      stream: ({required includeArchived}) => includeArchived
          ? repo.watchAllIncludingArchived(companyId: companyId)
          : repo.watchAll(companyId: companyId),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf: (t) => t.isDeleted,
      rowBuilder: (t) => _PaymentTermRow(key: ValueKey(t.id), term: t),
      archivedRowBuilder: (t) =>
          _PaymentTermRow.archived(key: ValueKey(t.id), term: t),
    );
  }
}

class _PaymentTermRow extends StatelessWidget {
  const _PaymentTermRow({required this.term, super.key}) : _isArchived = false;

  /// Variant rendered inside the "Archived" section. Drops the trailing
  /// chevron and renders a muted "Archived" pill instead.
  const _PaymentTermRow.archived({required this.term, super.key})
    : _isArchived = true;

  final PaymentTerm term;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = term.name.trim().isEmpty
        ? context.tr('untitled')
        : term.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(displayName),
          subtitle: Text('${term.numDays} ${context.tr('days')}'),
          trailing: _isArchived
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.draftSoft,
                    borderRadius: BorderRadius.circular(InRadii.r1),
                  ),
                  child: Text(
                    context.tr('archived'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.draft,
                    ),
                  ),
                )
              // An unsynced row takes the state slot rather than sitting
              // beside the chevron — see UnsyncedPill on the width budget.
              : term.isDirty
              ? const UnsyncedPill()
              : const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/payment_terms/${term.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

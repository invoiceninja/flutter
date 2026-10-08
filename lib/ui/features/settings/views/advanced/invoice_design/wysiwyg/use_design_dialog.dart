import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/view_models/design_update_all_mixin.dart';

/// The document types a design can be the default for.
const List<String> kDesignDocumentTypes = [
  'invoice',
  'quote',
  'credit',
  'purchase_order',
];

/// The document types a design that is "for" [entities] can be offered as
/// the default of. A design's own list is not that: it can be empty (a
/// dialog with nothing to tick), and can name types — a statement, a
/// payment receipt — that have no default-design setting, which were then
/// written into the request as though they had.
List<String> designDefaultTypes(Iterable<String> entities) {
  final wanted = entities.toSet();
  final offered = [
    for (final type in kDesignDocumentTypes)
      if (wanted.contains(type)) type,
  ];
  return offered.isEmpty ? kDesignDocumentTypes : offered;
}

CompanySettings _withDesign(CompanySettings s, String entity, String id) =>
    switch (entity) {
      'invoice' => s.copyWith(invoiceDesignId: id),
      'quote' => s.copyWith(quoteDesignId: id),
      'credit' => s.copyWith(creditDesignId: id),
      'purchase_order' => s.copyWith(purchaseOrderDesignId: id),
      _ => s,
    };

/// The document types among [entities] whose default design is [designId].
List<String> entitiesUsingDesign(
  CompanySettings settings,
  String? designId, [
  Iterable<String> entities = kDesignDocumentTypes,
]) {
  if (designId == null || designId.isEmpty) return const [];
  return [
    for (final e in entities)
      if (DesignUpdateAllMixin.designIdFor(settings, e) == designId) e,
  ];
}

/// What making [designId] the default for [entities] writes: the company
/// settings, and — when existing documents are to follow — the one-shot
/// directive `CompanySyncDispatcher` turns into a `POST /designs/set/default`
/// per type once the settings have landed. The same two things the Invoice
/// Design → General page writes.
({CompanySettings settings, Map<String, dynamic>? outboxExtra}) planUseDesign(
  CompanySettings current, {
  required String designId,
  required Iterable<String> entities,
  required bool updateExisting,
}) {
  var settings = current;
  for (final entity in entities) {
    settings = _withDesign(settings, entity, designId);
  }
  return (
    settings: settings,
    outboxExtra: updateExisting && entities.isNotEmpty
        ? {
            '_design_updates': [
              for (final entity in entities)
                {'design_id': designId, 'entity': entity},
            ],
          }
        : null,
  );
}

/// Offer to make a saved design the one new documents use.
///
/// Saving a design used to be where the journey stopped: nothing said it had
/// to be picked on another screen (Invoice Design → General) before any
/// document would use it.
///
/// A design whose create has not reached the server has no id the setting
/// could hold, so it says so instead.
Future<void> showUseDesignDialog(
  BuildContext context, {
  required Services services,
  required String companyId,
  required String designId,
  required List<String> entities,
}) async {
  final id = await services.designs.resolveId(designId);
  if (!context.mounted) return;
  if (id.isEmpty || id.startsWith('tmp_')) {
    Notify.info(context, context.tr('design_still_saving'));
    return;
  }
  final company = await services.company.watchCompany(companyId).first;
  if (company == null || !context.mounted) return;

  final choice = await showDialog<UseDesignChoice>(
    context: context,
    builder: (_) => UseDesignDialog(
      entities: designDefaultTypes(entities),
      alreadyUsing: entitiesUsingDesign(company.settings, id).toSet(),
    ),
  );
  if (choice == null || choice.entities.isEmpty || !context.mounted) return;

  final toasts = Notify.capture(context);
  final tr = context.tr;
  final plan = planUseDesign(
    company.settings,
    designId: id,
    entities: choice.entities,
    updateExisting: choice.updateExisting,
  );
  try {
    await services.company.updateCompany(
      draft: company.copyWith(settings: plan.settings),
      extraOutboxPayload: plan.outboxExtra,
    );
    toasts?.success(tr('design_now_in_use'));
  } catch (_) {
    toasts?.error(tr('an_error_occurred'));
  }
}

typedef UseDesignChoice = ({Set<String> entities, bool updateExisting});

/// Which document types should use the design. Pops a [UseDesignChoice], or
/// null when dismissed.
///
/// It changes what customers are sent, so nothing here happens on a stray
/// Enter: the primary action is not focused and carries no Enter hint.
class UseDesignDialog extends StatefulWidget {
  const UseDesignDialog({
    super.key,
    required this.entities,
    required this.alreadyUsing,
  });

  /// The types the design applies to.
  final List<String> entities;

  /// The types whose default it already is.
  final Set<String> alreadyUsing;

  @override
  State<UseDesignDialog> createState() => _UseDesignDialogState();
}

class _UseDesignDialogState extends State<UseDesignDialog> {
  /// What can still be switched to it.
  late final List<String> _offered = [
    for (final e in widget.entities)
      if (!widget.alreadyUsing.contains(e)) e,
  ];

  /// All ticked: the user came here to use it.
  late final Set<String> _chosen = {..._offered};
  bool _updateExisting = false;

  String _names(BuildContext context, Iterable<String> entities) =>
      [for (final e in entities) context.tr('${e}s')].join(', ');

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hint = TextStyle(fontSize: 13, color: tokens.ink3);
    final nothingLeft = _offered.isEmpty;
    return AlertDialog(
      title: Text(context.tr('use_this_design_for')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.alreadyUsing.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: InSpacing.sm),
                child: Text(
                  '${context.tr('already_used_for')}: '
                  '${_names(context, widget.alreadyUsing)}',
                  style: hint,
                ),
              ),
            if (!nothingLeft) ...[
              Text(context.tr('use_design_hint'), style: hint),
              SizedBox(height: InSpacing.sm),
              for (final entity in _offered)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(context.tr('${entity}s')),
                  value: _chosen.contains(entity),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _chosen.add(entity);
                    } else {
                      _chosen.remove(entity);
                    }
                  }),
                ),
              const Divider(),
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(context.tr('update_existing_documents')),
                value: _updateExisting,
                onChanged: _chosen.isEmpty
                    ? null
                    : (v) => setState(() => _updateExisting = v ?? false),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr(nothingLeft ? 'close' : 'not_now')),
        ),
        if (!nothingLeft)
          PrimaryDialogAction(
            label: context.tr('use_this_design'),
            enabled: _chosen.isNotEmpty,
            autofocus: false,
            showEnterHint: false,
            onPressed: () => Navigator.of(
              context,
            ).pop((entities: {..._chosen}, updateExisting: _updateExisting)),
          ),
      ],
    );
  }
}

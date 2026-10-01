import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/static/pdf_catalogs.dart';
import 'package:admin/domain/custom_field_pdf_offer.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// What the user chose in [showCustomFieldsPdfOfferDialog]: the fields to
/// print, and whether to open the design afterwards to put them in order.
typedef PdfOfferChoice = ({List<PdfFieldOffer> chosen, bool reorder});

/// "Show these on the PDF?" after a save labelled new invoice / product /
/// surcharge fields (React #3360). A new field is otherwise invisible on
/// every document until the user finds Invoice Design → the right section and
/// adds it there. Each field is a toggle, on by default, naming where it will
/// go; the additions land at the end of their section, so a secondary action
/// opens the design to reorder. Null when dismissed.
Future<PdfOfferChoice?> showCustomFieldsPdfOfferDialog(
  BuildContext context,
  List<PdfFieldOffer> offers,
) => showDialog<PdfOfferChoice>(
  context: context,
  builder: (_) => _PdfOfferDialog(offers: offers),
);

class _PdfOfferDialog extends StatefulWidget {
  const _PdfOfferDialog({required this.offers});

  final List<PdfFieldOffer> offers;

  @override
  State<_PdfOfferDialog> createState() => _PdfOfferDialogState();
}

class _PdfOfferDialogState extends State<_PdfOfferDialog> {
  late final Set<String> _on = {for (final o in widget.offers) o.customKey};

  List<PdfFieldOffer> get _chosen => [
    for (final o in widget.offers)
      if (_on.contains(o.customKey)) o,
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final chosen = _chosen;
    return AlertDialog(
      title: Text(context.tr('add_custom_fields_to_pdf')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in widget.offers)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _on.contains(o.customKey),
                  title: Text(o.label),
                  subtitle: Text(
                    context.tr(
                      kPdfVariableSections[o.section]?.titleKey ?? o.section,
                    ),
                    style: TextStyle(color: tokens.ink3),
                  ),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _on.add(o.customKey);
                    } else {
                      _on.remove(o.customKey);
                    }
                  }),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('skip')),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: chosen.isEmpty
              ? null
              : () =>
                    Navigator.of(context).pop((chosen: chosen, reorder: true)),
          child: Text(context.tr('invoice_design')),
        ),
        PrimaryDialogAction(
          label: context.tr('add'),
          enabled: chosen.isNotEmpty,
          // Nothing here takes text, and a stray Enter adding fields to every
          // document is a fair default — the whole point of the prompt.
          onPressed: () =>
              Navigator.of(context).pop((chosen: chosen, reorder: false)),
        ),
      ],
    );
  }
}

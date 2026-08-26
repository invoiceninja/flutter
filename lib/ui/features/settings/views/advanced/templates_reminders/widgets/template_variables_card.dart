import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Copyable variable chips displayed next to the body editor. Source lists
/// mirror React (`react/src/pages/settings/templates-and-reminders/
/// common/constants/variables/{common,payment}-variables.ts`).
///
/// On narrow viewports (< 600 px — the [InSpacing] mobile breakpoint), the
/// four groups collapse into a single [ExpansionTile] titled "Insert
/// variable" so the editor stays above the fold. Tapping a chip copies
/// the token to the clipboard and surfaces a snackbar.
class TemplateVariablesCard extends StatelessWidget {
  const TemplateVariablesCard({super.key, required this.templateKey});

  /// Active template id. Drives the payment-list swap + quote relabel.
  /// `payment` / `payment_partial` / `payment_failed` swap in
  /// [_paymentVariables]; otherwise [_commonVariables] is used. For
  /// `quote` / `quote_reminder1` the first-group header is relabeled
  /// "Quote" instead of "Invoice" so users aren't confused by chips like
  /// `$amount` and `$due_date` filed under Invoice on a quote template.
  final String templateKey;

  @override
  Widget build(BuildContext context) {
    final isPayment = const {
      'payment',
      'payment_partial',
      'payment_failed',
    }.contains(templateKey);
    final variables = isPayment ? _paymentVariables : _commonVariables;
    final firstGroupLabel =
        const {'quote', 'quote_reminder1'}.contains(templateKey)
        ? 'quote'
        : 'invoice';
    final groups = <(String, List<String>)>[
      (firstGroupLabel, variables['invoice']!),
      ('client', variables['client']!),
      ('contact', variables['contact']!),
      ('company', variables['company']!),
    ];

    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    if (isNarrow) {
      // Collapsed by default so the editor remains above the fold on a
      // 375 px phone — opening the expansion tile reveals the four chip
      // groups with their headers.
      return _MobileVariablesTile(
        groups: groups,
        onTapChip: (v) => _copy(context, v),
      );
    }

    return FormSection(
      title: context.tr('variables'),
      children: [
        for (final group in groups)
          _VariableGroup(
            label: context.tr(group.$1),
            tokens: group.$2,
            onTap: (v) => _copy(context, v),
          ),
      ],
    );
  }

  void _copy(BuildContext context, String token) {
    Clipboard.setData(ClipboardData(text: token));
    final msg = context.tr('copied_to_clipboard').replaceFirst(':value', token);
    Notify.info(context, msg);
  }
}

class _VariableGroup extends StatelessWidget {
  const _VariableGroup({
    required this.label,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final List<String> tokens;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.sm,
          children: [
            for (final token in tokens)
              _VariableChip(token: token, onPressed: () => onTap(token)),
          ],
        ),
      ],
    );
  }
}

class _VariableChip extends StatelessWidget {
  const _VariableChip({required this.token, required this.onPressed});

  final String token;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    // Bumped vertical padding + font size from the first cut (6/12) so
    // the chip clears Material's 36 dp minimum hit target for chip-like
    // controls. Total tap height now ~38 dp at 1x density.
    return Semantics(
      button: true,
      label: 'Copy variable $token',
      child: Material(
        color: t.surfaceAlt,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: t.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: InSpacing.sm,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flexible + ellipsis is a safety net: real tokens fit
                // within a chip on a 360 px phone, but a pathologically long
                // token degrades gracefully instead of throwing a RenderFlex
                // overflow. No visual change for existing tokens (a min-axis
                // Row only shrinks the child when space-constrained).
                Flexible(
                  child: Text(
                    token,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kMonoFontFamily,
                      fontSize: 14,
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Copy to clipboard',
                  child: Icon(Icons.copy, size: 14, color: t.ink2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileVariablesTile extends StatelessWidget {
  const _MobileVariablesTile({required this.groups, required this.onTapChip});

  final List<(String, List<String>)> groups;
  final ValueChanged<String> onTapChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(InRadii.r3),
          border: Border.all(color: t.border),
          boxShadow: t.shadow1,
        ),
        child: Theme(
          // ExpansionTile pulls the divider color from the inherited
          // ThemeData — null it out so the open state doesn't draw a
          // 1px line that fights the FormSection-style card chrome.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(),
            title: Text(
              context.tr('variables'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: t.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            childrenPadding: EdgeInsets.symmetric(
              horizontal: InSpacing.lg(context),
              vertical: InSpacing.md(context),
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) SizedBox(height: InSpacing.lg(context)),
                _VariableGroup(
                  label: context.tr(groups[i].$1),
                  tokens: groups[i].$2,
                  onTap: onTapChip,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const Map<String, List<String>> _commonVariables = {
  'invoice': [
    r'$amount',
    r'$balance',
    r'$date',
    r'$due_date',
    r'$footer',
    r'$number',
    r'$payment_url',
    r'$po_number',
    r'$terms',
    r'$view_url',
    r'$assigned_to_user',
    r'$created_by_user',
    r'$discount',
    r'$exchange_rate',
    r'$invoices',
    r'$payment_button',
    r'$payments',
    r'$public_notes',
    r'$view_button',
  ],
  'client': [
    r'$client_address1',
    r'$client.city',
    r'$client.credit_balance',
    r'$client.name',
    r'$client.postal_code',
    r'$client.shipping_address1',
    r'$client.shipping_city',
    r'$client.shipping_postal_code',
    r'$client.state',
    r'$client.address2',
    r'$client.country',
    r'$client.id_number',
    r'$client.phone',
    r'$client.public_notes',
    r'$client.shipping_address2',
    r'$client.shipping_country',
    r'$client.shipping_state',
    r'$client.vat_number',
  ],
  'contact': [
    r'$contact.email',
    r'$contact.first_name',
    r'$contact.last_name',
    r'$contact.phone',
  ],
  'company': [
    r'$company.address1',
    r'$company.address2',
    r'$company.country',
    r'$company.email',
    r'$company.id_number',
    r'$company.name',
    r'$company.phone',
    r'$company.state',
    r'$company.vat_number',
    r'$company.website',
  ],
};

const Map<String, List<String>> _paymentVariables = {
  'invoice': [
    r'$assigned_to_user',
    r'$invoice',
    r'$invoices',
    r'$invoices.balance',
    r'$invoices.po_number',
    r'$payment_button',
    r'$view_button',
    r'$created_by_user',
    r'$invoice_references',
    r'$invoices.amount',
    r'$invoices.due_date',
    r'$payment.status',
    r'$payment_url',
    r'$view_url',
  ],
  'client': [
    r'$client_address1',
    r'$client.city',
    r'$client.credit_balance',
    r'$client.name',
    r'$client.postal_code',
    r'$client.shipping_address1',
    r'$client.shipping_city',
    r'$client.shipping_postal_code',
    r'$client.state',
    r'$client.address2',
    r'$client.country',
    r'$client.id_number',
    r'$client.phone',
    r'$client.public_notes',
    r'$client.shipping_address2',
    r'$client.shipping_country',
    r'$client.shipping_state',
    r'$client.vat_number',
  ],
  'contact': [
    r'$contact.email',
    r'$contact.first_name',
    r'$contact.last_name',
    r'$contact.phone',
  ],
  'company': [
    r'$company.address1',
    r'$company.address2',
    r'$company.country',
    r'$company.email',
    r'$company.id_number',
    r'$company.name',
    r'$company.phone',
    r'$company.state',
    r'$company.vat_number',
    r'$company.website',
  ],
};

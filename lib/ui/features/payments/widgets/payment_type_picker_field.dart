import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/domain/payment_types.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/views/basic/payment_types_screen.dart';

/// What every payment Type picker offers (docs/payment-types.md): each type
/// under the company's name for it ([paymentTypeName]), sorted by that name,
/// still findable by its stock name, with the company's hidden types left
/// out of the opening list.
class PaymentTypeOptions {
  PaymentTypeOptions._(this.items, this._stockNames, this.hidden);

  factory PaymentTypeOptions.of(
    BuildContext context, {
    Set<String> hidden = const {},
  }) {
    final l10n = Localization.of(context);
    final types = context.read<Services>().statics.paymentTypes.values;
    final stock = <String, String>{};
    final items = <PaymentType>[];
    for (final t in types) {
      stock[t.id] = t.name;
      items.add(PaymentType(id: t.id, name: paymentTypeName(l10n, t)));
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return PaymentTypeOptions._(items, stock, hidden);
  }

  /// Every type, labelled and sorted.
  final List<PaymentType> items;
  final Map<String, String> _stockNames;

  /// Ids the company hides from the pickers' opening list.
  final Set<String> hidden;

  /// [id]'s option from the FULL list — never the filtered one, so a selected
  /// type the company later hid still shows (docs/pickers.md).
  PaymentType? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final t in items) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The label, falling back to the id for a nameless entry.
  String displayString(PaymentType t) => t.name.isEmpty ? t.id : t.name;

  /// The stock name, when the company renamed the type — so "Instant" still
  /// finds "Echtzeitüberweisung".
  String searchTextOf(PaymentType t) {
    final stock = _stockNames[t.id] ?? '';
    return stock == t.name ? '' : stock;
  }

  /// For `SearchableDropdownField.idleExcludes`: null when nothing is hidden.
  bool Function(PaymentType)? get idleExcludes =>
      hidden.isEmpty ? null : (t) => hidden.contains(t.id);

  /// For `optionTrailingBuilder`: tags a hidden type a search turned up, so
  /// it doesn't look like it slipped through. Never the selected one.
  Widget Function(BuildContext, PaymentType)? trailingFor(String? selectedId) =>
      hidden.isEmpty
      ? null
      : (context, t) => hidden.contains(t.id) && t.id != selectedId
            ? Text(
                context.tr('hidden'),
                style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
              )
            : const SizedBox.shrink();
}

/// The company's hidden payment types, live from its Drift row — rebuilt when
/// the list changes (the picker's own "Manage payment types" dialog saves it).
/// The stream is created once, not per build (a Drift watch replays on every
/// re-subscribe).
class HiddenPaymentTypesBuilder extends StatefulWidget {
  const HiddenPaymentTypesBuilder({
    super.key,
    required this.companyId,
    required this.builder,
  });

  final String companyId;
  final Widget Function(BuildContext context, Set<String> hidden) builder;

  @override
  State<HiddenPaymentTypesBuilder> createState() =>
      _HiddenPaymentTypesBuilderState();
}

class _HiddenPaymentTypesBuilderState extends State<HiddenPaymentTypesBuilder> {
  late Stream<Company?> _company;

  @override
  void initState() {
    super.initState();
    _company = _watch();
  }

  @override
  void didUpdateWidget(HiddenPaymentTypesBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _company = _watch();
  }

  Stream<Company?> _watch() =>
      context.read<Services>().company.watchCompany(widget.companyId);

  @override
  Widget build(BuildContext context) => StreamBuilder<Company?>(
    stream: _company,
    builder: (context, snapshot) => widget.builder(
      context,
      parseHiddenPaymentTypes(snapshot.data?.settings.hiddenPaymentTypes),
    ),
  );
}

/// The Type picker of the payment and expense forms: company names, hidden
/// types out of the opening list (but still searchable), the whole list
/// shown without typing, and — for a user who may edit company settings — a
/// "Manage payment types" footer that opens the Payment Types page as a
/// dialog over the form, so the record being entered survives.
class PaymentTypePickerField extends StatelessWidget {
  const PaymentTypePickerField({
    super.key,
    required this.companyId,
    required this.label,
    required this.selectedId,
    required this.onChanged,
    this.errorText,
    this.helper,
  });

  final String companyId;
  final String label;
  final String selectedId;

  /// Fires with the picked id, `''` when cleared.
  final ValueChanged<String> onChanged;
  final String? errorText;
  final Widget? helper;

  @override
  Widget build(BuildContext context) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canManage = me?.isAdmin == true || me?.isOwner == true;
    return HiddenPaymentTypesBuilder(
      companyId: companyId,
      builder: (context, hidden) {
        final options = PaymentTypeOptions.of(context, hidden: hidden);
        return SearchableDropdownField<PaymentType>(
          label: label,
          items: options.items,
          initialValue: options.byId(selectedId),
          displayString: options.displayString,
          idOf: (t) => t.id,
          onChanged: (t) => onChanged(t?.id ?? ''),
          errorText: errorText,
          helper: helper,
          idleResults: options.items.length,
          idleExcludes: options.idleExcludes,
          searchTextOf: options.searchTextOf,
          optionTrailingBuilder: options.trailingFor(selectedId),
          footerBuilder: canManage
              ? (footerContext) => _ManageFooter(
                  hiddenCount: hidden.length,
                  onTap: () {
                    // Close the popover first; the dialog opens over the form.
                    FocusManager.instance.primaryFocus?.unfocus();
                    showPaymentTypesDialog(context, companyId: companyId);
                  },
                )
              : null,
        );
      },
    );
  }
}

class _ManageFooter extends StatelessWidget {
  const _ManageFooter({required this.hiddenCount, required this.onTap});

  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final manage = context.tr('manage_payment_types');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: InSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.tune, size: 16, color: accent),
            const SizedBox(width: InSpacing.sm),
            Flexible(
              child: Text(
                hiddenCount == 0
                    ? manage
                    : '${context.tr('hidden_count', {'count': '$hiddenCount'})}'
                          ' · $manage',
                style: TextStyle(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

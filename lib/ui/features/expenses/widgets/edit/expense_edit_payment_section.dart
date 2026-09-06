import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// "Mark paid" toggle revealing the payment-metadata triple (date + type +
/// transaction reference). Per the UX spec § Mark paid toggle: ticking the
/// switch defaults `payment_date = today`; unticking clears all three.
class ExpenseEditPaymentSection extends StatefulWidget {
  const ExpenseEditPaymentSection({super.key, required this.vm});
  final ExpenseEditViewModel vm;

  @override
  State<ExpenseEditPaymentSection> createState() =>
      _ExpenseEditPaymentSectionState();
}

class _ExpenseEditPaymentSectionState extends State<ExpenseEditPaymentSection>
    with FormatterHostMixin {
  late final Services _services;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    loadFormatter(_services, widget.vm.companyId);
  }

  bool get _isPaid =>
      widget.vm.draft.paymentDate != null ||
      widget.vm.draft.paymentTypeId.isNotEmpty ||
      widget.vm.draft.transactionReference.isNotEmpty;

  void _onMarkPaidToggled(bool next) {
    final vm = widget.vm;
    if (next) {
      // Default payment_date to today when first ticked.
      if (vm.draft.paymentDate == null) vm.setPaymentDate(Date.today());
    } else {
      vm.setPaymentDate(null);
      vm.setPaymentTypeId('');
      vm.setTransactionReference('');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final paid = _isPaid;
    return DashboardCardShell(
      title: context.tr('payment'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('mark_paid')),
            value: paid,
            onChanged: _onMarkPaidToggled,
          ),
          if (paid) ...[
            SizedBox(height: InSpacing.sm),
            _PaymentDateField(vm: vm, formatter: formatter),
            _PaymentTypePicker(vm: vm),
            EntityEditField(
              label: context.tr('transaction_reference'),
              initial: vm.draft.transactionReference,
              onChanged: vm.setTransactionReference,
              errorText: vm.fieldErrorFor('transaction_reference'),
              autocorrect: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentDateField extends StatelessWidget {
  const _PaymentDateField({required this.vm, required this.formatter});
  final ExpenseEditViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InDateField(
        value: vm.draft.paymentDate?.toDateTime(),
        onChanged: (picked) {
          vm.setPaymentDate(
            picked == null ? null : Date(picked.year, picked.month, picked.day),
          );
        },
        formatter: formatter,
        labelText: context.tr('payment_date'),
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 10),
        clearable: true,
      ),
    );
  }
}

class _PaymentTypePicker extends StatelessWidget {
  const _PaymentTypePicker({required this.vm});
  final ExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final types = services.statics.paymentTypes.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    PaymentType? selected;
    for (final t in types) {
      if (t.id == vm.draft.paymentTypeId) {
        selected = t;
        break;
      }
    }
    return SearchableDropdownField<PaymentType>(
      label: context.tr('payment_type'),
      items: types,
      initialValue: selected,
      displayString: (t) => t.name,
      idOf: (t) => t.id,
      onChanged: (t) => vm.setPaymentTypeId(t?.id ?? ''),
      errorText: vm.fieldErrorFor('payment_type_id'),
    );
  }
}

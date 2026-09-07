import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';

/// Recurring schedule editor — frequency picker, remaining-cycles
/// affordance (Endless checkbox + disabled-when-checked number input), and
/// the next-send-date `InDateField`. Per UX spec, an inline preview line
/// below the frequency picker shows the next 3 send dates client-side via
/// [nextSendAfter].
class RecurringExpenseEditScheduleSection extends StatefulWidget {
  const RecurringExpenseEditScheduleSection({super.key, required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  State<RecurringExpenseEditScheduleSection> createState() =>
      _RecurringExpenseEditScheduleSectionState();
}

class _RecurringExpenseEditScheduleSectionState
    extends State<RecurringExpenseEditScheduleSection>
    with FormatterHostMixin {
  late final Services _services;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    loadFormatter(_services, widget.vm.companyId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final draft = vm.draft;
    final endless = draft.remainingCycles == -1;

    return DashboardCardShell(
      title: context.tr('recurring_schedule'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FrequencyPicker(vm: vm),
          if (draft.nextSendDate != null) _NextRunsPreview(vm: vm),
          SizedBox(height: InSpacing.sm),
          InDateField(
            value: draft.nextSendDate?.toDateTime(),
            onChanged: (picked) {
              vm.setNextSendDate(
                picked == null
                    ? null
                    : Date(picked.year, picked.month, picked.day),
              );
            },
            formatter: formatter,
            labelText: context.tr('next_send_date'),
            firstDate: DateTime(DateTime.now().year - 2),
            lastDate: DateTime(DateTime.now().year + 20),
            clearable: true,
          ),
          SizedBox(height: InSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('endless')),
            value: endless,
            onChanged: vm.setEndlessCycles,
          ),
          if (!endless)
            EntityEditField(
              numeric: true,
              useCommaAsDecimalPlace: vm.useCommaAsDecimalPlace,
              label: context.tr('remaining_cycles'),
              initial:
                  '${draft.remainingCycles < 0 ? 1 : draft.remainingCycles}',
              onChanged: (raw) {
                final n = int.tryParse(raw.trim());
                if (n != null && n >= 0) {
                  vm.setRemainingCycles(n);
                }
              },
              keyboardType: TextInputType.number,
              errorText: vm.fieldErrorFor('remaining_cycles'),
            ),
        ],
      ),
    );
  }
}

class _FrequencyPicker extends StatelessWidget {
  const _FrequencyPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final items = kRecurringFrequencyOrdered;
    final selected = vm.draft.frequencyId;
    return SearchableDropdownField<String>(
      label: context.tr('frequency'),
      items: items,
      initialValue: items.contains(selected) ? selected : null,
      displayString: (id) {
        final key = kRecurringFrequencyLabelKey[id];
        return key == null ? id : context.tr(key);
      },
      idOf: (id) => id,
      onChanged: (id) => vm.setFrequencyId(id ?? items.first),
      errorText: vm.fieldErrorFor('frequency_id'),
    );
  }
}

/// "Next: May 21, Jun 21, Jul 21" preview below the frequency picker. The
/// dates come from [nextSendAfter] — three steps starting from the
/// current `next_send_date`.
class _NextRunsPreview extends StatelessWidget {
  const _NextRunsPreview({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    final start = draft.nextSendDate;
    if (start == null) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final previews = <String>[];
    for (var i = 0; i < 3; i++) {
      final d = nextSendAfter(start, draft.frequencyId, i);
      if (d == null) break;
      previews.add('${_shortMonth(d.month)} ${d.day}');
    }
    if (previews.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.sm),
      child: Text(
        '${context.tr('next')}: ${previews.join(', ')}',
        style: TextStyle(color: tokens.ink3, fontSize: 12),
      ),
    );
  }

  String _shortMonth(int m) {
    const names = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[(m - 1).clamp(0, 11)];
  }
}

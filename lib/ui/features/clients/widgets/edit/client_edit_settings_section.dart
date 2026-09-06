import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/industry.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/models/value/size.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/labeled_switch_group.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_field_pair.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// Per-client "Settings" card on the edit screen — the cascade overrides
/// (currency / language / payment terms / task rate) plus classification,
/// company size, industry, e-invoice routing, and the tax flags. Mirrors the
/// React edit "Additional Info → Settings / Classify" sub-tabs.
///
/// Currency / language / payment_terms live in the `settings` cascade (see
/// `Client.toApiJson`): clearing a picker removes the override so the client
/// inherits the company/group value. The pickers are type-to-search because
/// the currency / language lists run past ~20 entries (Forms rule).
class ClientEditSettingsSection extends StatelessWidget {
  const ClientEditSettingsSection({super.key, required this.vm});

  final ClientEditViewModel vm;

  /// Server `classification` enum (React parity). Labels resolve via `tr`.
  static const List<String> _classifications = [
    'individual',
    'business',
    'company',
    'partnership',
    'trust',
    'charity',
    'government',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    final statics = context.read<Services>().statics;

    List<T> sorted<T>(Iterable<T> items, String Function(T) name) =>
        items.toList()..sort(
          (a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()),
        );

    final currencies = sorted<Currency>(
      statics.currencies.values,
      (c) => c.name,
    );
    final languages = sorted<Language>(statics.languages.values, (l) => l.name);
    final industries = sorted<Industry>(
      statics.industries.values,
      (i) => i.name,
    );
    final sizes = sorted<Size>(statics.sizes.values, (s) => s.name);

    // `default_task_rate` is stored as a num (see `setDefaultTaskRate`); show a
    // whole number without a trailing `.0`, and tolerate a legacy string value.
    final taskRateRaw = draft.settings?['default_task_rate'];
    final taskRate = taskRateRaw == null
        ? ''
        : (taskRateRaw is num && taskRateRaw % 1 == 0
              ? taskRateRaw.toInt().toString()
              : taskRateRaw.toString());

    return DashboardCardShell(
      title: context.tr('settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Group + assigned user — org/ownership fields (repo-backed, so
          // each is a StreamBuilder-fed searchable picker). Clearing either
          // sets the id back to '' (none / unassigned).
          ClientEditFieldPair(
            left: _GroupPicker(vm: vm),
            right: _AssignedUserPicker(vm: vm),
          ),
          ClientEditFieldPair(
            left: SearchableDropdownField<Currency>(
              label: context.tr('currency'),
              items: currencies,
              initialValue: statics.currency(draft.currencyId),
              displayString: (c) => c.name,
              idOf: (c) => c.id,
              onChanged: (c) => vm.setCurrencyId(c?.id ?? ''),
            ),
            right: SearchableDropdownField<Language>(
              label: context.tr('language'),
              items: languages,
              initialValue: statics.language(draft.languageId),
              displayString: (l) => l.name,
              idOf: (l) => l.id,
              onChanged: (l) => vm.setLanguageId(l?.id ?? ''),
            ),
          ),
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('payment_terms'),
              initial: draft.paymentTerms,
              keyboardType: TextInputType.number,
              onChanged: vm.setPaymentTerms,
            ),
            right: EntityEditField(
              label: context.tr('task_rate'),
              initial: taskRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: vm.setDefaultTaskRate,
            ),
          ),
          // Quote "valid until" (days) + send-reminders override — both cascade
          // settings stored in `settings`; blank / "Default" inherits.
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('valid_until'),
              initial: vm.validUntil,
              keyboardType: TextInputType.number,
              onChanged: vm.setValidUntil,
            ),
            right: _SendRemindersPicker(vm: vm),
          ),
          ClientEditFieldPair(
            left: SearchableDropdownField<Industry>(
              label: context.tr('industry'),
              items: industries,
              initialValue: statics.industry(draft.industryId),
              displayString: (i) => i.name,
              idOf: (i) => i.id,
              onChanged: (i) => vm.setIndustryId(i?.id ?? ''),
            ),
            right: SearchableDropdownField<Size>(
              label: context.tr('size_id'),
              items: sizes,
              initialValue: statics.size(draft.sizeId),
              displayString: (s) => s.name,
              idOf: (s) => s.id,
              onChanged: (s) => vm.setSizeId(s?.id ?? ''),
            ),
          ),
          ClientEditFieldPair(
            left: SearchableDropdownField<String>(
              label: context.tr('classification'),
              items: _classifications,
              initialValue: draft.classification.isEmpty
                  ? null
                  : draft.classification,
              displayString: (v) => context.tr(v),
              idOf: (v) => v,
              onChanged: (v) => vm.setClassification(v ?? ''),
            ),
            right: EntityEditField(
              label: context.tr('routing_id'),
              initial: draft.routingId,
              onChanged: vm.setRoutingId,
              autocorrect: false,
            ),
          ),
          SizedBox(height: InSpacing.sm),
          LabeledSwitchGroup(
            items: [
              LabeledSwitchItem(
                label: context.tr('tax_exempt'),
                value: draft.isTaxExempt,
                onChanged: vm.setIsTaxExempt,
              ),
              LabeledSwitchItem(
                label: context.tr('valid_vat_number'),
                value: draft.hasValidVatNumber,
                onChanged: vm.setHasValidVatNumber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Group (`group_settings_id`) picker — repo-backed (bundled group settings),
/// so it streams the list and resolves the current selection by id. Clearing
/// sets the override back to none.
class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.vm});
  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<List<GroupSetting>>(
      stream: services.groupSettings.watchAll(companyId: vm.companyId),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <GroupSetting>[];
        GroupSetting? selected;
        for (final g in groups) {
          if (g.id == vm.draft.groupSettingsId) {
            selected = g;
            break;
          }
        }
        return SearchableDropdownField<GroupSetting>(
          label: context.tr('group'),
          items: groups,
          initialValue: selected,
          displayString: (g) => g.name.isEmpty ? g.id : g.name,
          idOf: (g) => g.id,
          onChanged: (g) => vm.setGroupSettingsId(g?.id ?? ''),
        );
      },
    );
  }
}

/// Assigned-user picker — mirrors the project edit screen's picker. Streams
/// the company's users and resolves the current `assigned_user_id`.
class _AssignedUserPicker extends StatelessWidget {
  const _AssignedUserPicker({required this.vm});
  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<List<User>>(
      stream: services.user.watchAllForPicker(companyId: vm.companyId),
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <User>[];
        User? selected;
        for (final u in users) {
          if (u.id == vm.draft.assignedUserId) {
            selected = u;
            break;
          }
        }
        return SearchableDropdownField<User>(
          label: context.tr('assigned_user'),
          items: users,
          initialValue: selected,
          displayString: (u) => u.displayName,
          idOf: (u) => u.id,
          onChanged: (u) => vm.setAssignedUserId(u?.id ?? ''),
        );
      },
    );
  }
}

/// Tri-state send-reminders cascade override: Default (inherit company) /
/// Enabled / Disabled. The `__default__` sentinel item maps to a cleared
/// override (no per-client `send_reminders` key).
class _SendRemindersPicker extends StatelessWidget {
  const _SendRemindersPicker({required this.vm});
  final ClientEditViewModel vm;

  static const String _inheritKey = '__default__';

  @override
  Widget build(BuildContext context) {
    final reminders = vm.sendReminders;
    final current = reminders == null
        ? _inheritKey
        : (reminders ? 'enabled' : 'disabled');
    return SearchableDropdownField<String>(
      label: context.tr('send_reminders'),
      items: const [_inheritKey, 'enabled', 'disabled'],
      initialValue: current,
      displayString: (v) =>
          v == _inheritKey ? context.tr('default') : context.tr(v),
      idOf: (v) => v,
      onChanged: (v) {
        switch (v) {
          case 'enabled':
            vm.setSendReminders(true);
          case 'disabled':
            vm.setSendReminders(false);
          default:
            vm.setSendReminders(null); // Default / cleared → inherit.
        }
      },
    );
  }
}

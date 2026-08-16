import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/payment_links/view_models/payment_link_edit_view_model.dart';
import 'package:admin/ui/features/payment_links/widgets/edit/multi_product_picker.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// First tab of the Payment Link edit screen — identity + grouping +
/// the four product categories. Same FormSection-card layout as every
/// other settings edit so the tab body slots cleanly under the shared
/// [TabBarView] without bespoke chrome.
class PaymentLinkOverviewTab extends StatelessWidget {
  const PaymentLinkOverviewTab({super.key, required this.vm});

  final PaymentLinkEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('overview'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.name,
              labelKey: 'name',
              onChanged: vm.setName,
              errorText: vm.fieldErrorFor('name'),
              externalSyncKey: vm.original?.id,
            ),
            _GroupPicker(vm: vm, services: services),
            _AssignedUserPicker(vm: vm, services: services),
            // Purchase Page is server-computed — read-only and only
            // meaningful on edit. Hide on Create.
            if (!vm.isCreate) _PurchasePageReadOnly(url: vm.draft.purchasePage),
          ],
        ),
        FormSection(
          title: context.tr('products'),
          children: [
            _ProductSection(
              vm: vm,
              services: services,
              labelKey: 'products',
              recurring: false,
              ids: vm.draft.productIds,
              onChanged: vm.setProductIds,
            ),
            _ProductSection(
              vm: vm,
              services: services,
              labelKey: 'recurring_products',
              recurring: true,
              ids: vm.draft.recurringProductIds,
              onChanged: vm.setRecurringProductIds,
            ),
            _ProductSection(
              vm: vm,
              services: services,
              labelKey: 'optional_products',
              recurring: false,
              ids: vm.draft.optionalProductIds,
              onChanged: vm.setOptionalProductIds,
            ),
            _ProductSection(
              vm: vm,
              services: services,
              labelKey: 'optional_recurring_products',
              recurring: true,
              ids: vm.draft.optionalRecurringProductIds,
              onChanged: vm.setOptionalRecurringProductIds,
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.vm, required this.services});
  final PaymentLinkEditViewModel vm;
  final Services services;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupSetting>>(
      stream: services.groupSettings.watchAll(companyId: vm.companyId),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <GroupSetting>[];
        final active =
            all
                .where((g) => g.archivedAt == null && !g.isDeleted)
                .toList(growable: false)
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        final selected = vm.draft.groupId.isEmpty
            ? null
            : active
                  .where((g) => g.id == vm.draft.groupId)
                  .cast<GroupSetting?>()
                  .firstWhere((_) => true, orElse: () => null);
        return SearchableDropdownField<GroupSetting>(
          label: context.tr('group'),
          items: active,
          initialValue: selected,
          displayString: (g) => g.name,
          idOf: (g) => g.id,
          onChanged: (g) => vm.setGroupId(g?.id ?? ''),
          errorText: vm.fieldErrorFor('group_id'),
        );
      },
    );
  }
}

/// Assigned-user picker. Present in both React and admin-portal but was
/// missing here even though the VM already exposes `setAssignedUserId`.
/// Mirrors `project_edit_details_section.dart`'s `_AssignedUserPicker`.
class _AssignedUserPicker extends StatelessWidget {
  const _AssignedUserPicker({required this.vm, required this.services});
  final PaymentLinkEditViewModel vm;
  final Services services;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<User>>(
      stream: services.user.watchPage(
        companyId: vm.companyId,
        loadedPages: 100,
      ),
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

class _ProductSection extends StatelessWidget {
  const _ProductSection({
    required this.vm,
    required this.services,
    required this.labelKey,
    required this.recurring,
    required this.ids,
    required this.onChanged,
  });

  final PaymentLinkEditViewModel vm;
  final Services services;
  final String labelKey;

  /// Currently unused — products and recurring-products live in the
  /// same catalog on the server. Kept on the API to communicate intent
  /// for a future split (`isRecurring` would filter the dropdown then).
  final bool recurring;

  final String ids;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: services.products.watchPage(
        companyId: vm.companyId,
        loadedPages: 10,
      ),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Product>[];
        final available =
            all
                .where((p) => p.archivedAt == null && !p.isDeleted)
                .toList(growable: false)
              ..sort(
                (a, b) => a.productKey.toLowerCase().compareTo(
                  b.productKey.toLowerCase(),
                ),
              );
        return MultiProductPicker(
          labelKey: labelKey,
          value: ids,
          products: available,
          onChanged: onChanged,
        );
      },
    );
  }
}

/// Read-only display of the server-computed purchase URL. Uses
/// `SelectableText` instead of a `TextField` so we don't allocate a
/// `TextEditingController` on every rebuild (the prior implementation
/// leaked).
class _PurchasePageReadOnly extends StatelessWidget {
  const _PurchasePageReadOnly({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('purchase_page'),
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  url.isEmpty ? '—' : url,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('copy'),
            icon: const Icon(Icons.copy_outlined, size: 18),
            onPressed: url.isEmpty ? null : () => copyToClipboard(context, url),
          ),
        ],
      ),
    );
  }
}

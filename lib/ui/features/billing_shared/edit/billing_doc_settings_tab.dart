import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_edit_field_decoration.dart';

/// The bottom-notes "Settings" tab shared by every billing-doc edit
/// screen. Mirrors the old admin-portal Settings tab: Design / Project
/// / Exchange Rate on the left, User / Vendor / Auto Bill on the
/// right. VM-agnostic — the host passes the current values + setters.
class BillingDocSettingsTab extends StatelessWidget {
  const BillingDocSettingsTab({
    super.key,
    required this.companyId,
    required this.entityType,
    required this.tagIds,
    required this.onTagIdsChanged,
    required this.designId,
    required this.onDesignChanged,
    required this.userId,
    required this.onUserChanged,
    required this.projectId,
    required this.onProjectChanged,
    required this.vendorId,
    required this.onVendorChanged,
    required this.exchangeRate,
    required this.onExchangeRateChanged,
    this.autoBillEnabled,
    this.onAutoBillEnabledChanged,
    this.showVendor = true,
  });

  final String companyId;
  final String entityType;
  final List<String> tagIds;
  final ValueChanged<List<String>> onTagIdsChanged;
  final String designId;
  final ValueChanged<String> onDesignChanged;
  final String userId;
  final ValueChanged<String> onUserChanged;
  final String projectId;
  final ValueChanged<String> onProjectChanged;
  final String vendorId;
  final ValueChanged<String> onVendorChanged;
  final String exchangeRate;
  final ValueChanged<String> onExchangeRateChanged;

  /// Auto Bill applies to invoices + recurring invoices only. Null for
  /// quotes / credits / purchase orders → the toggle is hidden.
  final bool? autoBillEnabled;
  final ValueChanged<bool>? onAutoBillEnabledChanged;

  /// Hidden for purchase orders (their top card is already the vendor
  /// picker — duplicating it here is confusing).
  final bool showVendor;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final tokens = context.inTheme;

    Widget design() => StreamBuilder<List<Design>>(
      stream: services.designs.watchAll(companyId: companyId),
      builder: (context, snap) {
        final designs = snap.data ?? const <Design>[];
        Design? sel;
        for (final d in designs) {
          if (d.id == designId) {
            sel = d;
            break;
          }
        }
        return SearchableDropdownField<Design>(
          label: context.tr('design'),
          items: designs,
          initialValue: sel,
          displayString: (d) => d.name,
          idOf: (d) => d.id,
          onChanged: (d) => onDesignChanged(d?.id ?? ''),
        );
      },
    );

    Widget user() => StreamBuilder<List<User>>(
      stream: services.user.watchPage(companyId: companyId, loadedPages: 100),
      builder: (context, snap) {
        final users = snap.data ?? const <User>[];
        User? sel;
        for (final u in users) {
          if (u.id == userId) {
            sel = u;
            break;
          }
        }
        return SearchableDropdownField<User>(
          label: context.tr('user'),
          items: users,
          initialValue: sel,
          displayString: (u) => u.displayName,
          idOf: (u) => u.id,
          onChanged: (u) => onUserChanged(u?.id ?? ''),
        );
      },
    );

    Widget project() => StreamBuilder<List<Project>>(
      stream: services.projects.watchPage(
        companyId: companyId,
        loadedPages: 100,
      ),
      builder: (context, snap) {
        final projects = snap.data ?? const <Project>[];
        Project? sel;
        for (final p in projects) {
          if (p.id == projectId) {
            sel = p;
            break;
          }
        }
        return SearchableDropdownField<Project>(
          label: context.tr('project'),
          items: projects,
          initialValue: sel,
          displayString: (p) => p.name,
          idOf: (p) => p.id,
          onChanged: (p) => onProjectChanged(p?.id ?? ''),
        );
      },
    );

    Widget vendor() => StreamBuilder<List<Vendor>>(
      stream: services.vendors.watchPage(
        companyId: companyId,
        loadedPages: 100,
      ),
      builder: (context, snap) {
        final vendors = snap.data ?? const <Vendor>[];
        Vendor? sel;
        for (final v in vendors) {
          if (v.id == vendorId) {
            sel = v;
            break;
          }
        }
        return SearchableDropdownField<Vendor>(
          label: context.tr('vendor'),
          items: vendors,
          initialValue: sel,
          displayString: (v) => v.name,
          idOf: (v) => v.id,
          onChanged: (v) => onVendorChanged(v?.id ?? ''),
        );
      },
    );

    // TextFormField (not TextField + a build-created controller): its
    // State retains the controller across the parent's frequent
    // AnimatedBuilder rebuilds, so typing doesn't reset the cursor.
    final exchangeRate = TextFormField(
      initialValue: this.exchangeRate,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: billingFieldDecoration(
        context,
        label: context.tr('exchange_rate'),
      ),
      onChanged: onExchangeRateChanged,
    );

    final autoBill = onAutoBillEnabledChanged == null
        ? null
        : SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.tr('auto_bill_enabled'),
              style: TextStyle(color: tokens.ink, fontSize: 14),
            ),
            value: autoBillEnabled ?? false,
            onChanged: onAutoBillEnabledChanged,
          );

    final gap = SizedBox(height: InSpacing.md(context));
    return Padding(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [design(), gap, project(), gap, exchangeRate],
                ),
              ),
              SizedBox(width: InSpacing.lg(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    user(),
                    if (showVendor) ...[gap, vendor()],
                    if (autoBill != null) ...[gap, autoBill],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: InSpacing.lg(context)),
          EntityTagsField(
            entityType: entityType,
            selectedIds: tagIds,
            onChanged: onTagIdsChanged,
          ),
        ],
      ),
    );
  }
}

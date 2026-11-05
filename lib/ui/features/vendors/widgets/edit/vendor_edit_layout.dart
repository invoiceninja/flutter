import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_edit_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/edit/vendor_edit_address_section.dart';
import 'package:admin/ui/features/vendors/widgets/edit/vendor_edit_contacts_section.dart';
import 'package:admin/ui/features/vendors/widgets/edit/vendor_edit_details_section.dart';
import 'package:admin/ui/features/vendors/widgets/edit/vendor_edit_notes_section.dart';
import 'package:admin/ui/features/vendors/widgets/edit/vendor_edit_settings_section.dart';
import 'package:admin/ui/core/edit/create_form_documents.dart';

/// Lays out the edit-screen cards (Details, Address, Settings, Contacts,
/// Notes) using the same v2 mockup pattern as `ClientEditLayout`:
///
/// - ≥1000 px: two columns. Left (`Expanded`) holds Details + Address +
///   Settings; right (`_sidebarWidth` 360 px) holds Contacts + Notes.
/// - <1000 px: single centered column (≤820 px) with all cards stacked.
class VendorEditLayout extends StatelessWidget {
  const VendorEditLayout({super.key, required this.vm});

  final VendorEditViewModel vm;

  static const double _sidebarWidth = 360;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol =
            constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: twoCol
              ? _wide(context)
              : CenteredFormColumn(child: _narrow(context)),
        );
      },
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VendorEditDetailsSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              VendorEditAddressSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              VendorEditSettingsSection(vm: vm),
            ],
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(
          width: _sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VendorEditContactsSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              VendorEditNotesSection(vm: vm),
              if (vm.offersDocuments) ...[
                SizedBox(height: InSpacing.md(context)),
                CreateFormDocumentsCard(vm: vm),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VendorEditDetailsSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        VendorEditAddressSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        VendorEditSettingsSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        VendorEditContactsSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        VendorEditNotesSection(vm: vm),
        if (vm.offersDocuments) ...[
          SizedBox(height: InSpacing.md(context)),
          CreateFormDocumentsCard(vm: vm),
        ],
      ],
    );
  }
}

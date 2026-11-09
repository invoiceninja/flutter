import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/auth/view_models/setup_wizard_view_model.dart';

/// A step's title and subtitle. The title is the step's heading for a screen
/// reader too, read with where the step sits ("Step 2 of 2: Add your logo"),
/// and takes [focusNode] so a step change can move the reader to it.
class SetupStepHeading extends StatelessWidget {
  const SetupStepHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.stepCount,
    this.focusNode,
  });

  final String title;
  final String subtitle;
  final int step;
  final int stepCount;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          focusNode: focusNode,
          // A display heading scales less than body text (as iOS large titles
          // do): at 2x a 24 px title would be a three-line block.
          child: Semantics(
            header: true,
            headingLevel: 1,
            label: context.tr('setup_step_heading_sr', {
              'current': '$step',
              'total': '$stepCount',
              'title': title,
            }),
            excludeSemantics: true,
            child: Text(
              title,
              textScaler: MediaQuery.textScalerOf(
                context,
              ).clamp(maxScaleFactor: 1.5),
              style: TextStyle(
                fontSize: narrow ? 24 : 28,
                height: narrow ? 30 / 24 : 34 / 28,
                letterSpacing: -0.2,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        Text(
          subtitle,
          style: TextStyle(fontSize: 15, height: 22 / 15, color: tokens.ink2),
        ),
      ],
    );
  }
}

/// Step 1: who the invoices are from, and in what currency and language.
class SetupStepBusiness extends StatelessWidget {
  const SetupStepBusiness({
    super.key,
    required this.vm,
    required this.nameController,
    required this.firstController,
    required this.lastController,
    required this.nameFocus,
    required this.firstFocus,
    required this.headingFocus,
    required this.regionExpanded,
    required this.onToggleRegion,
    required this.currencies,
    required this.languages,
    this.regionPickersKey,
  });

  /// On the pickers, so opening them can scroll them into view.
  final Key? regionPickersKey;

  final SetupWizardViewModel vm;
  final TextEditingController nameController;
  final TextEditingController firstController;
  final TextEditingController lastController;
  final FocusNode nameFocus;
  final FocusNode firstFocus;
  final FocusNode headingFocus;
  final bool regionExpanded;
  final VoidCallback onToggleRegion;
  final List<Currency> currencies;
  final List<Language> languages;

  @override
  Widget build(BuildContext context) {
    final motion = InMotion.of(context);
    final gap = SizedBox(height: InSpacing.md(context));
    final suggestion = vm.suggestedBusinessName;
    final showSuggestion =
        suggestion.isNotEmpty && vm.businessName.trim() != suggestion;
    final currency = currencies.where((c) => c.id == vm.currencyId).firstOrNull;
    final language = languages.where((l) => l.id == vm.languageId).firstOrNull;
    final regionKnown = currency != null && language != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupStepHeading(
          title: context.tr(
            vm.isAdditionalCompany
                ? 'setup_business_title_additional'
                : 'setup_business_title',
          ),
          subtitle: context.tr('setup_business_subtitle'),
          step: vm.stepNumber,
          stepCount: vm.stepCount,
          focusNode: headingFocus,
        ),
        const SizedBox(height: InSpacing.xl),
        if (vm.askUserName) ...[
          SetupUserNameFields(
            first: firstController,
            last: lastController,
            firstFocus: firstFocus,
            nameFocus: nameFocus,
            onChanged: (first, last) =>
                vm.setUserName(first: first, last: last),
          ),
          gap,
        ],
        TextField(
          key: const ValueKey('setup_company_name'),
          controller: nameController,
          focusNode: nameFocus,
          textCapitalization: TextCapitalization.words,
          // The signed-in user's own company (CLAUDE.md § Forms).
          autofillHints: const [AutofillHints.organizationName],
          textInputAction: TextInputAction.done,
          onChanged: vm.setBusinessName,
          onSubmitted: (_) => FormSaveScope.maybeOf(context)?.trySubmit(),
          decoration: InputDecoration(
            labelText: context.tr('setup_business_name'),
            helperText: context.tr('setup_business_name_helper'),
            helperMaxLines: 2,
            errorText: vm.showNameError
                ? context.tr('setup_business_name_required')
                : null,
          ),
        ),
        AnimatedSize(
          duration: motion(InMotion.fast),
          curve: InMotion.out,
          alignment: AlignmentDirectional.topStart,
          child: showSuggestion
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const ValueKey('setup_use_name'),
                    icon: const Icon(Icons.person_outline, size: 18),
                    label: Text(
                      context.tr('setup_use_name', {'name': suggestion}),
                    ),
                    onPressed: () {
                      nameController.text = suggestion;
                      nameController.selection = TextSelection.collapsed(
                        offset: suggestion.length,
                      );
                      vm.setBusinessName(suggestion);
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: InSpacing.xl),
        _RegionRow(
          label: context.tr('setup_region_label'),
          value: regionKnown
              ? '${currency.name} (${currency.code}) · ${language.name}'
              : null,
          expanded: regionExpanded,
          onToggle: onToggleRegion,
        ),
        AnimatedSize(
          duration: motion(InMotion.base),
          curve: InMotion.move,
          alignment: AlignmentDirectional.topStart,
          child: regionExpanded
              ? Padding(
                  key: regionPickersKey,
                  padding: EdgeInsets.only(top: InSpacing.md(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchableDropdownField<Currency>(
                        key: const ValueKey('setup_currency'),
                        label: context.tr('currency'),
                        items: currencies,
                        initialValue: currency,
                        displayString: (c) => '${c.name} (${c.code})',
                        idOf: (c) => c.id,
                        onChanged: (c) {
                          if (c != null) vm.setCurrency(c.id);
                        },
                      ),
                      gap,
                      SearchableDropdownField<Language>(
                        key: const ValueKey('setup_language'),
                        label: context.tr('setup_invoice_language'),
                        items: languages,
                        initialValue: language,
                        displayString: (l) => l.name,
                        idOf: (l) => l.id,
                        onChanged: (l) {
                          if (l != null) vm.setLanguage(l.id);
                        },
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// "Currency and invoice language" as one line a glance confirms, with
/// Change to open the two pickers. The value wraps under the label and Change
/// keeps its own width, so neither squeezes the other at a large text size.
class _RegionRow extends StatelessWidget {
  const _RegionRow({
    required this.label,
    required this.value,
    required this.expanded,
    required this.onToggle,
  });

  final String label;

  /// Null while the currencies and languages are still loading.
  final String? value;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // The whole card is the target, not just Change: on a phone the card is
    // what a thumb lands on. A local Material, never `Ink`
    // (docs/sidebar-and-shell.md).
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        excludeFromSemantics: true,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: InSpacing.lg(context),
            end: 4,
            top: 10,
            bottom: 10,
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: InSpacing.sm,
            runSpacing: 4,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 180),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, color: tokens.ink3),
                    ),
                    const SizedBox(height: 2),
                    if (value != null)
                      Text(
                        value!,
                        key: const ValueKey('setup_region_value'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: tokens.ink,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Container(
                          width: 120,
                          height: 12,
                          decoration: BoxDecoration(
                            color: tokens.surfaceAlt,
                            borderRadius: BorderRadius.circular(InRadii.r1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                key: const ValueKey('setup_region_change'),
                onPressed: onToggle,
                child: Text(
                  context.tr(expanded ? 'setup_region_done' : 'setup_change'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First and last name, side by side. Next moves to the last name, then on
/// to the business name.
class SetupUserNameFields extends StatelessWidget {
  const SetupUserNameFields({
    super.key,
    required this.first,
    required this.last,
    required this.firstFocus,
    required this.nameFocus,
    required this.onChanged,
  });

  final TextEditingController first;
  final TextEditingController last;
  final FocusNode firstFocus;
  final FocusNode nameFocus;
  final void Function(String? first, String? last) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('setup_first_name'),
            controller: first,
            focusNode: firstFocus,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            textInputAction: TextInputAction.next,
            onChanged: (v) => onChanged(v, null),
            decoration: InputDecoration(labelText: context.tr('first_name')),
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: TextField(
            key: const ValueKey('setup_last_name'),
            controller: last,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            textInputAction: TextInputAction.next,
            onChanged: (v) => onChanged(null, v),
            onSubmitted: (_) => nameFocus.requestFocus(),
            decoration: InputDecoration(labelText: context.tr('last_name')),
          ),
        ),
      ],
    );
  }
}

/// Step 2: the logo. On a phone the preview above is the hero and its logo
/// slot the target, with Photos and Files as two plain buttons (a logo
/// usually lives in Photos, which the file picker cannot reach on iOS); on a
/// desktop or the web it is the drop zone.
class SetupStepLogo extends StatelessWidget {
  const SetupStepLogo({
    super.key,
    required this.vm,
    required this.headingFocus,
    required this.touchLayout,
    required this.onFiles,
    required this.onPickPhoto,
    required this.onPickFile,
    required this.busy,
    this.error,
    this.preview,
  });

  final SetupWizardViewModel vm;
  final FocusNode headingFocus;
  final bool touchLayout;
  final Future<void> Function(List<UploadSource> sources) onFiles;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final bool busy;
  final String? error;

  /// The phone layout's hero, drawn between the heading and the buttons.
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    final logo = vm.logo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupStepHeading(
          title: context.tr('setup_logo_title'),
          subtitle: context.tr('setup_logo_subtitle'),
          step: vm.stepNumber,
          stepCount: vm.stepCount,
          focusNode: headingFocus,
        ),
        const SizedBox(height: InSpacing.xl),
        // A narrow window has no preview pane, so the preview leads the step.
        if (preview != null) ...[
          Center(child: preview),
          const SizedBox(height: InSpacing.xl),
        ],
        if (touchLayout) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final photo = FilledButton.icon(
                key: const ValueKey('setup_choose_photo'),
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: busy ? null : onPickPhoto,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(context.tr('setup_choose_photo')),
              );
              final scale = MediaQuery.textScalerOf(context).scale(1);
              // A phone: one full-width Photos button (where a logo usually
              // is) and Files as a quiet link under it — side by side they
              // wrapped on a 360 px phone and broke words at a large text
              // size. A tablet has room for the pair.
              if (constraints.maxWidth / scale < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    photo,
                    const SizedBox(height: InSpacing.xs),
                    Center(
                      child: TextButton(
                        key: const ValueKey('setup_choose_file'),
                        onPressed: busy ? null : onPickFile,
                        child: Text(context.tr('setup_choose_file_instead')),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: photo),
                  SizedBox(width: InSpacing.md(context)),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('setup_choose_file'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 44),
                      ),
                      onPressed: busy ? null : onPickFile,
                      icon: const Icon(Icons.folder_outlined, size: 18),
                      label: Text(context.tr('setup_choose_file')),
                    ),
                  ),
                ],
              );
            },
          ),
        ] else
          FileDropZone(
            key: const ValueKey('setup_logo_drop'),
            allowedExtensions: kSetupLogoExtensions,
            idleLabelKey: 'setup_drop_logo',
            enabled: !busy,
            preview: logo == null
                ? null
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 96),
                    child: Image.memory(logo, fit: BoxFit.contain),
                  ),
            onFiles: onFiles,
          ),
        const SizedBox(height: InSpacing.sm),
        AnimatedSwitcher(
          duration: motion(InMotion.fast),
          child: error != null
              ? Text(
                  error!,
                  key: ValueKey(error),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.error,
                  ),
                )
              : Text(
                  context.tr('setup_logo_hint'),
                  key: const ValueKey('hint'),
                  style: TextStyle(fontSize: 13, color: tokens.ink3),
                ),
        ),
        if (logo != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('setup_remove_logo'),
              onPressed: busy ? null : () => vm.setLogo(null),
              icon: const Icon(Icons.close, size: 18),
              label: Text(context.tr('remove')),
            ),
          ),
      ],
    );
  }
}

/// What a logo may be — the server renders these.
const List<String> kSetupLogoExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp'];

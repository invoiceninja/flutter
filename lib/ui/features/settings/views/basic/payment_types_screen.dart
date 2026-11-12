import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/domain/payment_types.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/view_models/payment_types_settings_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_company_scoped_host.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';

/// Searchable label keys rendered by this screen, aggregated into
/// `kSettingsSearchCatalog['payment_types']`. `search_catalog_consistency_test`
/// checks each appears as a `context.tr('…')` in this file.
const kPaymentTypesSearchKeys = <String>[
  'payment_types',
  'rename_payment_type',
  'hide_all',
  'show_all',
];

/// Settings → Payment Types (invoiceninja/flutter#191, docs/payment-types.md).
///
/// The server's payment types are a fixed list a company can't add to. This
/// page lets the company hide the ones it never uses from the Type pickers
/// (`settings.hidden_payment_types`) and rename one
/// (`settings.translations['payment_type_<English>']`, which the server also
/// prints on PDFs, the portal and emails). Company scope only
/// (`clientEditable: false` in the catalog). The payment and expense Type
/// pickers open the same body in a dialog ([showPaymentTypesDialog]).
class PaymentTypesScreen extends StatelessWidget {
  const PaymentTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return SettingsCompanyScopedHost<PaymentTypesSettingsViewModel>(
      create: (companyId) {
        final vm = PaymentTypesSettingsViewModel(
          repo: services.company,
          companyId: companyId,
        );
        unawaited(vm.load());
        return vm;
      },
      builder: (context, vm) =>
          SettingsPageScaffold<PaymentTypesSettingsViewModel>(
            titleKey: 'payment_types',
            viewModel: vm,
            body: SettingsFormShell(
              sections: [
                FormSection(
                  title: context.tr('payment_types'),
                  children: [PaymentTypesEditor(vm: vm)],
                ),
              ],
            ),
          ),
    );
  }
}

/// The Payment Types page body as a dialog over a form — the Type pickers'
/// "Manage payment types" footer. A dialog, not a route, so the payment or
/// expense being entered survives the trip. Saves on its own Save.
Future<void> showPaymentTypesDialog(
  BuildContext context, {
  required String companyId,
}) => showDialog<void>(
  context: context,
  builder: (_) => _PaymentTypesDialog(companyId: companyId),
);

class _PaymentTypesDialog extends StatefulWidget {
  const _PaymentTypesDialog({required this.companyId});

  final String companyId;

  @override
  State<_PaymentTypesDialog> createState() => _PaymentTypesDialogState();
}

class _PaymentTypesDialogState extends State<_PaymentTypesDialog> {
  late final PaymentTypesSettingsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = PaymentTypesSettingsViewModel(
      repo: context.read<Services>().company,
      companyId: widget.companyId,
    );
    unawaited(_vm.load());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = context.tr('saved_settings');
    final failed = context.tr('error_refresh_page');
    final result = await _vm.save();
    if (!mounted) return;
    if (result == null) {
      Notify.error(context, failed, detail: _vm.submitError);
      return;
    }
    Notify.success(context, saved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => AlertDialog(
        title: Semantics(
          header: true,
          headingLevel: 1,
          child: Text(context.tr('payment_types')),
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(child: PaymentTypesEditor(vm: _vm)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('save'),
            autofocus: false,
            showEnterHint: false,
            busy: _vm.isSaving,
            onPressed: _vm.isDirty && !_vm.isSaving ? _save : null,
          ),
        ],
      ),
    );
  }
}

enum _Filter { all, shown, hidden }

/// The list of payment types with a search, an All / Shown / Hidden filter,
/// Hide all / Show all, and per type a Shown switch and a rename.
///
/// Names come from the DRAFT's `translations`, never the rendered label:
/// `Localization` withholds Custom Labels while the app's language differs
/// from the company's, and this is where they are edited.
class PaymentTypesEditor extends StatefulWidget {
  const PaymentTypesEditor({super.key, required this.vm});

  final PaymentTypesSettingsViewModel vm;

  @override
  State<PaymentTypesEditor> createState() => _PaymentTypesEditorState();
}

class _PaymentTypesEditorState extends State<PaymentTypesEditor> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  void _onSearch() => setState(() {});

  PaymentTypesSettingsViewModel get vm => widget.vm;

  Map<String, dynamic> get _translations =>
      vm.settings.translations ?? const <String, dynamic>{};

  Set<String> get _hidden =>
      parseHiddenPaymentTypes(vm.settings.hiddenPaymentTypes);

  /// The company's own name for [type], or '' when it has none.
  String _customName(PaymentType type) {
    final key = kPaymentTypeLabelKeys[type.id];
    if (key == null) return '';
    return (_translations[key] ?? '').toString().trim();
  }

  String _shownName(PaymentType type) {
    final custom = _customName(type);
    return custom.isEmpty ? type.name : custom;
  }

  void _setHidden(Set<String> hidden) => vm.updateSettings(
    (s) => s.copyWith(hiddenPaymentTypes: encodeHiddenPaymentTypes(hidden)),
  );

  void _setShown(PaymentType type, bool shown) {
    final hidden = _hidden;
    shown ? hidden.remove(type.id) : hidden.add(type.id);
    _setHidden(hidden);
  }

  Future<void> _rename(PaymentType type, List<PaymentType> all) async {
    final key = kPaymentTypeLabelKeys[type.id];
    if (key == null) return;
    final takenNames = {
      for (final t in all)
        if (t.id != type.id) _shownName(t).toLowerCase(),
    };
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(
        stockName: type.name,
        currentName: _customName(type),
        takenNames: takenNames,
      ),
    );
    if (result == null || !mounted) return;
    vm.updateSettings((s) {
      final next = Map<String, dynamic>.of(
        s.translations ?? const <String, dynamic>{},
      );
      // '' is Reset: drop the key rather than store a blank override.
      if (result.isEmpty || result == type.name) {
        next.remove(key);
      } else {
        next[key] = result;
      }
      return s.copyWith(translations: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.draft == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final tokens = context.inTheme;
        final statics = context.read<Services>().statics;
        final hidden = _hidden;
        final defaultId = vm.settings.paymentTypeId ?? '';
        final all = statics.paymentTypes.values.toList()
          ..sort(
            (a, b) => _shownName(
              a,
            ).toLowerCase().compareTo(_shownName(b).toLowerCase()),
          );
        final words = _search.text.trim().toLowerCase();
        final rows = [
          for (final t in all)
            if ((_filter == _Filter.all ||
                    (_filter == _Filter.hidden) == hidden.contains(t.id)) &&
                (words.isEmpty ||
                    '${_shownName(t)} ${t.name}'.toLowerCase().contains(words)))
              t,
        ];
        final shownCount = all.where((t) => !hidden.contains(t.id)).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('payment_types_help'),
              style: TextStyle(color: tokens.ink2),
            ),
            const SizedBox(height: InSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: context.tr('search_payment_types'),
                    ),
                  ),
                ),
                const SizedBox(width: InSpacing.sm),
                BackDismissibleMenuAnchor(
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.visibility_off_outlined),
                      onPressed: () => _setHidden({for (final t in all) t.id}),
                      child: Text(context.tr('hide_all')),
                    ),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.visibility_outlined),
                      onPressed: () => _setHidden(const {}),
                      child: Text(context.tr('show_all')),
                    ),
                  ],
                  builder: (context, controller, _) => IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: context.tr('actions'),
                    onPressed: () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: InSpacing.sm),
            Wrap(
              spacing: InSpacing.sm,
              runSpacing: InSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<_Filter>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _Filter.all,
                      label: Text(context.tr('all')),
                    ),
                    ButtonSegment(
                      value: _Filter.shown,
                      label: Text(context.tr('shown')),
                    ),
                    ButtonSegment(
                      value: _Filter.hidden,
                      label: Text(context.tr('hidden')),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
                Text(
                  context.tr('payment_types_shown_count', {
                    'count': '$shownCount',
                    'total': '${all.length}',
                  }),
                  style: TextStyle(color: tokens.ink3),
                ),
              ],
            ),
            const SizedBox(height: InSpacing.sm),
            for (final t in rows)
              _PaymentTypeRow(
                name: _shownName(t),
                stockName: t.name,
                renamed: _customName(t).isNotEmpty,
                isDefault: t.id == defaultId,
                shown: !hidden.contains(t.id),
                onRename: kPaymentTypeLabelKeys.containsKey(t.id)
                    ? () => _rename(t, all)
                    : null,
                onShownChanged: (v) => _setShown(t, v),
              ),
          ],
        );
      },
    );
  }
}

class _PaymentTypeRow extends StatelessWidget {
  const _PaymentTypeRow({
    required this.name,
    required this.stockName,
    required this.renamed,
    required this.isDefault,
    required this.shown,
    required this.onRename,
    required this.onShownChanged,
  });

  final String name;
  final String stockName;
  final bool renamed;
  final bool isDefault;
  final bool shown;

  /// Null for a type that can't be renamed (FPX, Stripe Bank Transfer).
  final VoidCallback? onRename;
  final ValueChanged<bool> onShownChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final notes = [
      if (renamed) context.tr('renamed_from', {'name': stockName}),
      if (isDefault && !shown) context.tr('payment_type_hidden_default'),
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onRename,
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              style: shown ? null : TextStyle(color: tokens.ink3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDefault) ...[
            const SizedBox(width: InSpacing.sm),
            Text(
              context.tr('default'),
              style: TextStyle(color: tokens.accent, fontSize: 12),
            ),
          ],
        ],
      ),
      subtitle: notes.isEmpty
          ? null
          : Text(notes.join(' · '), style: TextStyle(color: tokens.ink3)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onRename != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: context.tr('rename_payment_type'),
              onPressed: onRename,
            ),
          Semantics(
            label: context.tr('shown'),
            child: Switch(value: shown, onChanged: onShownChanged),
          ),
        ],
      ),
    );
  }
}

/// One-field rename. Pops the new name, `''` for Reset, or null on Cancel.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({
    required this.stockName,
    required this.currentName,
    required this.takenNames,
  });

  final String stockName;
  final String currentName;

  /// Every other type's current name, lower-cased — a match is allowed, but
  /// warned about: two identical names in a picker can't be told apart.
  final Set<String> takenNames;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.currentName);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String get _name => _controller.text.trim();

  void _submit() => Navigator.of(context).pop(_name);

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final clash = widget.takenNames.contains(_name.toLowerCase());
    return AlertDialog(
      title: Semantics(
        header: true,
        headingLevel: 1,
        child: Text(context.tr('rename_payment_type')),
      ),
      content: FormSaveScope(
        onSubmit: _submit,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.tr('name'),
                hintText: widget.stockName,
                helperText: clash
                    ? context.tr('payment_type_name_in_use')
                    : null,
                helperMaxLines: 2,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: InSpacing.sm),
            Text(
              context.tr('payment_type_rename_help'),
              style: TextStyle(color: tokens.ink3, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.currentName.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(
              context.tr('reset_to_name', {'name': widget.stockName}),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('save'),
          autofocus: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}

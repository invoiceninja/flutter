import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_country_field.dart';
import 'package:admin/ui/features/settings/widgets/plain_radio_field.dart';

/// Quick "New Client" form, opened from a billing document's client picker so
/// the user never has to abandon a half-written invoice to add a client.
///
/// Mirrors React's `pages/invoices/common/components/ClientCreate.tsx`: the
/// same four tabs and the same field set — deliberately narrower than the full
/// client edit screen (no number, website, tags, custom fields, industry/size,
/// tax flags or notes).
///
/// Creates through the normal offline-first pipeline and returns the created
/// client — carrying a `tmp_` id when it hasn't synced yet — so the caller can
/// select it on the document immediately. Null when cancelled.
Future<Client?> showClientCreateDialog(
  BuildContext context, {
  required String companyId,
  String initialName = '',
}) {
  return showDialog<Client>(
    context: context,
    // Twenty-odd fields of typed input — a stray barrier tap must not bin it.
    barrierDismissible: false,
    builder: (_) =>
        _ClientCreateDialog(companyId: companyId, initialName: initialName),
  );
}

class _ClientCreateDialog extends StatefulWidget {
  const _ClientCreateDialog({
    required this.companyId,
    required this.initialName,
  });

  final String companyId;
  final String initialName;

  @override
  State<_ClientCreateDialog> createState() => _ClientCreateDialogState();
}

class _ClientCreateDialogState extends State<_ClientCreateDialog>
    with SingleTickerProviderStateMixin {
  /// Explicit controller (not `DefaultTabController`) so a failed save can
  /// jump to whichever tab owns the first error.
  late final TabController _tab = TabController(length: 4, vsync: this);

  late final Services _services;
  late final ClientEditViewModel _vm;
  late final Client _seed;
  bool _wired = false;

  /// Latched once the dialog has committed to popping, so the frame between
  /// `save()` clearing `isSaving` and the actual pop can't take a second
  /// submit (which would create a second client).
  bool _closing = false;

  // Sorted once: the VM notifies per keystroke, and re-sorting ~250 countries
  // and currencies on every character is pure waste.
  late final List<Currency> _currencies;
  late final List<Language> _languages;

  // Built once for the same reason. A `watchAll(...)` call inside `build`
  // returns a NEW stream object each time, so `StreamBuilder` would cancel and
  // re-subscribe (re-querying Drift) on every keystroke.
  late final Stream<List<GroupSetting>> _groups;

  /// Which api error keys live on which tab, so a 422 can surface its field.
  static const List<List<String>> _tabErrorKeys = [
    [
      'name',
      'vat_number',
      'contacts.0.first_name',
      'contacts.0.last_name',
      'contacts.0.email',
      'contacts.0.phone',
      'settings.currency_id',
    ],
    ['address1', 'address2', 'city', 'state', 'postal_code', 'country_id'],
    [
      'shipping_address1',
      'shipping_address2',
      'shipping_city',
      'shipping_state',
      'shipping_postal_code',
      'shipping_country_id',
    ],
    [
      'settings.language_id',
      'settings.payment_terms',
      'settings.valid_until',
      'settings.default_task_rate',
      'settings.send_reminders',
      'group_settings_id',
    ],
  ];

  // Built here rather than in `initState` because the name guard's message is
  // resolved through `Localizations`, an inherited lookup.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    _services = context.read<Services>();
    final name = widget.initialName.trim();
    _seed = name.isEmpty
        ? emptyClient()
        : emptyClient().copyWith(name: name, displayName: name);
    _vm = ClientEditViewModel(
      repo: _services.clients,
      companyId: widget.companyId,
      // `cloneFrom` is "start from this draft, still a create" — the same slot
      // the full screen uses for a staged/group-prefilled draft.
      cloneFrom: _seed,
      // React's inline-create guard: name OR a contact name. Only the quick
      // dialog opts in; the full client screen keeps the server's laxer rule.
      nameOrContactRequiredMessage: context.tr(
        'please_enter_a_client_or_contact_name',
      ),
      useCommaAsDecimalPlace:
          _services
              .formatterIfReady(widget.companyId)
              ?.settings
              .useCommaAsDecimalPlace ??
          false,
      sync: _services.sync,
      connectivity: _services.connectivity,
      // Shorter than the 30 s default: this modal is blocking another form.
      onlineSaveTimeout: const Duration(seconds: 8),
    );
    final statics = _services.statics;
    _currencies = statics.currencies.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    _languages = statics.languages.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _groups = _services.groupSettings.watchAll(companyId: widget.companyId);
  }

  @override
  void dispose() {
    _tab.dispose();
    _vm.dispose();
    super.dispose();
  }

  bool get _dirty => _vm.draft != _seed;

  Future<void> _handleClose() async {
    // Also guards the system-back path, which reaches here through PopScope
    // without passing the buttons' own `isSaving` checks — popping mid-save
    // would "cancel" a client that has already been written locally.
    if (_vm.isSaving || _closing) return;
    if (_dirty && !await showDiscardChangesDialog(context)) return;
    if (!mounted) return;
    _closing = true;
    // A previous attempt that failed (422 or 5xx) left a local `tmp_` client
    // plus its outbox row. The user is abandoning the form, so bin both —
    // otherwise a client they thought they discarded appears in the picker
    // and eventually syncs.
    await _discardFailedAttempt();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _jumpToFirstErrorTab() {
    for (var i = 0; i < _tabErrorKeys.length; i++) {
      if (_tabErrorKeys[i].any((k) => _vm.fieldErrorFor(k) != null)) {
        if (_tab.index != i) _tab.animateTo(i);
        return;
      }
    }
  }

  Future<void> _save() async {
    // `_closing` covers the window between `save()` returning and the pop:
    // `isSaving` is already false by then, so a second Enter would otherwise
    // start a fresh create (with `recoveryTempId` cleared) and write a
    // SECOND client.
    if (_vm.isSaving || _closing) return;
    // `save()` runs the VM's `validate()` first: the name-or-contact-name
    // guard populates `fieldErrors` and returns null without ever writing an
    // outbox row, so the errors below cover both it and a server 422.
    final saved = await _vm.save();
    if (!mounted) return;

    if (saved == null) {
      // A 422 carrying per-field errors leaves `submitError` null by design
      // (`GenericEditViewModel`) — those errors render inline instead. Only a
      // submit-level failure (5xx, network) needs the toast.
      if (_vm.submitError != null) {
        Notify.error(
          context,
          context.tr('could_not_save'),
          detail: _vm.submitError,
        );
      }
      // Deliberately do NOT discard the failed attempt here. `recoveryTempId`
      // makes the next Save reuse the same tmp id, so fixing the flagged field
      // and re-saving repairs the record in place — the framework's intended
      // recovery path (`entity_edit_screen_scaffold`). Discarding would also
      // run `clearFailedSync()`, which wipes `fieldErrors`, leaving the user
      // staring at a form that reports nothing at all. The ghost is cleaned up
      // on a successful re-save (below) or on cancel (`_handleClose`).
      _jumpToFirstErrorTab();
      return;
    }

    _closing = true;
    // This save superseded any earlier 422, whose dead row now holds a stale
    // payload. Mirrors `_cleanupPriorDeadRow` on the full edit scaffold.
    await _deletePriorDeadRow();
    if (!mounted) return;

    // The create may have drained inside the await window, in which case Drift
    // now holds the real row and the tmp id is gone. `watch` resolves tmp →
    // real through `id_remap`; returning the stale local draft would hand the
    // document a dead id. Time-boxed so a stream that never emits can't strand
    // the dialog open over an already-created client.
    final fresh = await _services.clients
        .watch(companyId: widget.companyId, id: saved.id)
        .first
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    if (!mounted) return;
    Notify.success(
      context,
      context.tr(
        _vm.lastSaveWasOptimistic ? 'saving_in_background' : 'created_client',
      ),
    );
    Navigator.of(context).pop(fresh ?? saved);
  }

  /// The dead outbox row for this dialog's failed attempt, if any.
  Future<OutboxRow?> _failedAttemptRow() async {
    final tmpId = _vm.recoveryTempId;
    if (tmpId == null) return null;
    return _services.db.outboxDao.findDeadForEntity(
      companyId: widget.companyId,
      entityType: 'client',
      entityId: tmpId,
    );
  }

  /// Drop a superseded 422's row after a successful re-save. Deletes the row
  /// only — unlike [_discardFailedAttempt] the local client record is the one
  /// we just saved and must survive.
  Future<void> _deletePriorDeadRow() async {
    final row = await _failedAttemptRow();
    if (row == null) return;
    await _services.db.outboxDao.deleteRow(row.id);
    _vm.clearFailedSync();
  }

  /// Bin a failed attempt entirely — outbox row *and* the never-synced local
  /// client `discardOutboxRow` ghost-deletes with it.
  Future<void> _discardFailedAttempt() async {
    final row = await _failedAttemptRow();
    if (row == null) return;
    await _services.sync.discardOutboxRow(row.id);
    _vm.clearFailedSync();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.wide;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _handleClose();
        },
        // `barrierDismissible: false` disables the modal route's own dismiss
        // action, so Escape would otherwise be swallowed entirely and the key
        // would do nothing at all. Route it through the same close path as
        // Cancel (discard prompt included) rather than leaving it inert.
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                _handleClose();
                return null;
              },
            ),
          },
          child: narrow ? _fullscreen(context) : _windowed(context),
        ),
      ),
    );
  }

  /// Phone / narrow window. A four-tab, twenty-field form inside an
  /// `AlertDialog` is ~295 px wide after inset padding — too cramped to use.
  Widget _fullscreen(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('new_client')),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.tr('cancel'),
            onPressed: _vm.isSaving ? null : _handleClose,
          ),
        ),
        body: SafeArea(child: _body(context)),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(InSpacing.lg(context)),
            child: _actions(context),
          ),
        ),
      ),
    );
  }

  Widget _windowed(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('new_client')),
      // Tight, not a loose `ConstrainedBox(maxWidth:)`: `AlertDialog` wraps
      // its column in an `IntrinsicWidth`, and `TabBarView` → `PageView` →
      // `RenderViewport` throws on an intrinsic-dimension query. A tight
      // `SizedBox` short-circuits that, and because `RenderConstrainedBox`
      // enforces down against the parent it also shrinks (rather than
      // overflowing) on a short window.
      content: SizedBox(width: 460, height: 380, child: _body(context)),
      actions: [_actions(context)],
    );
  }

  Widget _body(BuildContext context) {
    return FormSaveScope(
      onSubmit: _save,
      enabled: !_vm.isSaving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: context.tr('details')),
              Tab(text: context.tr('address')),
              Tab(text: context.tr('shipping')),
              Tab(text: context.tr('settings')),
            ],
          ),
          Divider(height: 1, color: context.inTheme.border),
          // Off-screen tabs are disposed by `TabBarView`, which is fine and
          // load-bearing: every keystroke lands in the VM draft immediately,
          // and each field reseeds from `initial:` on return. Never hold field
          // state in the tab widgets.
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _DetailsTab(vm: _vm, currencies: _currencies),
                _AddressTab(vm: _vm),
                _ShippingTab(vm: _vm),
                _SettingsTab(vm: _vm, languages: _languages, groups: _groups),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: _vm.isSaving ? null : _handleClose,
          child: Text(context.tr('cancel')),
        ),
        SizedBox(width: InSpacing.md(context)),
        PrimaryDialogAction(
          label: context.tr('save'),
          enabled: !_vm.isSaving,
          busy: _vm.isSaving,
          // The Name field owns focus; Enter still submits via FormSaveScope.
          autofocus: false,
          // The Details tab holds a currency `SearchableDropdownField`, which
          // swallows Enter to pick an option — so the hint would sometimes lie.
          showEnterHint: false,
          onPressed: _save,
        ),
      ],
    );
  }
}

/// Shared tab chrome: one scrollable column of fields.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: InSpacing.md(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.vm, required this.currencies});

  final ClientEditViewModel vm;
  final List<Currency> currencies;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    final statics = context.read<Services>().statics;
    final contact = draft.contacts.isEmpty ? null : draft.contacts.first;
    return _TabBody(
      children: [
        EntityEditField(
          label: context.tr('name'),
          initial: draft.name,
          autofocus: true,
          onChanged: vm.setName,
          errorText: vm.fieldErrorFor('name'),
        ),
        EntityEditField(
          label: context.tr('vat_number'),
          initial: draft.vatNumber,
          onChanged: vm.setVatNumber,
          errorText: vm.fieldErrorFor('vat_number'),
        ),
        SizedBox(height: InSpacing.md(context)),
        Text(
          context.tr('primary_contact'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
        ),
        EntityEditField(
          label: context.tr('first_name'),
          initial: contact?.firstName ?? '',
          onChanged: (v) => vm.setContactFirstNameAt(0, v),
          errorText: vm.fieldErrorFor('contacts.0.first_name'),
        ),
        EntityEditField(
          label: context.tr('last_name'),
          initial: contact?.lastName ?? '',
          onChanged: (v) => vm.setContactLastNameAt(0, v),
          errorText: vm.fieldErrorFor('contacts.0.last_name'),
        ),
        EntityEditField(
          label: context.tr('email'),
          initial: contact?.email ?? '',
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => vm.setContactEmailAt(0, v),
          errorText: vm.fieldErrorFor('contacts.0.email'),
        ),
        EntityEditField(
          label: context.tr('phone'),
          initial: contact?.phone ?? '',
          keyboardType: TextInputType.phone,
          onChanged: (v) => vm.setContactPhoneAt(0, v),
          errorText: vm.fieldErrorFor('contacts.0.phone'),
        ),
        SearchableDropdownField<Currency>(
          label: context.tr('currency'),
          items: currencies,
          initialValue: statics.currency(draft.currencyId),
          displayString: (c) => '${c.code} · ${c.name}',
          idOf: (c) => c.id,
          // Cleared = inherit from the company/group cascade.
          onChanged: (c) => vm.setCurrencyId(c?.id ?? ''),
          errorText: vm.fieldErrorFor('settings.currency_id'),
        ),
      ],
    );
  }
}

class _AddressTab extends StatelessWidget {
  const _AddressTab({required this.vm});
  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    return _TabBody(
      children: [
        EntityEditField(
          label: context.tr('address1'),
          initial: draft.address1,
          onChanged: vm.setAddress1,
          errorText: vm.fieldErrorFor('address1'),
        ),
        EntityEditField(
          label: context.tr('address2'),
          initial: draft.address2,
          onChanged: vm.setAddress2,
          errorText: vm.fieldErrorFor('address2'),
        ),
        EntityEditField(
          label: context.tr('city'),
          initial: draft.city,
          onChanged: vm.setCity,
          errorText: vm.fieldErrorFor('city'),
        ),
        EntityEditField(
          label: context.tr('state'),
          initial: draft.state,
          onChanged: vm.setState,
          errorText: vm.fieldErrorFor('state'),
        ),
        EntityEditField(
          label: context.tr('postal_code'),
          initial: draft.postalCode,
          onChanged: vm.setPostalCode,
          errorText: vm.fieldErrorFor('postal_code'),
        ),
        ClientEditCountryField(
          initial: draft.countryId,
          onChanged: vm.setCountryId,
        ),
      ],
    );
  }
}

class _ShippingTab extends StatelessWidget {
  const _ShippingTab({required this.vm});
  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    return _TabBody(
      children: [
        EntityEditField(
          label: context.tr('shipping_address1'),
          initial: draft.shippingAddress1,
          onChanged: vm.setShippingAddress1,
          errorText: vm.fieldErrorFor('shipping_address1'),
        ),
        EntityEditField(
          label: context.tr('shipping_address2'),
          initial: draft.shippingAddress2,
          onChanged: vm.setShippingAddress2,
          errorText: vm.fieldErrorFor('shipping_address2'),
        ),
        EntityEditField(
          label: context.tr('city'),
          initial: draft.shippingCity,
          onChanged: vm.setShippingCity,
          errorText: vm.fieldErrorFor('shipping_city'),
        ),
        EntityEditField(
          label: context.tr('state'),
          initial: draft.shippingState,
          onChanged: vm.setShippingState,
          errorText: vm.fieldErrorFor('shipping_state'),
        ),
        EntityEditField(
          label: context.tr('postal_code'),
          initial: draft.shippingPostalCode,
          onChanged: vm.setShippingPostalCode,
          errorText: vm.fieldErrorFor('shipping_postal_code'),
        ),
        ClientEditCountryField(
          initial: draft.shippingCountryId,
          onChanged: vm.setShippingCountryId,
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.vm,
    required this.languages,
    required this.groups,
  });

  final ClientEditViewModel vm;
  final List<Language> languages;
  final Stream<List<GroupSetting>> groups;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    final statics = context.read<Services>().statics;
    // Stored as a num (see `setDefaultTaskRate`); render whole numbers without
    // a trailing `.0`, and tolerate a legacy string value.
    final rateRaw = draft.settings?['default_task_rate'];
    final taskRate = rateRaw == null
        ? ''
        : (rateRaw is num && rateRaw % 1 == 0
              ? rateRaw.toInt().toString()
              : rateRaw.toString());

    return _TabBody(
      children: [
        SearchableDropdownField<Language>(
          label: context.tr('language'),
          items: languages,
          initialValue: statics.language(draft.languageId),
          displayString: (l) => l.name,
          idOf: (l) => l.id,
          onChanged: (l) => vm.setLanguageId(l?.id ?? ''),
          errorText: vm.fieldErrorFor('settings.language_id'),
        ),
        // Payment terms and valid-until are day counts here, matching the full
        // client edit screen (React uses a term dropdown; in-app consistency
        // wins so the same client reads the same in both places).
        EntityEditField(
          label: context.tr('payment_terms'),
          initial: draft.paymentTerms,
          keyboardType: TextInputType.number,
          onChanged: vm.setPaymentTerms,
          errorText: vm.fieldErrorFor('settings.payment_terms'),
        ),
        EntityEditField(
          label: context.tr('valid_until'),
          initial: vm.validUntil,
          keyboardType: TextInputType.number,
          onChanged: vm.setValidUntil,
          errorText: vm.fieldErrorFor('settings.valid_until'),
        ),
        EntityEditField(
          label: context.tr('task_rate'),
          initial: taskRate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: vm.setDefaultTaskRate,
          errorText: vm.fieldErrorFor('settings.default_task_rate'),
        ),
        PlainRadioField<bool?>(
          label: context.tr('send_reminders'),
          value: vm.sendReminders,
          options: [
            (value: null, label: context.tr('default')),
            (value: true, label: context.tr('enabled')),
            (value: false, label: context.tr('disabled')),
          ],
          onChanged: vm.setSendReminders,
        ),
        _GroupPicker(vm: vm, groups: groups),
      ],
    );
  }
}

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({required this.vm, required this.groups});
  final ClientEditViewModel vm;

  /// Hoisted by the host — see the field's note there.
  final Stream<List<GroupSetting>> groups;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroupSetting>>(
      stream: groups,
      builder: (context, snapshot) {
        final groups = snapshot.data ?? const <GroupSetting>[];
        if (groups.isEmpty) return const SizedBox.shrink();
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
          displayString: (g) => g.name,
          idOf: (g) => g.id,
          onChanged: (g) => vm.setGroupSettingsId(g?.id ?? ''),
          errorText: vm.fieldErrorFor('group_settings_id'),
        );
      },
    );
  }
}

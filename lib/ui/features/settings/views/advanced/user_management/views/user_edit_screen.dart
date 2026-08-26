import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/data/models/domain/user.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/notifications.dart';
import 'package:admin/domain/permissions.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/view_models/user_edit_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/widgets/permission_grid.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/widgets/unconfirmed_email_banner.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Settings → User Management → New / Edit screen.
///
/// Three tabs: Details / Notifications / Permissions. Self-edit redirects to
/// `/settings/user_details`; owner Permissions tab is read-only.
class UserEditScreen extends StatefulWidget {
  const UserEditScreen({super.key, this.existingId});

  final String? existingId;

  @override
  State<UserEditScreen> createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  UserEditViewModel? _vm;
  bool _initialized = false;

  bool get _isCreate => widget.existingId == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final authUserId = session?.userId ?? '';
    final companyId = session?.currentCompanyId ?? '';

    // Self-edit redirect.
    if (widget.existingId != null && widget.existingId == authUserId) {
      Future.microtask(() {
        if (mounted) context.go('/settings/user_details');
      });
      return;
    }

    if (_isCreate) {
      _vm = UserEditViewModel(
        repo: services.user,
        companyId: companyId,
        firstNameRequiredMessage: context.tr('please_enter_a_first_name'),
        lastNameRequiredMessage: context.tr('please_enter_a_last_name'),
        emailRequiredMessage: context.tr('please_enter_your_email'),
        sync: services.sync,
        connectivity: services.connectivity,
      );
    } else {
      // Edit mode: capture password upfront (server gates GET /users/{id}
      // with 412), then fetch a fresh snapshot from the API so the form
      // shows server-canonical data — Drift may be stale or empty on a
      // deep-link. Falls back to the Drift row if the network fails.
      // Via a microtask, like the self-edit redirect above. `_loadExistingUser`
      // runs synchronously up to its first `await` — and that first await is
      // `showConfirmPasswordSheet`, whose own first statement is
      // `await showDialog(...)`, which pushes on the root Navigator
      // *synchronously*. From `didChangeDependencies` that lands inside the
      // build scope and trips `markNeedsBuild` on the root Overlay (an
      // ancestor): "setState() or markNeedsBuild() called during build". The
      // throw is swallowed by the `unawaited`, so in debug/profile the prompt
      // never appears, `_vm` is never assigned and the screen sits on a
      // spinner forever.
      Future.microtask(() {
        if (!mounted) return;
        unawaited(_loadExistingUser(services, companyId, widget.existingId!));
      });
    }
  }

  Future<void> _loadExistingUser(
    Services services,
    String companyId,
    String userId,
  ) async {
    // Offline-created user (tmp_<uuid>) — the server has never seen this
    // row, so don't prompt for password and don't hit the API (would 404).
    // The local Drift row is authoritative until the outbox drains and
    // applyCreateResponse swaps in the real id.
    if (userId.startsWith('tmp_')) {
      final local = await services.user.get(
        companyId: companyId,
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        _vm = UserEditViewModel(
          repo: services.user,
          companyId: companyId,
          existing: local,
          sync: services.sync,
          connectivity: services.connectivity,
        );
      });
      return;
    }

    // Ensure password is cached for the password-gated GET + the eventual
    // save round-trip. Skip the prompt when the cache is already warm.
    if (services.passwordCache.read() == null) {
      final ok = await showConfirmPasswordSheet(
        context,
        cache: services.passwordCache,
      );
      if (!ok) {
        if (!mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/settings/users');
        }
        return;
      }
    }
    User? existing;
    try {
      final apiUser = await services.user.api.getOne(id: userId);
      await services.user.applyApiResponse(companyId: companyId, api: apiUser);
      existing = await services.user.get(companyId: companyId, userId: userId);
    } catch (e) {
      // Network failure — fall back to Drift cache so the admin can at
      // least see what was last loaded. Surface the error inline.
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred'), error: e);
      }
      existing = await services.user.get(companyId: companyId, userId: userId);
    }
    if (!mounted) return;
    if (existing == null) {
      // Neither the network nor the local cache produced a user. Don't
      // build a VM with a blank draft (would let an admin "edit" a
      // phantom record). Route back to the list with a heads-up.
      Notify.error(context, context.tr('user_not_found'));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/settings/users');
      }
      return;
    }
    setState(() {
      _vm = UserEditViewModel(
        repo: services.user,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) {
      return SettingsScreenScaffold(
        titleKey: _isCreate ? 'new_user' : 'edit_user',
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return ChangeNotifierProvider<UserEditViewModel>.value(
      value: vm,
      child: _UserEditBody(isCreate: _isCreate),
    );
  }
}

class _UserEditBody extends StatelessWidget {
  const _UserEditBody({required this.isCreate});

  final bool isCreate;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UserEditViewModel>();
    // Deliberately not gated on the required fields being filled: a disabled
    // Save button can't say *why*, and `validate()` names the missing field
    // inline instead (invoiceninja/flutter#66).
    final canSave = !vm.isSaving;
    return DefaultTabController(
      length: 3,
      // `Builder` so the Save handlers below get a context UNDER the
      // controller — `_save` needs it to jump back to the Details tab, which
      // is the only tab that renders the field errors it publishes.
      child: Builder(
        builder: (context) => SettingsScreenScaffold(
          titleKey: isCreate ? 'new_user' : 'edit_user',
          leading: const BackButton(),
          actions: [
            TextButton(
              onPressed: canSave ? () => _save(context, vm) : null,
              child: Text(context.tr('save')),
            ),
          ],
          body: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: context.tr('details')),
                  Tab(text: context.tr('notifications')),
                  Tab(text: context.tr('permissions')),
                ],
              ),
              Expanded(
                child: FormSaveScope(
                  onSubmit: () => _save(context, vm),
                  enabled: canSave,
                  child: TabBarView(
                    children: [
                      _DetailsTab(vm: vm),
                      _NotificationsTab(vm: vm),
                      _PermissionsTab(vm: vm),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, UserEditViewModel vm) async {
    final services = context.read<Services>();
    // Check the form before asking the user to authenticate. Save is gated
    // only on `isSaving` (a disabled button can't say *why* it's disabled), so
    // without this a blank New User form answered a Save tap with the password
    // sheet and only then said "Please enter a first name" — authenticate
    // first, find out it was pointless second.
    if (!vm.validateAndPublish()) {
      // The errors `validateAndPublish` publishes are rendered ONLY by
      // `_DetailsTab` (tab 0). From Notifications or Permissions — a natural
      // first stop when provisioning a user — the early return used to be
      // completely silent: no toast, no tab change, no visible error, and Save
      // is deliberately never disabled (see `canSave`). Send the user to the
      // tab that can show the problem, and say what it is.
      DefaultTabController.maybeOf(context)?.animateTo(0);
      final first = vm.fieldErrors.values
          .expand((messages) => messages)
          .firstWhere((m) => m.trim().isNotEmpty, orElse: () => '');
      Notify.error(
        context,
        first.isEmpty ? context.tr('please_fill_out_all_fields') : first,
      );
      return;
    }
    // Every user mutation is password-gated server-side (412). Prime the cache
    // *before* the row is enqueued: otherwise the drain parks it, the sheet
    // pops after the form has already claimed success, and cancelling leaves a
    // dead row in the outbox behind a "Successfully created user" toast
    // (invoiceninja/flutter#64). Edit mode primes at load, but the cache holds
    // for 5 minutes and a long edit can outlive it.
    if (services.passwordCache.read() == null) {
      final ok = await showConfirmPasswordSheet(
        context,
        cache: services.passwordCache,
      );
      if (!ok || !context.mounted) return;
    }
    try {
      final saved = await vm.save();
      if (!context.mounted) return;
      // Null means the save never left the form — client-side validation, or a
      // 422 the VM has already attached to the offending fields. Stay put so
      // the inline errors are readable, but never end on silence: a 5xx or a
      // dropped connection has no field to hang itself on.
      if (saved == null) {
        if (vm.fieldErrors.isEmpty) {
          Notify.error(context, vm.submitError ?? context.tr('could_not_save'));
        }
        return;
      }
      Notify.success(
        context,
        context.tr(isCreate ? 'created_user' : 'updated_user'),
      );
      context.go('/settings/users');
    } catch (e) {
      if (context.mounted) {
        Notify.error(context, context.tr('could_not_save'), error: e);
      }
    }
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.vm});
  final UserEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    // A brand-new draft has emailVerifiedAt == 0 too, but hasn't been mailed
    // anything yet, so the banner must not show in create mode. Beyond that
    // the flag only means "email unconfirmed" — see `User.isEmailUnconfirmed`,
    // and invoiceninja/flutter#47 for what reading it as "pending invite" cost.
    final showUnconfirmed = !vm.isCreate && vm.draft.isEmailUnconfirmed;
    return SettingsFormShell(
      sections: [
        if (showUnconfirmed)
          FormSection(
            title: context.tr('email'),
            // No `onResend`: the draft may hold a typed-but-unsaved email
            // change, and the server would mail the address it still has.
            children: [const UnconfirmedEmailBanner()],
          ),
        FormSection(
          title: context.tr('details'),
          children: [
            _LabeledField(
              labelKey: 'first_name',
              initial: vm.draft.firstName,
              onChanged: vm.setFirstName,
              required: true,
              errorText: vm.fieldErrorFor('first_name'),
            ),
            // Required by `StoreUserRequest` just like the other two — the
            // star and the inline error say so now (flutter#66).
            _LabeledField(
              labelKey: 'last_name',
              initial: vm.draft.lastName,
              onChanged: vm.setLastName,
              required: vm.isCreate,
              errorText: vm.fieldErrorFor('last_name'),
            ),
            _LabeledField(
              labelKey: 'email',
              initial: vm.draft.email,
              onChanged: vm.setEmail,
              required: true,
              errorText: vm.fieldErrorFor('email'),
              keyboardType: TextInputType.emailAddress,
            ),
            _LabeledField(
              labelKey: 'phone',
              initial: vm.draft.phone,
              onChanged: vm.setPhone,
              keyboardType: TextInputType.phone,
            ),
            SwitchListTile(
              title: Text(context.tr('login_notification')),
              subtitle: Text(
                context.trIfDefined('login_notification_help') ?? '',
              ),
              value: vm.draft.userLoggedInNotification,
              onChanged: vm.setUserLoggedInNotification,
            ),
            // User custom fields (`user1..4`) — type-aware, gated by the
            // company's configured labels; renders nothing when none are set.
            Builder(
              builder: (context) {
                final services = context.read<Services>();
                return EntityCustomFieldsSection(
                  keyPrefix: 'user',
                  companyStream: services.company.watchCompany(vm.companyId),
                  formatter: services.formatterIfReady(vm.companyId),
                  wrapInCard: false,
                  values: [
                    vm.draft.customValue1,
                    vm.draft.customValue2,
                    vm.draft.customValue3,
                    vm.draft.customValue4,
                  ],
                  onChanged: [
                    vm.setCustomValue1,
                    vm.setCustomValue2,
                    vm.setCustomValue3,
                    vm.setCustomValue4,
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab({required this.vm});
  final UserEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final globalMuted = vm.notificationsGlobal;
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('notifications'),
          children: [
            ListTile(
              title: Text(context.tr('all_events')),
              trailing: DropdownButton<NotificationGlobal>(
                value: vm.globalNotification,
                onChanged: (v) {
                  if (v != null) vm.setNotificationGlobal(v);
                },
                items: [
                  for (final g in NotificationGlobal.values)
                    DropdownMenuItem(
                      value: g,
                      child: Text(context.tr(g.labelKey)),
                    ),
                ],
              ),
            ),
          ],
        ),
        for (final section in kNotificationSections)
          FormSection(
            title: context.tr(section.headerKey),
            children: [
              for (final event in section.events)
                Opacity(
                  opacity: globalMuted ? 0.4 : 1.0,
                  child: ListTile(
                    title: Text(context.tr(event.labelKey)),
                    trailing: DropdownButton<NotificationChoice>(
                      value: vm.notificationChoiceFor(event.id),
                      onChanged: globalMuted
                          ? null
                          : (v) {
                              if (v != null) {
                                vm.setNotificationChoice(event.id, v);
                              }
                            },
                      items: [
                        for (final c in NotificationChoice.values)
                          DropdownMenuItem(
                            value: c,
                            child: Text(context.tr(c.labelKey)),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _PermissionsTab extends StatelessWidget {
  const _PermissionsTab({required this.vm});
  final UserEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.isOwner) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Text(
            context.tr('company_owner_has_full_access'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('permissions'),
          children: [
            SwitchListTile(
              title: Text(context.tr('administrator')),
              subtitle: Text(context.trIfDefined('administrator_help') ?? ''),
              value: vm.isAdmin,
              onChanged: vm.setAdmin,
            ),
            const Divider(height: 1),
            for (final special in kPermissionSpecial)
              SwitchListTile(
                title: Text(
                  context.tr(kPermissionSpecialLabels[special] ?? special),
                ),
                subtitle: kPermissionSpecialHelp[special] == null
                    ? null
                    : Text(context.tr(kPermissionSpecialHelp[special]!)),
                value: vm.hasPermission(special),
                onChanged: vm.isAdmin
                    ? null
                    : (v) => vm.togglePermission(special),
              ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(InSpacing.md(context)),
              child: PermissionGrid(
                permissions: vm.permissions,
                isAdmin: vm.isAdmin,
                onChange: vm.setPermissions,
                onAutoPromote: (verb) {
                  // Per-verb keys so translators get sentence-cased copy
                  // without juggling interpolation hyphens.
                  Notify.success(context, context.tr('granted_${verb}_all'));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lightweight labeled text field — wires `FormSaveScope.trySubmit` on Enter
/// for single-line inputs so the form submits without a Save click.
class _LabeledField extends StatefulWidget {
  const _LabeledField({
    required this.labelKey,
    required this.initial,
    required this.onChanged,
    this.required = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
  });

  final String labelKey;
  final String initial;
  final ValueChanged<String> onChanged;
  final bool required;

  /// Inline rejection message from `vm.fieldErrorFor(<api key>)` — client-side
  /// validation or a server 422 for this field.
  final String? errorText;
  final TextInputType keyboardType;

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = FormSaveScope.maybeOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: 6,
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText:
              context.tr(widget.labelKey) + (widget.required ? ' *' : ''),
          errorText: widget.errorText,
          border: const OutlineInputBorder(),
        ),
        keyboardType: widget.keyboardType,
        textInputAction: TextInputAction.done,
        onChanged: widget.onChanged,
        onSubmitted: (_) => scope?.trySubmit(),
      ),
    );
  }
}

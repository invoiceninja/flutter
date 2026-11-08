import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:admin/domain/docuninja/docuninja_users.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_filter_dialog.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_inline_error.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

final _log = Logger('DocuNinjaUsersScreen');

/// Shows [child] once DocuNinja is ready and the user is the DocuNinja
/// owner (React's `docuNinjaOwner()` guard on the users pages); otherwise
/// the loading, "go to DocuNinja" or "not allowed" state.
class _OwnerGate extends StatefulWidget {
  const _OwnerGate({required this.title, required this.builder});

  final String title;
  final Widget Function(BuildContext, DocuNinjaState) builder;

  @override
  State<_OwnerGate> createState() => _OwnerGateState();
}

class _OwnerGateState extends State<_OwnerGate> {
  DocuNinjaSession? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<DocuNinjaSession?>();
    if (identical(session, _session)) return;
    _session = session;
    session?.load();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    return ValueListenableBuilder<DocuNinjaState>(
      valueListenable: session,
      builder: (context, state, _) {
        final owner = state.login?.companyUser.isOwner ?? false;
        final Widget body;
        if (state.access == DocuNinjaAccess.loading ||
            state.access == DocuNinjaAccess.unavailable) {
          body = const Center(child: CircularProgressIndicator());
        } else if (!state.isReady || state.company == null) {
          body = EmptyState(
            icon: Icons.draw_outlined,
            title: context.tr('docuninja'),
            action: TextButton(
              onPressed: () => context.go('/docuninja'),
              child: Text(context.tr('docuninja')),
            ),
          );
        } else if (!owner) {
          body = EmptyState(
            icon: Icons.lock_outline,
            title: context.tr('unauthorized_action'),
          );
        } else {
          body = KeyedSubtree(
            key: ValueKey(state.company!.id),
            child: widget.builder(context, state),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: body,
        );
      },
    );
  }
}

/// The seat limit: DocuNinja's `account.num_users` against the company's
/// DocuNinja users (one count, where React uses three).
class _Seats {
  const _Seats(this.used, this.max);

  final int used;
  final int max;

  bool get full => max > 0 && used >= max;
}

Future<_Seats> _seats(DocuNinjaApi api, DocuNinjaState state) async {
  final page = await api.users(
    ninjaCompanyKey: state.company!.ninjaCompanyKey,
    perPage: 1,
    status: 'active,archived',
  );
  return _Seats(page.total, state.login?.account.numUsers ?? 0);
}

/// React's users list (`/docuninja/users`, `Users.tsx`), for the DocuNinja
/// owner: name, email and status, the seat-limit alert, New User (grant
/// access) and each user's edit page. docs/docuninja.md § Users.
class DocuNinjaUsersScreen extends StatelessWidget {
  const DocuNinjaUsersScreen({super.key});

  @override
  Widget build(BuildContext context) => _OwnerGate(
    title: context.tr('users'),
    builder: (context, state) => _UsersList(state: state),
  );
}

class _UsersList extends StatefulWidget {
  const _UsersList({required this.state});

  final DocuNinjaState state;

  @override
  State<_UsersList> createState() => _UsersListState();
}

enum _UserAction { archive, restore, delete }

class _UsersListState extends State<_UsersList> {
  late final DocuNinjaApi _api = context.read<DocuNinjaApi>();
  late final DocuNinjaUsersViewModel _vm = DocuNinjaUsersViewModel(
    api: _api,
    ninjaCompanyKey: widget.state.company!.ninjaCompanyKey,
  )..refresh();
  final _scroll = ScrollController();
  _Seats? _seatCount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _countSeats();
  }

  @override
  void dispose() {
    _vm.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _countSeats() async {
    try {
      final seats = await _seats(_api, widget.state);
      if (mounted) setState(() => _seatCount = seats);
    } on Object catch (e, st) {
      _log.warning('Counting DocuNinja users failed', e, st);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_vm.refresh(), _countSeats()]);
  }

  void _onScroll() {
    if (!_scroll.hasClients ||
        !_vm.hasMore ||
        _vm.isLoading ||
        _vm.isLoadingMore ||
        _vm.error != null) {
      return;
    }
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 400) _vm.loadMore();
  }

  Future<void> _bulk(DnUser u, String action, String successKey) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.userBulk(action, [u.id]);
      if (!mounted) return;
      Notify.success(context, context.tr(successKey));
      await _refresh();
    } on Object catch (e, st) {
      _log.warning('DocuNinja user $action failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<EntityActionItem<_UserAction>> _items(DnUser u) {
    final subject = u.name.isEmpty ? u.email : u.name;
    EntityActionItem<_UserAction> item(
      _UserAction kind,
      IconData icon,
      String key,
      VoidCallback onTap, {
      bool destructive = false,
    }) => EntityActionItem<_UserAction>(
      kind: kind,
      icon: icon,
      label: context.tr(key),
      enabled: !_busy,
      confirm: true,
      isDestructive: destructive,
      isLifecycle: true,
      confirmSubject: subject,
      onTap: onTap,
    );
    return [
      if (u.isActive)
        item(
          _UserAction.archive,
          Icons.archive_outlined,
          'archive',
          () => _bulk(u, 'archive', 'archived_user'),
        ),
      if (!u.isActive)
        item(
          _UserAction.restore,
          Icons.restore_outlined,
          'restore',
          () => _bulk(u, 'restore', 'restored_user'),
        ),
      if (!u.isDeleted)
        item(
          _UserAction.delete,
          Icons.delete_outline,
          'delete',
          () => _bulk(u, 'delete', 'deleted_user'),
          destructive: true,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final seats = _seatCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // React's NumberOfUsersAlert, and its New User button: no seat left
        // means no new user.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                onPressed: seats == null || seats.full || _busy
                    ? null
                    : () async {
                        await context.push('/docuninja/users/access');
                        if (mounted) await _refresh();
                      },
                icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                label: Text(context.tr('new_user')),
              ),
              // The lifecycle filter, so an archived user can be restored.
              ListenableBuilder(
                listenable: _vm,
                builder: (context, _) => FilterIconButton(
                  activeCount: _vm.activeFilterCount,
                  onPressed: () async {
                    final picked =
                        await showDialog<
                          ({Set<String> states, Set<String> statuses})
                        >(
                          context: context,
                          builder: (_) => DnFilterDialog(states: _vm.states),
                        );
                    if (picked != null) {
                      _vm.setFilters(statuses: const {}, states: picked.states);
                    }
                  },
                ),
              ),
              if (seats != null && seats.max > 0)
                LtrText(
                  '${seats.used} / ${seats.max}',
                  style: TextStyle(color: context.inTheme.ink2),
                ),
              if (seats != null && seats.full)
                TextButton(
                  onPressed: () => context.go('/settings/account_management'),
                  child: Text(
                    '${context.tr('user_limit_reached')} · '
                    '${context.tr('upgrade')}',
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => _list(context),
          ),
        ),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final vm = _vm;
    if (!vm.hasLoaded && vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.items.isEmpty && vm.error != null) {
      return ErrorView(
        message: context.tr('an_error_occurred_try_again'),
        onRetry: _refresh,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
    final tokens = context.inTheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (vm.error != null && vm.items.isNotEmpty && !vm.isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DocuNinjaInlineError(
                  offline: vm.error == DnListError.offline,
                  onRetry: vm.retry,
                ),
              ),
            ),
          if (vm.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.group_outlined,
                title: context.tr('no_records_found'),
              ),
            )
          else
            SliverList.separated(
              itemCount: vm.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = vm.items[i];
                final (String key, Color fg, Color bg) = u.isDeleted
                    ? ('deleted', tokens.overdue, tokens.overdueSoft)
                    : u.isArchived
                    ? ('archived', tokens.partial, tokens.partialSoft)
                    : ('active', tokens.paid, tokens.paidSoft);
                return InkWell(
                  onTap: u.isDeleted
                      ? null
                      : () async {
                          await context.push('/docuninja/users/${u.id}');
                          if (mounted) await _refresh();
                        },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        8,
                        4,
                        8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.name.isEmpty ? u.email : u.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (u.name.isNotEmpty)
                                  LtrText(
                                    u.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: tokens.ink3,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: context.tr(key),
                            fgColor: fg,
                            bgColor: bg,
                            textStyle: TextStyle(
                              fontSize: 13,
                              color: tokens.ink,
                            ),
                          ),
                          EntityActionsPopupButton<_UserAction>(
                            items: _items(u),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          if (vm.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(InSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

/// React's user edit page (`users/edit/Edit.tsx`): the details read-only,
/// then the role and permissions and the notifications. React also edits a
/// user's saved signature and initials here; the app shows them but does
/// not edit them yet (docs/docuninja.md § Users).
class DocuNinjaUserScreen extends StatelessWidget {
  const DocuNinjaUserScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => _OwnerGate(
    title: context.tr('edit_user'),
    builder: (context, state) => _UserEditor(id: id),
  );
}

class _UserEditor extends StatefulWidget {
  const _UserEditor({required this.id});

  final String id;

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  late final DocuNinjaApi _api = context.read<DocuNinjaApi>();
  DnUser? _user;
  bool _failed = false;
  bool _saving = false;
  bool _isAdmin = false;
  List<DnPermission> _permissions = const [];
  DnNotificationChoice _notify = const DnNotificationChoice(DnNotify.none);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final u = await _api.user(widget.id);
      if (!mounted) return;
      setState(() {
        _user = u;
        _isAdmin = u.isAdmin;
        _permissions = [
          for (final p in u.permissions)
            if (p.permissionableId == null) p,
        ];
        _notify = DnNotificationChoice.decode(u.notifications);
      });
    } on Object catch (e, st) {
      _log.warning('Reading the DocuNinja user failed', e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save() async {
    final u = _user;
    if (u == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await _api.updateUser(
        u,
        isAdmin: _isAdmin,
        permissions: _permissions,
        notifications: _notify.encode(),
      );
      if (!mounted) return;
      setState(() => _user = saved);
      Notify.success(context, context.tr('updated_user'));
    } on Object catch (e, st) {
      _log.warning('Saving the DocuNinja user failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    if (_failed) {
      return ErrorView(
        message: context.tr('an_error_occurred_try_again'),
        onRetry: _load,
      );
    }
    if (u == null) return const Center(child: CircularProgressIndicator());
    final tokens = context.inTheme;
    return ListView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormSection(
                  title: context.tr('user_details'),
                  children: [
                    _ReadOnly(
                      label: context.tr('first_name'),
                      value: u.firstName,
                    ),
                    _ReadOnly(
                      label: context.tr('last_name'),
                      value: u.lastName,
                    ),
                    _ReadOnly(
                      label: context.tr('email'),
                      value: u.email,
                      ltr: true,
                    ),
                    if (u.eSignature.isNotEmpty)
                      _SavedImage(
                        label: context.tr('signature'),
                        dataUrl: u.eSignature,
                      ),
                    if (u.eInitials.isNotEmpty)
                      _SavedImage(
                        label: context.tr('initials'),
                        dataUrl: u.eInitials,
                      ),
                  ],
                ),
                SizedBox(height: InSpacing.lg(context)),
                FormSection(
                  title: context.tr('permissions'),
                  children: [
                    DnPermissionsGrid(
                      isAdmin: _isAdmin,
                      permissions: _permissions,
                      enabled: !_saving,
                      onAdminChanged: (v) => setState(() {
                        _isAdmin = v;
                        // React clears the grants when the role changes.
                        _permissions = const [];
                      }),
                      onChanged: (p) => setState(() => _permissions = p),
                    ),
                  ],
                ),
                SizedBox(height: InSpacing.lg(context)),
                FormSection(
                  title: context.tr('notifications'),
                  children: [
                    _NotifyDropdown(
                      label: context.tr('receive_all_notifications'),
                      value: _notify.master,
                      withCustom: true,
                      enabled: !_saving,
                      onChanged: (v) =>
                          setState(() => _notify = _notify.withMaster(v)),
                    ),
                    for (final (type, labelKey) in kDnNotificationTypes)
                      _NotifyDropdown(
                        label: context.tr(labelKey),
                        value: _notify.master == DnNotify.custom
                            ? _notify.of(type)
                            : _notify.master == DnNotify.none
                            ? DnNotify.none
                            : _notify.master,
                        enabled:
                            !_saving &&
                            _notify.master != DnNotify.all &&
                            _notify.master != DnNotify.allUser,
                        onChanged: (v) =>
                            setState(() => _notify = _notify.withType(type, v)),
                      ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: InSpacing.lg(context)),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 44),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.ink3,
                              ),
                            )
                          : Text(context.tr('save')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final shown = value.isEmpty ? '—' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: tokens.ink3, fontSize: 12)),
        if (ltr) LtrText(shown) else Text(shown),
      ],
    );
  }
}

/// A saved signature or initials, as React shows them (an image up to
/// 128 px tall).
class _SavedImage extends StatelessWidget {
  const _SavedImage({required this.label, required this.dataUrl});

  final String label;
  final String dataUrl;

  @override
  Widget build(BuildContext context) {
    final data = Uri.tryParse(dataUrl)?.data;
    final bytes = data?.contentAsBytes();
    if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxHeight: 128),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: context.inTheme.border),
            borderRadius: BorderRadius.circular(InRadii.r1),
          ),
          padding: const EdgeInsets.all(InSpacing.sm),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            semanticLabel: label,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _NotifyDropdown extends StatelessWidget {
  const _NotifyDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.withCustom = false,
  });

  final String label;
  final DnNotify value;
  final ValueChanged<DnNotify> onChanged;
  final bool enabled;
  final bool withCustom;

  @override
  Widget build(BuildContext context) {
    String text(DnNotify n) => context.tr(switch (n) {
      DnNotify.none => 'none',
      DnNotify.all => 'all',
      DnNotify.allUser => 'owned_by_user',
      DnNotify.custom => 'custom',
    });
    final options = [
      if (withCustom) DnNotify.custom,
      DnNotify.none,
      DnNotify.all,
      DnNotify.allUser,
    ];
    return DropdownButtonFormField<DnNotify>(
      key: ValueKey('$label:$value'),
      initialValue: options.contains(value) ? value : DnNotify.none,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(text(o))),
      ],
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null,
    );
  }
}

/// React's permissions grid (`components/Permissions.tsx`): Administrator,
/// then create / view / edit / delete (and requires approval for
/// documents) per model, with an All row. An administrator needs no
/// grants, so the boxes are off for one.
class DnPermissionsGrid extends StatelessWidget {
  const DnPermissionsGrid({
    super.key,
    required this.isAdmin,
    required this.permissions,
    required this.onAdminChanged,
    required this.onChanged,
    this.enabled = true,
  });

  final bool isAdmin;
  final List<DnPermission> permissions;
  final ValueChanged<bool> onAdminChanged;
  final ValueChanged<List<DnPermission>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final boxes = enabled && !isAdmin;
    bool allOn(DnAction a) => kDnPermissionModels.every(
      (m) =>
          !dnPermissionApplies(m.$1, a) ||
          dnHasPermission(permissions, m.$1, a),
    );
    Widget cell(Widget child) =>
        SizedBox(width: 64, child: Center(child: child));
    Widget header(String key) => cell(
      Text(
        context.tr(key),
        textAlign: TextAlign.center,
        style: TextStyle(color: tokens.ink3, fontSize: 12),
      ),
    );
    Widget row(String label, List<Widget> cells) => Row(
      children: [
        Expanded(child: Text(label)),
        ...cells,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: isAdmin,
          title: Text(context.tr('administrator')),
          onChanged: enabled ? onAdminChanged : null,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 480),
            child: Column(
              children: [
                row('', [
                  for (final (_, key) in kDnPermissionColumns) header(key),
                ]),
                row(context.tr('all'), [
                  for (final (a, _) in kDnPermissionColumns)
                    a == DnAction.requiresApproval
                        ? cell(const Text('—'))
                        : cell(
                            Checkbox(
                              value: !isAdmin && allOn(a),
                              onChanged: boxes
                                  ? (v) => onChanged(
                                      dnSetPermissionForAll(
                                        permissions,
                                        a,
                                        on: v ?? false,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                ]),
                for (final (model, labelKey) in kDnPermissionModels)
                  row(context.tr(labelKey), [
                    for (final (a, _) in kDnPermissionColumns)
                      dnPermissionApplies(model, a)
                          ? cell(
                              Checkbox(
                                value:
                                    !isAdmin &&
                                    dnHasPermission(permissions, model, a),
                                onChanged: boxes
                                    ? (v) => onChanged(
                                        dnSetPermission(
                                          permissions,
                                          model,
                                          a,
                                          on: v ?? false,
                                        ),
                                      )
                                    : null,
                              ),
                            )
                          : cell(const Text('—')),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// React's Grant Access page (`users/UserSelection.tsx`): the company's
/// Invoice Ninja users who have no DocuNinja user yet (matched by email),
/// picked within the seats left, with one role and set of permissions for
/// all of them; one `create_user` per user.
class DocuNinjaGrantAccessScreen extends StatelessWidget {
  const DocuNinjaGrantAccessScreen({super.key});

  @override
  Widget build(BuildContext context) => _OwnerGate(
    title: context.tr('add_user'),
    builder: (context, state) => _GrantAccess(state: state),
  );
}

class _GrantAccess extends StatefulWidget {
  const _GrantAccess({required this.state});

  final DocuNinjaState state;

  @override
  State<_GrantAccess> createState() => _GrantAccessState();
}

class _GrantAccessState extends State<_GrantAccess> {
  late final DocuNinjaApi _api = context.read<DocuNinjaApi>();
  List<User>? _available;
  _Seats? _seats0;
  bool _failed = false;
  bool _saving = false;
  final _selected = <String>{};
  bool _isAdmin = false;
  List<DnPermission> _permissions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null) return;
    try {
      final key = widget.state.company!.ninjaCompanyKey;
      final results = await Future.wait([
        services.user.watchAllForPicker(companyId: companyId).first,
        _api.users(
          ninjaCompanyKey: key,
          perPage: 10000,
          status: 'active,archived,deleted',
        ),
        _seats(_api, widget.state),
      ]);
      final inUsers = results[0] as List<User>;
      final dnUsers = (results[1] as DnPage<DnUser>).items;
      final taken = {for (final u in dnUsers) u.email.toLowerCase()};
      if (!mounted) return;
      setState(() {
        // React lists the account's active users other than the owner,
        // without a DocuNinja user of the same email.
        _available = [
          for (final u in inUsers)
            if (!u.isDeleted &&
                u.archivedAt == 0 &&
                !u.companyUser.isOwner &&
                u.email.isNotEmpty &&
                !taken.contains(u.email.toLowerCase()))
              u,
        ];
        _seats0 = results[2] as _Seats;
      });
    } on Object catch (e, st) {
      _log.warning('Reading users to grant DocuNinja access failed', e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  int get _left {
    final s = _seats0;
    if (s == null) return 0;
    if (s.max <= 0) return _available?.length ?? 0;
    return (s.max - s.used).clamp(0, 1 << 20);
  }

  Future<void> _grant() async {
    final loginApi = context.read<DocuNinjaLoginApi?>();
    final available = _available;
    if (loginApi == null || available == null || _saving) return;
    if (_selected.isEmpty) {
      Notify.error(context, context.tr('please_select_at_least_one_user'));
      return;
    }
    setState(() => _saving = true);
    try {
      await Future.wait([
        for (final u in available)
          if (_selected.contains(u.id))
            loginApi.createUser(
              userId: u.id,
              firstName: u.firstName,
              lastName: u.lastName,
              email: u.email,
              isAdmin: _isAdmin,
              permissions: [for (final p in _permissions) p.toJson()],
            ),
      ]);
      if (!mounted) return;
      Notify.success(
        context,
        context.tr('docuninja_access_granted_successfully'),
      );
      context.pop();
    } on Object catch (e, st) {
      _log.warning('Granting DocuNinja access failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      Notify.error(context, context.tr('docuninja_access_grant_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _available;
    if (_failed) {
      return ErrorView(
        message: context.tr('an_error_occurred_try_again'),
        onRetry: _load,
      );
    }
    if (available == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final tokens = context.inTheme;
    final seats = _seats0!;
    final Widget users;
    if (available.isEmpty) {
      users = Text(
        context.tr(
          seats.full
              ? 'max_users_reached'
              : 'docuninja_quota_available_but_no_users',
        ),
        style: TextStyle(color: tokens.ink2),
      );
    } else if (seats.full) {
      users = Text(
        context.tr('user_limit_reached'),
        style: TextStyle(color: tokens.ink2),
      );
    } else {
      users = Column(
        children: [
          for (final u in available)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _selected.contains(u.id),
              title: Text(u.displayName),
              subtitle: LtrText(u.email),
              onChanged:
                  _saving ||
                      (!_selected.contains(u.id) && _selected.length >= _left)
                  ? null
                  : (v) => setState(
                      () => v == true
                          ? _selected.add(u.id)
                          : _selected.remove(u.id),
                    ),
            ),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('docuninja_grant_access_help'),
                  style: TextStyle(color: tokens.ink2),
                ),
                SizedBox(height: InSpacing.md(context)),
                FormSection(
                  title: context.tr('users'),
                  trailing: seats.max > 0
                      ? LtrText(
                          '${seats.used + _selected.length} / ${seats.max}',
                          style: TextStyle(color: tokens.ink2),
                        )
                      : null,
                  children: [users],
                ),
                if (_selected.isNotEmpty) ...[
                  SizedBox(height: InSpacing.lg(context)),
                  FormSection(
                    title: context.tr('permissions'),
                    children: [
                      DnPermissionsGrid(
                        isAdmin: _isAdmin,
                        permissions: _permissions,
                        enabled: !_saving,
                        onAdminChanged: (v) => setState(() {
                          _isAdmin = v;
                          _permissions = const [];
                        }),
                        onChanged: (p) => setState(() => _permissions = p),
                      ),
                    ],
                  ),
                ],
                Padding(
                  padding: EdgeInsets.only(top: InSpacing.lg(context)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => context.pop(),
                        child: Text(context.tr('cancel')),
                      ),
                      SizedBox(width: InSpacing.md(context)),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 44),
                        ),
                        onPressed: _saving || _selected.isEmpty ? null : _grant,
                        child: Text(context.tr(_saving ? 'processing' : 'add')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

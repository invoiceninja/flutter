import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/shortcut_tooltip.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:admin/domain/docuninja/docuninja_send_rules.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_bulk.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_create_dialog.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_download.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_documents_list.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_filter_dialog.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_return_refresh.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_states.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

final _log = Logger('DocuNinjaScreen');

/// DocuNinja's home (`/docuninja`): the screen React's `Documents.tsx`
/// shows — Join, company setup, the plan wall, or the documents — decided
/// by [DocuNinjaSession] (docs/docuninja.md).
class DocuNinjaScreen extends StatefulWidget {
  const DocuNinjaScreen({super.key});

  @override
  State<DocuNinjaScreen> createState() => _DocuNinjaScreenState();
}

class _DocuNinjaScreenState extends State<DocuNinjaScreen> {
  DocuNinjaSession? _session;
  DocuNinjaDocumentsViewModel? _vm;
  String? _vmCompanyId;
  final _search = TextEditingController();
  bool _creating = false;

  /// Fields are placed in the browser for now: re-read the list when the
  /// user comes back to the app.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = dnRefreshOnReturn(_refreshList);
  }

  /// Whether the list is on screen. The DocuNinja branch stays mounted
  /// once visited (and the list stays under a document opened from it), so
  /// a refresh a live event, a return to the app or a company switch asks
  /// for while the user is elsewhere waits until the list shows again:
  /// one catch-up, not a stream of background requests. The company's
  /// handshake is not held: the pages over the list need it.
  bool _onStage = true;

  /// A list refresh was asked for while off screen.
  bool _stale = false;

  void _refreshList() {
    if (_onStage) {
      _vm?.refresh();
    } else {
      _stale = true;
    }
  }

  void _catchUp() {
    if (_stale) {
      _stale = false;
      _vm?.refresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onStage = TickerMode.valuesOf(context).enabled;
    if (onStage != _onStage) {
      _onStage = onStage;
      // After this frame: a refresh notifies its listeners at once.
      if (onStage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _onStage) _catchUp();
        });
      }
    }
    final session = context.read<DocuNinjaSession?>();
    if (identical(session, _session)) return;
    _session?.removeListener(_onSession);
    _session?.documentsChanged.removeListener(_onDocumentsChanged);
    _session?.remoteChanged.removeListener(_onDocumentsChanged);
    _session = session
      ?..addListener(_onSession)
      ..documentsChanged.addListener(_onDocumentsChanged)
      ..remoteChanged.addListener(_onDocumentsChanged);
    session?.load();
  }

  /// A reset (company switch, sign-out) leaves the session unavailable:
  /// load the new company's pairing, and drop the old company's list.
  void _onSession() {
    final session = _session;
    if (session == null || !mounted) return;
    final companyId = session.value.company?.id;
    // A change of company drops the list (and its search), and so does a
    // reset that settles on no company (an unpaired one); a reset still
    // on its way (unavailable, loading) keeps it, to land back on it.
    final settledElsewhere =
        companyId == null &&
        session.value.access != DocuNinjaAccess.unavailable &&
        session.value.access != DocuNinjaAccess.loading &&
        !session.value.isReady;
    if (_vmCompanyId != null &&
        (settledElsewhere ||
            (companyId != null && companyId != _vmCompanyId))) {
      _vm?.dispose();
      _vm = null;
      _vmCompanyId = null;
      _search.clear();
    }
    if (session.value.access == DocuNinjaAccess.unavailable &&
        (context.read<Services>().auth.session.value?.isHosted ?? false)) {
      // Even off screen: Templates, Users or Settings may be showing over
      // this list, and they wait on this handshake (one call a switch).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.load();
      });
    }
  }

  /// A document changed on its detail page: re-read the list, as React
  /// refetches its documents after every action.
  void _onDocumentsChanged() => _refreshList();

  DocuNinjaDocumentsViewModel? _documents(DocuNinjaState state) {
    final api = context.read<DocuNinjaApi?>();
    final companyId = state.company?.id;
    if (api == null || companyId == null) return null;
    if (_vm == null || _vmCompanyId != companyId) {
      _vm?.dispose();
      _vmCompanyId = companyId;
      _vm = DocuNinjaDocumentsViewModel(api: api)..refresh();
    }
    return _vm;
  }

  Future<void> _createAccount() async {
    final session = _session;
    if (session == null || _creating) return;
    final services = context.read<Services>();
    final loginApi = context.read<DocuNinjaLoginApi?>();
    if (loginApi == null) return;
    setState(() => _creating = true);
    try {
      await loginApi.createAccount();
    } on Object catch (e, st) {
      _log.warning('Creating the DocuNinja account failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
        setState(() => _creating = false);
      }
      return;
    }
    // The account exists now. The server also turned on the company's
    // DocuNinja flag: re-read the company, but whether or not that works,
    // re-run the handshake so the screen leaves Join.
    try {
      await services.auth.refresh();
    } on Object catch (e, st) {
      _log.warning('Refreshing after the DocuNinja account failed', e, st);
    }
    await session.load(force: true);
    if (mounted) setState(() => _creating = false);
  }

  void _upgrade() => context.go('/settings/account_management');

  /// Uploads a new document, then (as React does) opens its field builder:
  /// in the browser until the builder is embedded (docs/docuninja.md). The
  /// app lands on the new document, which re-reads when the user returns.
  Future<void> _create(DocuNinjaState state) async {
    final api = context.read<DocuNinjaApi?>();
    final companyId = context
        .read<Services>()
        .auth
        .session
        .value
        ?.currentCompanyId;
    if (api == null || companyId == null) return;
    final doc = await showDocuNinjaCreateDialog(
      context,
      api: api,
      // A timed-out upload may have landed: re-read the list.
      onMaybeCreated: () => _session?.markDocumentsChanged(),
    );
    if (doc != null) _opened(doc, companyId);
  }

  String? get _currentCompanyId =>
      context.read<Services>().auth.session.value?.currentCompanyId;

  /// A new document of [companyId]: the list re-reads, the app lands on it
  /// and (as React does) its builder opens — unless the user switched
  /// company while it uploaded, when it is not this company's to open.
  void _opened(DnDocument doc, String companyId) {
    _session?.markDocumentsChanged();
    if (!mounted || _currentCompanyId != companyId) return;
    context.go('/docuninja/${doc.id}');
    notifyAndOpenDocuNinjaBuilder(
      context,
      message: context.tr('document_created'),
      documentId: doc.id,
      companyId: companyId,
    );
  }

  /// React's drop zone above the table, for a DocuNinja role that may
  /// create: the files become a document at once, named after the first,
  /// and its builder opens, as after the `+` dialog.
  Widget? _dropZone(DocuNinjaState state) {
    final api = context.read<DocuNinjaApi?>();
    final companyId = _currentCompanyId;
    if (api == null ||
        companyId == null ||
        !state.can('documents', DnAction.create)) {
      return null;
    }
    return DocuNinjaDropZone(
      api: api,
      onMaybeCreated: () => _session?.markDocumentsChanged(),
      onCreated: (doc) => _opened(doc, companyId),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _session?.removeListener(_onSession);
    _session?.documentsChanged.removeListener(_onDocumentsChanged);
    _session?.remoteChanged.removeListener(_onDocumentsChanged);
    _vm?.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final globalNav = Breakpoints.isGlobalNavVisible(context);
    if (session == null) return const SizedBox.shrink();
    return ValueListenableBuilder<DocuNinjaState>(
      valueListenable: session,
      builder: (context, state, _) {
        final vm = state.isReady ? _documents(state) : null;
        return LayoutBuilder(
          builder: (context, pane) => _scaffold(
            context,
            state,
            vm,
            globalNav: globalNav,
            wide: pane.maxWidth >= kDocuNinjaTableMinWidth,
          ),
        );
      },
    );
  }

  /// On a wide pane the filters and React's Templates / Users / Settings
  /// sit in the toolbar above the list, as React's table toolbar has them;
  /// on a narrow one they fold into the app bar's filter icon and `⋮`.
  Widget _scaffold(
    BuildContext context,
    DocuNinjaState state,
    DocuNinjaDocumentsViewModel? vm, {
    required bool globalNav,
    required bool wide,
  }) {
    final canCreate = vm != null && state.can('documents', DnAction.create);
    // `N` starts a new document, as on the app's lists (React binds
    // `create_document` too); it falls through to a focused text field.
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyN): _NewDocumentIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewDocumentIntent: GuardedShortcutAction<_NewDocumentIntent>(
            onInvoke: (_) {
              if (canCreate) _create(state);
              return null;
            },
          ),
        },
        child: _scaffoldBody(
          context,
          state,
          vm,
          globalNav: globalNav,
          wide: wide,
        ),
      ),
    );
  }

  Widget _scaffoldBody(
    BuildContext context,
    DocuNinjaState state,
    DocuNinjaDocumentsViewModel? vm, {
    required bool globalNav,
    required bool wide,
  }) {
    return Scaffold(
      drawer: globalNav ? null : const AppDrawer(),
      appBar: AppBar(
        title: Text(context.tr('docuninja')),
        leading: globalNav ? null : const DrawerHamburger(),
        automaticallyImplyLeading: !globalNav,
        actions: [
          // React's drop zone and New Document page, for a DocuNinja
          // role that may create.
          if (vm != null && state.can('documents', DnAction.create))
            ShortcutTooltip(
              label: context.tr('new_document'),
              keys: const ['N'],
              child: IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _create(state),
              ),
            ),
          if (vm != null && !wide)
            ListenableBuilder(
              listenable: vm,
              builder: (context, _) => FilterIconButton(
                activeCount: vm.activeFilterCount,
                onPressed: () => _pickFilters(context, vm),
              ),
            ),
          // React's DocuNinja menu (templates, users, settings) and a
          // refresh, in one `⋮`: six icons would push the title off a
          // phone's app bar.
          if (vm != null)
            ListenableBuilder(
              listenable: vm,
              builder: (context, _) => EntityActionsPopupButton<_MenuAction>(
                items: [
                  // React's table checkboxes, for its bulk actions; on
                  // touch a long press on a row starts it too.
                  if (vm.items.isNotEmpty &&
                      !vm.isSelecting &&
                      _bulkActions(state).isNotEmpty)
                    EntityActionItem(
                      kind: _MenuAction.select,
                      icon: Icons.checklist,
                      label: context.tr('select'),
                      enabled: true,
                      onTap: vm.enterSelectionMode,
                    ),
                  if (!wide && state.can('blueprints', DnAction.view))
                    EntityActionItem(
                      kind: _MenuAction.templates,
                      icon: Icons.copy_all_outlined,
                      label: context.tr('templates'),
                      enabled: true,
                      isNavigationOnly: true,
                      onTap: () => context.go('/docuninja/templates'),
                    ),
                  if (!wide && (state.login?.companyUser.isOwner ?? false))
                    EntityActionItem(
                      kind: _MenuAction.users,
                      icon: Icons.group_outlined,
                      label: context.tr('users'),
                      enabled: true,
                      isNavigationOnly: true,
                      onTap: () => context.go('/docuninja/users'),
                    ),
                  if (!wide &&
                      state.login != null &&
                      dnIsAdmin(state.login!.companyUser))
                    EntityActionItem(
                      kind: _MenuAction.settings,
                      icon: Icons.settings_outlined,
                      label: context.tr('settings'),
                      enabled: true,
                      isNavigationOnly: true,
                      onTap: () => context.go('/docuninja/settings'),
                    ),
                  EntityActionItem(
                    kind: _MenuAction.refresh,
                    icon: Icons.refresh,
                    label: context.tr('refresh'),
                    // Always on: a refresh already in flight is shared.
                    enabled: true,
                    startsGroup: true,
                    onTap: vm.refresh,
                  ),
                ],
              ),
            ),
        ],
      ),
      // The search field sits in the body, not the app bar's fixed-height
      // `bottom`, so it grows with the text size instead of clipping.
      body: vm == null
          ? _body(context, state, vm)
          : ListenableBuilder(
              listenable: vm,
              // Back leaves selection before it leaves the screen.
              builder: (context, _) => PopScope(
                canPop: !vm.isSelecting,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) vm.clearSelection();
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The selection header takes the search row's place
                    // while selecting; the search keeps its text (the
                    // controller is the screen's).
                    if (vm.isSelecting)
                      LayoutBuilder(
                        builder: (context, c) => DnSelectionBar<DnDocument>(
                          vm: vm,
                          actions: _bulkActions(state),
                          wide: c.maxWidth >= kDocuNinjaTableMinWidth,
                        ),
                      )
                    else
                      _searchBar(context, state, vm, wide: wide),
                    Expanded(child: _body(context, state, vm)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _searchBar(
    BuildContext context,
    DocuNinjaState state,
    DocuNinjaDocumentsViewModel vm, {
    required bool wide,
  }) {
    final field = TextField(
      controller: _search,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search, size: 18),
        hintText: context.tr('search'),
        suffixIcon: ListenableBuilder(
          listenable: _search,
          builder: (context, _) => _search.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: context.tr('clear'),
                  onPressed: () {
                    _search.clear();
                    vm.setSearch('');
                  },
                ),
        ),
      ),
      onChanged: vm.setSearch,
    );
    // The list's own inset, so the toolbar lines up with the drop zone and
    // the table under it.
    final inset = dnListInset(table: wide);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        inset,
        InSpacing.lg(context),
        inset,
        InSpacing.lg(context),
      ),
      child: wide
          ? _wideToolbar(context, state, vm, field)
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: field,
              ),
            ),
    );
  }

  /// React's table toolbar (`datatables/Actions.tsx`): the search, the
  /// Lifecycle and Status filters showing what they hold, and the way to
  /// Templates, Users and Settings for the roles that may see them. It wraps
  /// rather than overflow a narrow-ish pane.
  Widget _wideToolbar(
    BuildContext context,
    DocuNinjaState state,
    DocuNinjaDocumentsViewModel vm,
    Widget field,
  ) {
    String names(Iterable<String> keys, List<String> order) {
      final sorted = [
        for (final k in order)
          if (keys.contains(k)) context.tr(k),
      ];
      return sorted.isEmpty ? context.tr('all') : sorted.join(', ');
    }

    Widget filter(String labelKey, String value) => OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      onPressed: () => _pickFilters(context, vm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              '${context.tr(labelKey)}: $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );

    Widget link(IconData icon, String labelKey, String route) =>
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          icon: Icon(icon, size: 18),
          label: Text(context.tr(labelKey)),
          onPressed: () => context.go(route),
        );

    final login = state.login;
    return Wrap(
      spacing: InSpacing.sm,
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 320, child: field),
        filter('lifecycle', names(vm.states, kDocuNinjaStateFilters)),
        filter('status', names(vm.statuses, kDocuNinjaStatusFilters)),
        if (state.can('blueprints', DnAction.view))
          link(Icons.copy_all_outlined, 'templates', '/docuninja/templates'),
        if (login?.companyUser.isOwner ?? false)
          link(Icons.group_outlined, 'users', '/docuninja/users'),
        if (login != null && dnIsAdmin(login.companyUser))
          link(Icons.settings_outlined, 'settings', '/docuninja/settings'),
      ],
    );
  }

  /// Back to everything: no search, React's default Active and no status.
  void _clearFilters(DocuNinjaDocumentsViewModel vm) {
    _search.clear();
    vm.setSearch('');
    vm.setFilters(statuses: const {}, states: const {'active'});
  }

  Widget _body(
    BuildContext context,
    DocuNinjaState state,
    DocuNinjaDocumentsViewModel? vm,
  ) {
    final auth = context.read<Services>().auth.session.value;
    final me = auth?.currentCompany;
    switch (state.access) {
      // Self-hosted never gets here (the route redirects home), so
      // unavailable is the moment before the first handshake.
      case DocuNinjaAccess.unavailable:
      case DocuNinjaAccess.loading:
        return const Center(child: CircularProgressIndicator());
      case DocuNinjaAccess.notJoined:
        return DocuNinjaJoinView(
          isAdmin: (me?.isAdmin ?? false) || (me?.isOwner ?? false),
          isEligible: auth?.plan == 'pro' || auth?.plan == 'enterprise',
          isCreating: _creating,
          onCreate: _createAccount,
          onUpgrade: _upgrade,
        );
      case DocuNinjaAccess.companySetup:
        return DocuNinjaCompanySetupView(
          isWorking: _creating,
          onSetUp: _createAccount,
        );
      case DocuNinjaAccess.planWall:
        return DocuNinjaPlanWallView(onUpgrade: _upgrade);
      case DocuNinjaAccess.offline:
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: context.tr('offline'),
          action: TextButton(
            onPressed: () => _session?.load(force: true),
            child: Text(context.tr('retry')),
          ),
        );
      case DocuNinjaAccess.failed:
        return ErrorView(
          message: context.tr('an_error_occurred_try_again'),
          onRetry: () => _session?.load(force: true),
        );
      case DocuNinjaAccess.ready:
        if (vm == null) return const SizedBox.shrink();
        return DocuNinjaDocumentsList(
          // A new company's list is a new list: its own date format (read
          // once, at mount) and the top of the scroll.
          key: ObjectKey(vm),
          vm: vm,
          selectable: _bulkActions(state).isNotEmpty,
          header: _dropZone(state),
          onClearFilters: () => _clearFilters(vm),
          onOpen: (doc) => context.go('/docuninja/${doc.id}'),
          actionsFor: (doc) {
            final items = _rowItems(state, vm, doc);
            // A row with nothing this role may do (a deleted document for
            // a view-only role) keeps the slot, so the columns stay put,
            // with no ⋮ that opens an empty menu.
            return Visibility(
              visible: items.isNotEmpty,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: EntityActionsPopupButton<_RowAction>(items: items),
            );
          },
        );
    }
  }

  bool _rowBusy = false;

  /// The bulk actions this user's DocuNinja role allows.
  List<DnBulkAction<DnDocument>> _bulkActions(DocuNinjaState state) =>
      dnPermittedBulkActions(
        _kBulkActions,
        canEdit: state.can('documents', DnAction.edit),
        canDelete: state.can('documents', DnAction.delete),
      );

  /// React's list row actions (`documents/common/hooks/useActions.tsx`)
  /// that act at once; Send, Options and the downloads open dialogs that
  /// live on the document page, a tap away.
  List<EntityActionItem<_RowAction>> _rowItems(
    DocuNinjaState state,
    DocuNinjaDocumentsViewModel vm,
    DnDocument doc,
  ) {
    final title = doc.description.isEmpty
        ? context.tr('untitled_document')
        : doc.description;
    final completed = dnIsCompleted(doc);
    // DocuNinja's own role (React offers every action and lets DocuNinja
    // refuse it with an error): what this user may not do is not offered.
    final canEdit = state.can('documents', DnAction.edit);
    final canCreate = state.can('documents', DnAction.create);
    final canDelete = state.can('documents', DnAction.delete);
    EntityActionItem<_RowAction> item(
      _RowAction kind,
      IconData icon,
      String key,
      Future<void> Function() run, {
      bool confirm = false,
      String? confirmMessageKey,
      bool destructive = false,
      bool lifecycle = false,
      bool enabled = true,
    }) => EntityActionItem<_RowAction>(
      kind: kind,
      icon: icon,
      label: context.tr(key),
      enabled: enabled && !_rowBusy,
      confirm: confirm,
      confirmMessageKey: confirmMessageKey,
      isDestructive: destructive,
      isLifecycle: lifecycle,
      confirmSubject: title,
      onTap: run,
    );
    return [
      if (!doc.isDeleted && canEdit)
        item(
          _RowAction.edit,
          Icons.edit_outlined,
          'edit',
          () => _openBuilder(doc),
          enabled: !completed && doc.status != DnDocumentStatus.voided,
        ),
      // React hides Timeline on a deleted document.
      if (!doc.isDeleted)
        item(
          _RowAction.open,
          Icons.timeline,
          'timeline',
          () async => context.go('/docuninja/${doc.id}'),
        ),
      if (completed && !doc.isDeleted && doc.files.isNotEmpty)
        item(
          _RowAction.viewPdf,
          Icons.picture_as_pdf_outlined,
          'view_pdf',
          () async => context.go('/docuninja/${doc.id}/pdf'),
        ),
      // React's row Audit Log and Download, on a completed document, the
      // rows a user downloads from; DocuNinja's own file names.
      if (completed)
        item(
          _RowAction.auditLog,
          Icons.fact_check_outlined,
          'audit_log',
          () => _rowDownload(
            () => context.read<DocuNinjaApi>().auditLog(doc.id),
            '${title}_audit_log',
          ),
        ),
      if (completed)
        item(
          _RowAction.download,
          Icons.download_outlined,
          'download',
          () => _rowDownload(
            () => context.read<DocuNinjaApi>().download(doc.id),
            title,
          ),
        ),
      if (!doc.isDeleted && canCreate)
        item(
          _RowAction.clone,
          Icons.copy_outlined,
          'clone',
          () => _rowRun(vm, () async {
            final json = await context.read<DocuNinjaApi>().action(
              doc.id,
              'clone',
            );
            final data = json is Map ? json['data'] : null;
            final id = data is Map ? '${data['id'] ?? ''}' : '';
            // Not if a company switch replaced the list meanwhile: the new
            // id would open under the other company.
            if (!mounted || !identical(vm, _vm)) return;
            Notify.success(context, context.tr('cloned_document'));
            if (id.isNotEmpty) context.go('/docuninja/$id');
          }),
          confirm: true,
          confirmMessageKey: 'clone_document_description',
        ),
      if (!doc.isDeleted && state.can('blueprints', DnAction.create))
        item(
          _RowAction.makeTemplate,
          Icons.copy_all_outlined,
          'clone_to_template',
          () => _rowRun(vm, () async {
            final companyId = context
                .read<Services>()
                .auth
                .session
                .value
                ?.currentCompanyId;
            final id = await context.read<DocuNinjaApi>().makeBlueprint(doc.id);
            // Not if a company switch replaced the list meanwhile: the new
            // id would open under the other company.
            if (!mounted || !identical(vm, _vm)) return;
            if (id.isEmpty || companyId == null) {
              throw StateError('make_blueprint returned no id');
            }
            notifyAndOpenDocuNinjaBuilder(
              context,
              message: context.tr('template_created'),
              documentId: id,
              companyId: companyId,
              template: true,
            );
          }),
          confirm: true,
        ),
      if (dnCanVoid(doc) && canEdit)
        item(
          _RowAction.voidIt,
          Icons.block_outlined,
          'void',
          () => _rowRun(vm, () async {
            await context.read<DocuNinjaApi>().action(doc.id, 'void');
            // Not if a company switch replaced the list meanwhile: the new
            // id would open under the other company.
            if (!mounted || !identical(vm, _vm)) return;
            Notify.success(context, context.tr('voided_document'));
            // React goes to the voided document.
            context.go('/docuninja/${doc.id}');
          }),
          confirm: true,
          destructive: true,
        ),
      if (!doc.isArchived && !doc.isDeleted && canEdit)
        item(
          _RowAction.archive,
          Icons.archive_outlined,
          'archive',
          () => _rowBulk(vm, doc, 'archive', 'document_archived'),
          confirm: true,
          confirmMessageKey: 'archive_document_description',
          lifecycle: true,
        ),
      if ((doc.isArchived || doc.isDeleted) && canEdit)
        item(
          _RowAction.restore,
          Icons.restore_outlined,
          'restore',
          () => _rowBulk(vm, doc, 'restore', 'document_restored'),
          lifecycle: true,
        ),
      if (!doc.isDeleted && canDelete)
        item(
          _RowAction.delete,
          Icons.delete_outline,
          'delete',
          () => _rowBulk(vm, doc, 'delete', 'deleted_document'),
          confirm: true,
          destructive: true,
          lifecycle: true,
        ),
    ];
  }

  Future<void> _openBuilder(DnDocument doc) async {
    final companyId = context
        .read<Services>()
        .auth
        .session
        .value
        ?.currentCompanyId;
    if (companyId == null) return;
    await openDocuNinjaBuilder(
      context,
      documentId: doc.id,
      companyId: companyId,
    );
  }

  Future<void> _rowBulk(
    DocuNinjaDocumentsViewModel vm,
    DnDocument doc,
    String action,
    String successKey,
  ) => _rowRun(vm, () async {
    await context.read<DocuNinjaApi>().bulk(action, [doc.id]);
    if (mounted) Notify.success(context, context.tr(successKey));
  });

  /// One row action at a time; the list re-reads after it either way.
  /// One download at a time, as the document page has it; the row menu
  /// stays usable for the rest meanwhile.
  bool _rowDownloading = false;

  Future<void> _rowDownload(
    Future<DnFileBytes> Function() fetch,
    String fallbackName,
  ) async {
    if (_rowDownloading) return;
    _rowDownloading = true;
    try {
      await dnSaveFile(context, fetch: fetch, fallbackName: fallbackName);
    } finally {
      _rowDownloading = false;
    }
  }

  Future<void> _rowRun(
    DocuNinjaDocumentsViewModel vm,
    Future<void> Function() run,
  ) async {
    if (_rowBusy) return;
    setState(() => _rowBusy = true);
    try {
      await run();
    } on Object catch (e, st) {
      _log.warning('DocuNinja row action failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      if (mounted) setState(() => _rowBusy = false);
      // Not a list a company switch has since replaced.
      if (identical(vm, _vm)) unawaited(vm.refresh());
    }
  }

  Future<void> _pickFilters(
    BuildContext context,
    DocuNinjaDocumentsViewModel vm,
  ) async {
    final picked =
        await showDialog<({Set<String> states, Set<String> statuses})>(
          context: context,
          builder: (context) => DnFilterDialog(
            states: vm.states,
            statuses: vm.statuses,
            statusOptions: kDocuNinjaStatusFilters,
          ),
        );
    if (picked != null) {
      vm.setFilters(statuses: picked.statuses, states: picked.states);
    }
  }
}

enum _RowAction {
  edit,
  open,
  viewPdf,
  auditLog,
  download,
  clone,
  makeTemplate,
  voidIt,
  archive,
  restore,
  delete,
}

enum _MenuAction { select, templates, users, settings, refresh }

class _NewDocumentIntent extends Intent {
  const _NewDocumentIntent();
}

/// React's bulk actions on the documents table.
final _kBulkActions = dnLifecycleBulkActions<DnDocument>(
  noun: 'document',
  isActive: (d) => !d.isDeleted && !d.isArchived,
  isDeleted: (d) => d.isDeleted,
);

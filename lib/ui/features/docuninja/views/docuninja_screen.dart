import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_create_dialog.dart';
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
    _lifecycle = dnRefreshOnReturn(() => _vm?.refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (_vmCompanyId != null && companyId != _vmCompanyId) {
      _vm?.dispose();
      _vm = null;
      _vmCompanyId = null;
      _search.clear();
    }
    if (session.value.access == DocuNinjaAccess.unavailable &&
        (context.read<Services>().auth.session.value?.isHosted ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) session.load();
      });
    }
  }

  /// A document changed on its detail page: re-read the list, as React
  /// refetches its documents after every action.
  void _onDocumentsChanged() => _vm?.refresh();

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
    final doc = await showDocuNinjaCreateDialog(context, api: api);
    if (doc == null || !mounted) return;
    _session?.markDocumentsChanged();
    Notify.success(context, context.tr('document_created'));
    context.go('/docuninja/${doc.id}');
    await openDocuNinjaBuilder(
      context,
      documentId: doc.id,
      companyId: companyId,
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
        return Scaffold(
          drawer: globalNav ? null : const AppDrawer(),
          appBar: AppBar(
            title: Text(context.tr('docuninja')),
            leading: globalNav ? null : const DrawerHamburger(),
            automaticallyImplyLeading: !globalNav,
            actions: [
              // React's DocuNinja menu: the templates beside the documents.
              if (vm != null && state.can('blueprints', DnAction.view))
                IconButton(
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: context.tr('templates'),
                  onPressed: () => context.go('/docuninja/templates'),
                ),
              // React's users page, for the DocuNinja owner.
              if (vm != null && (state.login?.companyUser.isOwner ?? false))
                IconButton(
                  icon: const Icon(Icons.group_outlined),
                  tooltip: context.tr('users'),
                  onPressed: () => context.go('/docuninja/users'),
                ),
              // React's settings button, for a DocuNinja admin.
              if (vm != null &&
                  state.login != null &&
                  dnIsAdmin(state.login!.companyUser))
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: context.tr('settings'),
                  onPressed: () => context.go('/docuninja/settings'),
                ),
              // React's drop zone and New Document page, for a DocuNinja
              // role that may create.
              if (vm != null && state.can('documents', DnAction.create))
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.tr('new_document'),
                  onPressed: () => _create(state),
                ),
              if (vm != null) ...[
                ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) => FilterIconButton(
                    activeCount: vm.activeFilterCount,
                    onPressed: () => _pickFilters(context, vm),
                  ),
                ),
                ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) => IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: context.tr('refresh'),
                    onPressed: vm.isLoading ? null : vm.refresh,
                  ),
                ),
              ],
            ],
          ),
          // The search field sits in the body, not the app bar's fixed-height
          // `bottom`, so it grows with the text size instead of clipping.
          body: vm == null
              ? _body(context, state, vm)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _searchBar(context, vm),
                    Expanded(child: _body(context, state, vm)),
                  ],
                ),
        );
      },
    );
  }

  Widget _searchBar(BuildContext context, DocuNinjaDocumentsViewModel vm) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: TextField(
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
            ),
          ),
        ),
      );

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
          vm: vm,
          onOpen: (doc) => context.go('/docuninja/${doc.id}'),
        );
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_bulk.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_filter_dialog.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_inline_error.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_states.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_return_refresh.dart';

final _log = Logger('DocuNinjaTemplatesScreen');

/// DocuNinja's templates (`/docuninja/templates`, React's `Blueprints.tsx`):
/// a template is a document with its fields placed, from which new
/// documents are made. docs/docuninja.md § Templates.
class DocuNinjaTemplatesScreen extends StatefulWidget {
  const DocuNinjaTemplatesScreen({super.key});

  @override
  State<DocuNinjaTemplatesScreen> createState() =>
      _DocuNinjaTemplatesScreenState();
}

enum _Action { use, options, archive, restore, delete }

/// React's bulk actions on the templates table.
final _kBulkActions = dnLifecycleBulkActions<DnBlueprint>(
  noun: 'template',
  isActive: (t) => !t.isDeleted && !t.isArchived,
  isDeleted: (t) => t.isDeleted,
);

/// Wide enough for the checkbox slot to sit on every row (hover-revealed).
const double _kWide = 720;

class _DocuNinjaTemplatesScreenState extends State<DocuNinjaTemplatesScreen> {
  DocuNinjaSession? _session;
  DocuNinjaTemplatesViewModel? _vm;
  String? _vmCompanyId;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  /// The template builder may run in the browser: re-read on coming back.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _lifecycle = dnRefreshOnReturn(() => _vm?.refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<DocuNinjaSession?>();
    if (identical(session, _session)) return;
    _session?.documentsChanged.removeListener(_onChanged);
    _session?.remoteChanged.removeListener(_onChanged);
    _session = session
      ?..documentsChanged.addListener(_onChanged)
      ..remoteChanged.addListener(_onChanged);
    // Opened directly (a restored route): the handshake may not have run.
    session?.load();
  }

  /// A template saved in the embedded builder, or made from a document.
  void _onChanged() => _vm?.refresh();

  @override
  void dispose() {
    _lifecycle.dispose();
    _session?.documentsChanged.removeListener(_onChanged);
    _session?.remoteChanged.removeListener(_onChanged);
    _vm?.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  DocuNinjaTemplatesViewModel? _templates(DocuNinjaState state) {
    final api = context.read<DocuNinjaApi?>();
    final companyId = state.company?.id;
    if (api == null || companyId == null) return null;
    if (_vm == null || _vmCompanyId != companyId) {
      _vm?.dispose();
      _vmCompanyId = companyId;
      _search.clear();
      _vm = DocuNinjaTemplatesViewModel(api: api)..refresh();
    }
    return _vm;
  }

  void _onScroll() {
    final vm = _vm;
    if (vm == null ||
        !_scroll.hasClients ||
        !vm.hasMore ||
        vm.isLoading ||
        vm.isLoadingMore ||
        vm.error != null) {
      return;
    }
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 400) vm.loadMore();
  }

  /// React's lifecycle filter: without it an archived or deleted template
  /// could never be listed again, nor restored.
  Future<void> _pickStates(DocuNinjaTemplatesViewModel vm) async {
    final picked =
        await showDialog<({Set<String> states, Set<String> statuses})>(
          context: context,
          builder: (_) => DnFilterDialog(states: vm.states),
        );
    if (picked != null) {
      vm.setFilters(statuses: const {}, states: picked.states);
    }
  }

  String? get _companyId =>
      context.read<Services>().auth.session.value?.currentCompanyId;

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    return ValueListenableBuilder<DocuNinjaState>(
      valueListenable: session,
      builder: (context, state, _) {
        final canView = state.can('blueprints', DnAction.view);
        final canCreate = state.can('blueprints', DnAction.create);
        final vm = state.isReady && canView ? _templates(state) : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('templates')),
            actions: [
              if (vm != null && canCreate)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.tr('new_template'),
                  onPressed: _busy ? null : () => _create(vm),
                ),
              // React's table checkboxes, for its bulk actions; on touch a
              // long press on a row starts it too.
              if (vm != null)
                ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) =>
                      vm.items.isEmpty || vm.isSelecting || _bulkActions.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.checklist),
                          tooltip: context.tr('select'),
                          onPressed: vm.enterSelectionMode,
                        ),
                ),
              if (vm != null)
                ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) => FilterIconButton(
                    activeCount: vm.activeFilterCount,
                    onPressed: () => _pickStates(vm),
                  ),
                ),
              if (vm != null)
                ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) => IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: context.tr('refresh'),
                    onPressed: vm.isLoading ? null : vm.refresh,
                  ),
                ),
            ],
          ),
          body: _body(context, state, vm, canView, canCreate),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    DocuNinjaState state,
    DocuNinjaTemplatesViewModel? vm,
    bool canView,
    bool canCreate,
  ) {
    switch (state.access) {
      case DocuNinjaAccess.unavailable || DocuNinjaAccess.loading:
        return const Center(child: CircularProgressIndicator());
      case DocuNinjaAccess.ready:
        break;
      default:
        // Join, setup, the plan wall and the errors live on DocuNinja's
        // home: send the user there.
        return DocuNinjaGoHomeState(access: state.access);
    }
    if (!canView || vm == null) {
      return EmptyState(
        icon: Icons.lock_outline,
        title: context.tr('unauthorized_action'),
      );
    }
    final search = Padding(
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
            ),
            onChanged: vm.setSearch,
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => ListenableBuilder(
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
              // The selection header takes the search row's place while
              // selecting; the search keeps its text (the controller is the
              // screen's).
              if (vm.isSelecting)
                DnSelectionBar<DnBlueprint>(
                  vm: vm,
                  actions: _bulkActions,
                  wide: c.maxWidth >= _kWide,
                )
              else
                search,
              Expanded(
                child: _list(context, vm, canCreate, c.maxWidth >= _kWide),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    DocuNinjaTemplatesViewModel vm,
    bool canCreate,
    bool wide,
  ) {
    if (!vm.hasLoaded && vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.items.isEmpty && vm.error != null) {
      return ErrorView(
        message: context.tr(
          vm.error == DnListError.offline
              ? 'offline'
              : 'an_error_occurred_try_again',
        ),
        onRetry: vm.refresh,
      );
    }
    // A first page that fits the pane never scrolls: check after layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
    final showError = vm.error != null && vm.items.isNotEmpty && !vm.isLoading;
    Widget notice() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DocuNinjaInlineError(
        offline: vm.error == DnListError.offline,
        onRetry: vm.retry,
      ),
    );
    return RefreshIndicator(
      onRefresh: vm.refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showError && !vm.errorFromMore)
            SliverToBoxAdapter(child: notice()),
          if (vm.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.copy_all_outlined,
                title: context.tr('no_records_found'),
              ),
            )
          else
            SliverList.separated(
              itemCount: vm.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = vm.items[i];
                final selecting = vm.isSelecting;
                void toggle() => vm.toggleSelected(t);
                return _TemplateRow(
                  template: t,
                  // Selecting, a tap ticks the row. Otherwise React opens
                  // every template's builder, a deleted one too.
                  onTap: selecting
                      ? toggle
                      : canCreate
                      ? () => _edit(t)
                      : null,
                  // No selection where no bulk action is allowed.
                  onLongPress: _bulkActions.isEmpty ? null : toggle,
                  selected: vm.isSelected(t),
                  leading: dnSelectLeading(
                    wide: wide && _bulkActions.isNotEmpty,
                    selecting: selecting,
                    selected: vm.isSelected(t),
                    onToggle: toggle,
                  ),
                  // No row menu while selecting: the bulk actions are it.
                  actions: selecting ? const [] : _items(context, vm, t),
                );
              },
            ),
          if (showError && vm.errorFromMore)
            SliverToBoxAdapter(child: notice()),
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

  /// Whether this user's DocuNinja role allows [action] on [model].
  bool _can(String model, DnAction action) =>
      _session?.value.can(model, action) ?? false;

  /// The bulk actions this user's DocuNinja role allows.
  List<DnBulkAction<DnBlueprint>> get _bulkActions => dnPermittedBulkActions(
    _kBulkActions,
    canEdit: _can('blueprints', DnAction.edit),
    canDelete: _can('blueprints', DnAction.delete),
  );

  /// React's template row actions (`blueprints/common/hooks/useActions.tsx`),
  /// less what this user's DocuNinja role would have refused (React offers
  /// them all).
  List<EntityActionItem<_Action>> _items(
    BuildContext context,
    DocuNinjaTemplatesViewModel vm,
    DnBlueprint t,
  ) {
    final title = t.name.isEmpty ? context.tr('untitled_template') : t.name;
    EntityActionItem<_Action> item(
      _Action kind,
      IconData icon,
      String key, {
      bool confirm = false,
      bool destructive = false,
      bool lifecycle = false,
    }) => EntityActionItem<_Action>(
      kind: kind,
      icon: icon,
      label: context.tr(key),
      enabled: !_busy,
      confirm: confirm,
      isDestructive: destructive,
      isLifecycle: lifecycle,
      confirmSubject: title,
      onTap: () => _onAction(vm, t, kind),
    );
    final canEdit = _can('blueprints', DnAction.edit);
    return [
      if (!t.isDeleted && _can('documents', DnAction.create))
        item(_Action.use, Icons.note_add_outlined, 'use_template'),
      if (canEdit) item(_Action.options, Icons.tune_outlined, 'options'),
      if (t.isActive && canEdit)
        item(
          _Action.archive,
          Icons.archive_outlined,
          'archive',
          confirm: true,
          lifecycle: true,
        ),
      if (!t.isActive && canEdit)
        item(
          _Action.restore,
          Icons.restore_outlined,
          'restore',
          lifecycle: true,
        ),
      if (!t.isDeleted && _can('blueprints', DnAction.delete))
        item(
          _Action.delete,
          Icons.delete_outline,
          'delete',
          confirm: true,
          destructive: true,
          lifecycle: true,
        ),
    ];
  }

  Future<void> _onAction(
    DocuNinjaTemplatesViewModel vm,
    DnBlueprint t,
    _Action action,
  ) async {
    switch (action) {
      case _Action.use:
        await _use(t);
      case _Action.options:
        await _options(vm, t);
      case _Action.archive:
        await _bulk(vm, t, 'archive', 'archived_template');
      case _Action.restore:
        await _bulk(vm, t, 'restore', 'restored_template');
      case _Action.delete:
        await _bulk(vm, t, 'delete', 'deleted_template');
    }
  }

  Future<void> _guarded(Future<void> Function() run) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await run();
    } on Object catch (e, st) {
      _log.warning('DocuNinja template action failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulk(
    DocuNinjaTemplatesViewModel vm,
    DnBlueprint t,
    String action,
    String successKey,
  ) => _guarded(() async {
    try {
      await context.read<DocuNinjaApi>().blueprintBulk(action, [t.id]);
      if (!mounted) return;
      Notify.success(context, context.tr(successKey));
    } finally {
      // Whether or not it answered: a request that timed out may have
      // landed. Not a list a company switch has since replaced.
      if (mounted && identical(vm, _vm)) unawaited(vm.refresh());
    }
  });

  /// React's Use Template: a new document from the template, opened in the
  /// builder, which maps the template's signers to real ones.
  Future<void> _use(DnBlueprint t) => _guarded(() async {
    final companyId = _companyId;
    if (companyId == null) return;
    final vm = _vm;
    final id = await context.read<DocuNinjaApi>().makeDocument(t.id);
    // Gone, or a company switch replaced the list meanwhile: the new
    // document is the other company's, and would open under this one's
    // DocuNinja session as "not found". It is there when they go back.
    if (!mounted || !identical(vm, _vm)) return;
    if (id.isEmpty) throw StateError('make_document returned no id');
    _session?.markDocumentsChanged();
    context.go('/docuninja/$id');
    notifyAndOpenDocuNinjaBuilder(
      context,
      message: context.tr('document_created'),
      documentId: id,
      companyId: companyId,
      fromTemplate: true,
    );
  });

  void _edit(DnBlueprint t) {
    final companyId = _companyId;
    if (companyId == null) return;
    openDocuNinjaBuilder(
      context,
      documentId: t.id,
      companyId: companyId,
      template: true,
    );
  }

  Future<void> _options(DocuNinjaTemplatesViewModel vm, DnBlueprint t) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TemplateOptionsDialog(
        template: t,
        api: context.read<DocuNinjaApi>(),
      ),
    );
    if (saved != true || !mounted) return;
    Notify.success(context, context.tr('template_updated'));
    await vm.refresh();
  }

  Future<void> _create(DocuNinjaTemplatesViewModel vm) async {
    final api = context.read<DocuNinjaApi>();
    final loginApi = context.read<DocuNinjaLoginApi?>();
    final companyId = _companyId;
    if (loginApi == null || companyId == null) return;
    final id = await showDialog<String>(
      context: context,
      builder: (_) => _TemplateWizard(api: api, loginApi: loginApi),
    );
    if (id == null || !mounted) return;
    if (id.isEmpty) {
      Notify.error(context, context.tr('an_error_occurred_try_again'));
      return;
    }
    unawaited(vm.refresh());
    notifyAndOpenDocuNinjaBuilder(
      context,
      message: context.tr('template_created'),
      documentId: id,
      companyId: companyId,
      template: true,
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.onTap,
    required this.actions,
    this.onLongPress,
    this.selected = false,
    this.leading,
  });

  final DnBlueprint template;
  final VoidCallback? onTap;
  final List<EntityActionItem<_Action>> actions;
  final VoidCallback? onLongPress;
  final bool selected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final t = template;
    // React's type column: "<Entity> Design" for one made from an Invoice
    // Ninja design, else Custom.
    final type = !t.isInvoiceNinjaDesign
        ? context.tr('custom')
        : t.entityType.isEmpty
        ? context.tr('design')
        : '${context.tr(t.entityType)} ${context.tr('design')}';
    final (String key, Color fg, Color bg) = t.isDeleted
        ? ('deleted', tokens.overdue, tokens.overdueSoft)
        : t.isArchived
        ? ('archived', tokens.partial, tokens.partialSoft)
        : ('active', tokens.paid, tokens.paidSoft);
    return SelectableListRow(
      selected: selected,
      urlSelected: false,
      // The list's separators draw the lines.
      hideBottomDivider: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
          child: Row(
            children: [
              ?leading,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.name.isEmpty ? context.tr('untitled_template') : t.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        type,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.ink3, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: InSpacing.sm),
              StatusPill(
                label: context.tr(key),
                fgColor: fg,
                bgColor: bg,
                textStyle: TextStyle(fontSize: 13, color: tokens.ink),
              ),
              // Kept while selecting (empty), so the pills stay put.
              Visibility(
                visible: actions.isNotEmpty,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: EntityActionsPopupButton<_Action>(items: actions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// React's template Options (`EditBlueprintModal.tsx`): name and
/// description, saved in place, staying open on a refusal.
class _TemplateOptionsDialog extends StatefulWidget {
  const _TemplateOptionsDialog({required this.template, required this.api});

  final DnBlueprint template;
  final DocuNinjaApi api;

  @override
  State<_TemplateOptionsDialog> createState() => _TemplateOptionsDialogState();
}

class _TemplateOptionsDialogState extends State<_TemplateOptionsDialog> {
  late final _name = TextEditingController(text: widget.template.name);
  late final _description = TextEditingController(
    text: widget.template.description,
  );
  bool _saving = false;
  String? _nameError;
  String? _descriptionError;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _canSave => !_saving && _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _nameError = null;
      _descriptionError = null;
    });
    try {
      await widget.api.updateBlueprint(
        widget.template,
        name: _name.text.trim(),
        description: _description.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on DocuNinjaException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = e.fieldErrors['name']?.first;
        _descriptionError = e.fieldErrors['description']?.first;
      });
      if (_nameError == null && _descriptionError == null) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } on Object catch (e, st) {
      _log.warning('Saving the DocuNinja template failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(context.tr('edit_template')),
      content: SizedBox(
        width: 480,
        child: FormSaveScope(
          onSubmit: _save,
          enabled: _canSave,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.tr('name'),
                  errorText: _nameError,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: InSpacing.sm),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('description'),
                  errorText: _descriptionError,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('save'),
          autofocus: false,
          busy: _saving,
          enabled: _name.text.trim().isNotEmpty,
          showEnterHint: _name.text.trim().isNotEmpty,
          onPressed: _save,
        ),
      ],
    ),
  );
}

enum _WizardStep { choose, invoiceNinja, custom }

/// React's New Template wizard (`BlueprintWizard.tsx`): a template from an
/// Invoice Ninja design (one per document type not yet made, through
/// `/api/docuninja/stub_blueprint`), or one of the user's own (a name and a
/// description; the PDF is uploaded in the template builder). Returns the
/// new template's id.
class _TemplateWizard extends StatefulWidget {
  const _TemplateWizard({required this.api, required this.loginApi});

  final DocuNinjaApi api;
  final DocuNinjaLoginApi loginApi;

  @override
  State<_TemplateWizard> createState() => _TemplateWizardState();
}

class _TemplateWizardState extends State<_TemplateWizard> {
  /// React's order.
  static const _entities = ['invoice', 'quote', 'credit', 'purchase_order'];

  _WizardStep _step = _WizardStep.choose;
  final _name = TextEditingController();
  final _description = TextEditingController();
  List<String>? _available;
  bool _loadFailed = false;
  bool _loadOffline = false;

  /// Drops a read that a later one (Back, then in again) overtook.
  int _loadGeneration = 0;
  String? _entity;
  bool _saving = false;
  String? _nameError;
  String? _descriptionError;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  /// The document types that have no design template yet (React reads the
  /// first hundred active templates).
  Future<void> _loadAvailable() async {
    final generation = ++_loadGeneration;
    setState(() {
      _available = null;
      _loadFailed = false;
    });
    try {
      final page = await widget.api.blueprints(perPage: 100);
      final made = {for (final b in page.items) b.entityType};
      if (!mounted || generation != _loadGeneration) return;
      setState(
        () => _available = [
          for (final e in _entities)
            if (!made.contains(e)) e,
        ],
      );
    } on Object catch (e, st) {
      _log.warning('Reading DocuNinja templates failed', e, st);
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _loadFailed = true;
          _loadOffline = e is NetworkException;
        });
      }
    }
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _nameError = null;
      _descriptionError = null;
    });
    try {
      final String id;
      if (_step == _WizardStep.invoiceNinja) {
        final entity = _entity;
        if (entity == null) {
          setState(() => _saving = false);
          return;
        }
        id = await widget.loginApi.stubBlueprint(entity);
      } else {
        final b = await widget.api.createBlueprint(
          name: _name.text.trim(),
          description: _description.text.trim(),
        );
        id = b.id;
      }
      if (mounted) Navigator.of(context).pop(id);
    } on DocuNinjaException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = e.fieldErrors['name']?.first;
        _descriptionError = e.fieldErrors['description']?.first;
      });
      if (_nameError == null && _descriptionError == null) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } on Object catch (e, st) {
      _log.warning('Creating the DocuNinja template failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    Widget option(IconData icon, String title, String help, VoidCallback go) =>
        Card(
          margin: const EdgeInsets.only(bottom: InSpacing.sm),
          child: ListTile(
            leading: Icon(icon, color: tokens.accent),
            title: Text(title),
            subtitle: Text(help),
            onTap: go,
          ),
        );
    final Widget content;
    final List<Widget> actions;
    switch (_step) {
      case _WizardStep.choose:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('choose_template_type'),
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink2),
            ),
            SizedBox(height: InSpacing.md(context)),
            option(
              Icons.description_outlined,
              // React's literal tile title: the product's name.
              'Invoice Ninja',
              context.tr('invoice_ninja_template_description'),
              () {
                setState(() => _step = _WizardStep.invoiceNinja);
                _loadAvailable();
              },
            ),
            option(
              Icons.build_outlined,
              context.tr('create_your_own'),
              context.tr('create_your_own_description'),
              () => setState(() => _step = _WizardStep.custom),
            ),
          ],
        );
        actions = [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
        ];
      case _WizardStep.invoiceNinja:
        final available = _available;
        content = _loadFailed
            ? DocuNinjaInlineError(
                offline: _loadOffline,
                onRetry: _loadAvailable,
              )
            : available == null
            ? const Padding(
                padding: EdgeInsets.all(InSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            : available.isEmpty
            ? Text(context.tr('all_entity_types_created'))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('document_type_description'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.ink2,
                    ),
                  ),
                  const SizedBox(height: InSpacing.sm),
                  RadioGroup<String>(
                    groupValue: _entity,
                    onChanged: (v) {
                      if (!_saving) setState(() => _entity = v);
                    },
                    child: Column(
                      children: [
                        for (final e in available)
                          RadioListTile<String>(
                            value: e,
                            title: Text(context.tr(e)),
                          ),
                      ],
                    ),
                  ),
                ],
              );
        actions = [
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() => _step = _WizardStep.choose),
            child: Text(context.tr('back')),
          ),
          if (available != null && available.isNotEmpty)
            PrimaryDialogAction(
              label: context.tr(_saving ? 'creating' : 'create_template'),
              busy: _saving,
              enabled: _entity != null,
              showEnterHint: false,
              onPressed: _create,
            ),
        ];
      case _WizardStep.custom:
        content = FormSaveScope(
          onSubmit: _create,
          enabled: !_saving,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.tr('name'),
                  hintText: context.tr('template_name'),
                  errorText: _nameError,
                ),
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: InSpacing.sm),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('description'),
                  errorText: _descriptionError,
                ),
              ),
            ],
          ),
        );
        actions = [
          TextButton(
            onPressed: _saving
                ? null
                : () => setState(() => _step = _WizardStep.choose),
            child: Text(context.tr('back')),
          ),
          PrimaryDialogAction(
            label: context.tr('create_template'),
            autofocus: false,
            busy: _saving,
            onPressed: _create,
          ),
        ];
    }
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(context.tr('new_template')),
        content: SizedBox(width: 520, child: content),
        actions: actions,
      ),
    );
  }
}

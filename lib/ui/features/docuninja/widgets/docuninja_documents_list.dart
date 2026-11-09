import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/utils/fab_clearance.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_bulk.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_inline_error.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_status_pill.dart';
import 'package:admin/utils/bidi.dart';
import 'package:admin/utils/formatting.dart';

/// The pane width from which the list is React's table.
const double kDocuNinjaTableMinWidth = 720;

/// Whether the documents page lays out as React's table and wide toolbar in
/// a pane [width] wide: from [kDocuNinjaTableMinWidth], and never on a phone
/// ([Breakpoints.isPhone]) — a landscape phone's pane is that wide, on a
/// viewport too short for the table's chrome (CLAUDE.md: a landscape phone
/// is not a small desktop).
bool dnShowsTable(BuildContext context, double width) =>
    width >= kDocuNinjaTableMinWidth && !Breakpoints.isPhone(context);

/// React's documents table (`useTableColumns.tsx`: contact, user, document,
/// files, status, created at) on a wide pane, and a row per document on a
/// narrow one. A page at a time; the next loads near the end.
class DocuNinjaDocumentsList extends StatefulWidget {
  const DocuNinjaDocumentsList({
    super.key,
    required this.vm,
    required this.onOpen,
    this.actionsFor,
    this.selectable = false,
    this.header,
    this.headerOnlyWhenEmpty = false,
    this.onClearFilters,
    this.onCreate,
    this.fabClearance = false,
  });

  final DocuNinjaDocumentsViewModel vm;
  final ValueChanged<DnDocument> onOpen;

  /// Rows can be ticked for the bulk actions (React's table checkboxes):
  /// a checkbox slot on the wide table (shown on hover), a long press
  /// anywhere, and a tap ticks once selecting.
  final bool selectable;

  /// A row's `⋮` menu (React's row actions), or none.
  final Widget Function(DnDocument doc)? actionsFor;

  /// Scrolls above the rows (React's drop zone), on an empty list too.
  final Widget? header;

  /// Shows [header] only over an empty list: a phone, whose create is the
  /// `+` button, keeps the Camera / Photos / Files tiles for the empty
  /// page and gives the rows the room otherwise.
  final bool headerOnlyWhenEmpty;

  /// The empty page's way to a first document (the New Document dialog),
  /// for a role that may create; none otherwise.
  final VoidCallback? onCreate;

  /// A floating `+` sits over the list's bottom edge: the last row scrolls
  /// clear of it ([fabScrollClearance]).
  final bool fabClearance;

  /// Clears the search and the filters, offered when they leave the list
  /// empty — never a dead end (the app's lists' Clear filters).
  final VoidCallback? onClearFilters;

  @override
  State<DocuNinjaDocumentsList> createState() => _DocuNinjaDocumentsListState();
}

class _DocuNinjaDocumentsListState extends State<DocuNinjaDocumentsList> {
  final _scroll = ScrollController();
  Formatter? _formatter;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      services.formatterFor(companyId).then((f) {
        if (mounted) setState(() => _formatter = f);
      });
    }
  }

  void _onScroll() {
    final vm = widget.vm;
    if (!_scroll.hasClients ||
        !vm.hasMore ||
        vm.isLoading ||
        vm.isLoadingMore ||
        vm.error != null) {
      return;
    }
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 400) vm.loadMore();
  }

  /// A page that does not fill the pane never scrolls, so the scroll
  /// listener alone would never ask for the next one: check after each
  /// layout too. A failed page stops this (the error guard) until Retry.
  void _checkAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _date(String iso) => dnLocalDate(_formatter, iso);

  bool _showError(DocuNinjaDocumentsViewModel vm) =>
      vm.error != null && vm.items.isNotEmpty && !vm.isLoading;

  Widget _errorNotice(DocuNinjaDocumentsViewModel vm) => DocuNinjaInlineError(
    offline: vm.error == DnListError.offline,
    onRetry: vm.retry,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.vm,
    builder: (context, _) {
      final vm = widget.vm;
      // Offline is the page's answer; anything else is answered where the
      // rows go, as React's table does, under the drop zone and header.
      if (vm.items.isEmpty && vm.error == DnListError.offline) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: context.tr('offline'),
          action: TextButton(
            onPressed: vm.refresh,
            child: Text(context.tr('retry')),
          ),
        );
      }
      _checkAfterLayout();
      return LayoutBuilder(
        builder: (context, c) {
          final table = dnShowsTable(context, c.maxWidth);
          final inset = dnListInset(table: table);
          final header =
              widget.header == null ||
                  (widget.headerOnlyWhenEmpty &&
                      !(vm.hasLoaded && vm.items.isEmpty))
              ? null
              : widget.header;
          // The Scaffold leaves the home indicator in the body's padding,
          // and a CustomScrollView does not pay it: the last row would end
          // under it. With the `+` up, its clearance includes that inset.
          final bottomInset = widget.fabClearance
              ? fabScrollClearance(context)
              : MediaQuery.paddingOf(context).bottom;
          final emptyPage = !table && _emptyPage(vm);
          Widget padded(Widget child) => SliverPadding(
            padding: EdgeInsetsDirectional.only(
              start: inset,
              end: inset,
              bottom: InSpacing.lg(context),
            ),
            sliver: SliverToBoxAdapter(child: child),
          );
          return RefreshIndicator(
            onRefresh: vm.refresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // React's page scrolls as one: the drop zone, then the
                // table under it.
                if (header != null) padded(header),
                // A failed refresh says so where the pull happened; a failed
                // next page says so under the rows.
                if (_showError(vm) && !vm.errorFromMore)
                  padded(_errorNotice(vm)),
                if (emptyPage)
                  _emptyPageSliver(context, bottomInset)
                else if (table)
                  SliverPadding(
                    padding: EdgeInsetsDirectional.only(
                      start: inset,
                      end: inset,
                      bottom: InSpacing.lg(context),
                    ),
                    sliver: _tableCard(context, vm),
                  )
                else
                  ..._narrowSlivers(context, vm),
                // React's "Total results" under the table.
                if (vm.items.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsetsDirectional.only(
                      start: inset,
                      end: inset,
                      top: table ? 0 : InSpacing.lg(context),
                      bottom: InSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '${context.tr('total_results')}: ${vm.total}',
                        style: TextStyle(
                          color: context.inTheme.ink3,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                if (!emptyPage && bottomInset > 0)
                  SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
              ],
            ),
          );
        },
      );
    },
  );

  /// Nothing to show and nothing narrowing the list: no documents yet.
  bool _emptyPage(DocuNinjaDocumentsViewModel vm) =>
      vm.hasLoaded &&
      !vm.isLoading &&
      !vm.isRequerying &&
      vm.error == null &&
      vm.items.isEmpty &&
      !_filtered(vm);

  /// A narrow list's first-run page: what the page is for, and the way to a
  /// first document, in the room under the header. A filtered or searched
  /// empty result keeps React's slim line (with Clear filters), and so does
  /// the wide table.
  Widget _emptyPageSliver(BuildContext context, double bottomInset) =>
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsetsDirectional.only(bottom: bottomInset),
          child: EmptyState(
            icon: Icons.draw_outlined,
            title: context.tr('docuninja_empty_upload'),
            action: widget.onCreate == null
                ? null
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('new_document')),
                    onPressed: widget.onCreate,
                  ),
          ),
        ),
      );

  /// The rows, or React's empty-table line, the next-page error and spinner.
  List<Widget> _rowSlivers(
    BuildContext context,
    DocuNinjaDocumentsViewModel vm, {
    required bool table,
  }) => [
    // A new search or filter is on its way: the rows below are the last
    // one's.
    if (vm.isRequerying)
      const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
    if (!vm.hasLoaded && vm.isLoading)
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      )
    else if (vm.items.isEmpty && vm.error != null)
      SliverToBoxAdapter(
        child: _NoRecords(
          boxed: table,
          messageKey: 'an_error_occurred_try_again',
          actionKey: 'retry',
          onAction: vm.refresh,
        ),
      )
    else if (vm.items.isEmpty && !vm.isRequerying)
      SliverToBoxAdapter(
        child: _NoRecords(
          boxed: table,
          actionKey: 'clear_filters',
          onAction: _filtered(vm) ? widget.onClearFilters : null,
        ),
      )
    else
      SliverList.separated(
        itemCount: vm.items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final doc = vm.items[i];
          final row = _rowParts(vm, doc, table: table);
          final created = _date(_createdAt(doc));
          // Each row hosts its own ink: the card's fill paints over the
          // Scaffold's, so a hover drawn there would be hidden.
          return Material(
            type: MaterialType.transparency,
            child: table
                ? _TableRow(doc: doc, created: created, parts: row)
                : _NarrowRow(doc: doc, created: created, parts: row),
          );
        },
      ),
    if (_showError(vm) && vm.errorFromMore)
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: InSpacing.sm,
        ),
        sliver: SliverToBoxAdapter(child: _errorNotice(vm)),
      ),
    if (vm.isLoadingMore)
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(InSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
  ];

  /// React's table on a wide pane: the column header and the rows in one
  /// bordered card, sized to its rows, as the app's own wide lists draw it.
  Widget _tableCard(BuildContext context, DocuNinjaDocumentsViewModel vm) {
    final tokens = context.inTheme;
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        boxShadow: tokens.shadow1,
      ),
      sliver: DecoratedSliver(
        // The border over the rows: the header strip and a selected
        // row fill to the edge and would otherwise cover it.
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r3),
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _TableHeader(
                leading: widget.selectable ? _selectAll(vm) : null,
                // Room for the rows' `⋮`, so the columns line up.
                trailingWidth: widget.actionsFor == null
                    ? 0
                    : actionButtonSize(),
              ),
            ),
            ..._rowSlivers(context, vm, table: true),
          ],
        ),
      ),
    );
  }

  /// The search or a filter is narrowing the list.
  bool _filtered(DocuNinjaDocumentsViewModel vm) =>
      vm.search.trim().isNotEmpty || vm.activeFilterCount > 0;

  /// React's header checkbox: ticks every loaded row, or clears them all.
  /// Shown on hover, and always while selecting, as the app's lists do.
  Widget _selectAll(DocuNinjaDocumentsViewModel vm) {
    final all = vm.items.isNotEmpty && vm.countSelected == vm.items.length;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: InSpacing.sm),
      child: LeadingSelectSlot(
        selecting: vm.isSelecting,
        selected: all,
        onSelectTap: vm.items.isEmpty
            ? null
            : () => all ? vm.clearSelection() : vm.selectAllVisible(),
        defaultChild: const SizedBox.shrink(),
      ),
    );
  }

  /// A row per document, edge to edge, as the app's narrow lists are.
  List<Widget> _narrowSlivers(
    BuildContext context,
    DocuNinjaDocumentsViewModel vm,
  ) => [
    const SliverToBoxAdapter(child: Divider(height: 1)),
    ..._rowSlivers(context, vm, table: false),
  ];
}

/// The side inset of everything on the documents page — the search row, the
/// drop zone and the table — so their edges line up: the app's wide lists'
/// 24 on a table, 16 for narrow rows.
double dnListInset({required bool table}) => table ? 24 : 16;

/// React's empty table: one muted line where the rows would be
/// (`DataTable.tsx`, `no_records_found`), not a page-high empty state.
class _NoRecords extends StatelessWidget {
  const _NoRecords({
    required this.boxed,
    this.messageKey = 'no_records_found',
    this.actionKey,
    this.onAction,
  });

  /// Inside the table card; a narrow list draws its divider under it.
  final bool boxed;
  final String messageKey;
  final String? actionKey;

  /// Offered under the line when set (Retry, Clear filters).
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(messageKey),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.inTheme.ink3, fontSize: 14),
            ),
            if (onAction != null && actionKey != null) ...[
              const SizedBox(height: InSpacing.sm),
              TextButton(
                onPressed: onAction,
                child: Text(context.tr(actionKey!)),
              ),
            ],
          ],
        ),
      ),
      if (!boxed) const Divider(height: 1),
    ],
  );
}

/// What a row needs from the list: its taps, its selection state and the
/// slots either side of its content.
typedef _RowParts = ({
  VoidCallback onTap,
  VoidCallback? onLongPress,
  bool selected,
  Widget? leading,
  Widget? actions,
});

extension on _DocuNinjaDocumentsListState {
  _RowParts _rowParts(
    DocuNinjaDocumentsViewModel vm,
    DnDocument doc, {
    required bool table,
  }) {
    final open = widget.onOpen;
    final actions = widget.actionsFor?.call(doc);
    if (!widget.selectable) {
      return (
        onTap: () => open(doc),
        onLongPress: null,
        selected: false,
        leading: null,
        actions: actions,
      );
    }
    final selecting = vm.isSelecting;
    void toggle() => vm.toggleSelected(doc);
    return (
      // Selecting, a tap ticks the row instead of opening it.
      onTap: selecting ? toggle : () => open(doc),
      onLongPress: toggle,
      selected: vm.isSelected(doc),
      // The table keeps the slot (its checkbox shows on hover); a narrow row
      // shows it only while selecting, where it is the checkbox.
      leading: dnSelectLeading(
        wide: table,
        selecting: selecting,
        selected: vm.isSelected(doc),
        onToggle: toggle,
      ),
      // No row menu while selecting: the bulk actions are the menu. The
      // table keeps the room, so its columns stay put.
      actions: selecting && actions != null
          ? (table ? SizedBox(width: actionButtonSize()) : null)
          : actions,
    );
  }
}

/// A DocuNinja timestamp (`2026-02-22T21:14:25.000000Z`, UTC) as the company
/// writes dates, on the user's own calendar day.
String dnLocalDate(Formatter? f, String? iso) {
  final at = dnParseUtc(iso)?.toLocal();
  if (f == null || at == null) return '';
  return f.date(Date(at.year, at.month, at.day).toIso());
}

/// A DocuNinja timestamp as the instant it names. DocuNinja writes UTC in
/// two shapes: `2026-02-22T21:14:25.000000Z` and, on invitations,
/// `2026-02-22 21:17:30` with no offset — which `DateTime.parse` would take
/// as local time, putting a Tokyo user's "Sent" on the day before. A bare
/// date stays a date.
DateTime? dnParseUtc(String? value) {
  final v = (value ?? '').trim();
  if (v.length <= 10) return DateTime.tryParse(v);
  final hasOffset = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(v);
  return DateTime.tryParse(hasOffset ? v : '${v.replaceFirst(' ', 'T')}Z');
}

/// React dates a document by its first file (`created_at` column).
String _createdAt(DnDocument doc) {
  final file = doc.files.isEmpty ? null : doc.files.first.raw['created_at'];
  return file is String && file.isNotEmpty ? file : doc.createdAt;
}

String _title(BuildContext context, DnDocument doc) =>
    doc.description.isEmpty ? context.tr('untitled_document') : doc.description;

/// React's contact column: the first contact invitation's name, or email.
String _contactName(DnDocument doc) {
  for (final i in doc.invitations) {
    final c = i.contact;
    if (c != null && i.clientContactId.isNotEmpty) {
      return c.name.isNotEmpty ? c.name : c.email;
    }
  }
  return '';
}

/// React's user column: the first user invitation's name, or email.
String _userName(DnDocument doc) {
  for (final i in doc.invitations) {
    final u = i.user;
    if (u != null && i.userId.isNotEmpty) {
      return u.name.isNotEmpty ? u.name : u.email;
    }
  }
  return '';
}

/// React's files column: the page count across the document's files, in a
/// green chip (`useTableColumns.tsx`); nothing when there are no files.
int _pageCount(DnDocument doc) =>
    doc.files.fold<int>(0, (n, f) => n + f.pageCount);

class _PagesChip extends StatelessWidget {
  const _PagesChip({required this.doc});

  final DnDocument doc;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (doc.files.isEmpty) {
      return Text('—', style: TextStyle(color: tokens.ink2));
    }
    final pages = _pageCount(doc);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.paidSoft,
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        // Holds a translated word, so it keeps the reading direction.
        child: Text(
          '$pages ${context.tr(pages == 1 ? 'page' : 'pages')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.paid,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

const _flex = [3, 3, 4, 2, 2, 2];

class _TableHeader extends StatelessWidget {
  const _TableHeader({this.trailingWidth = 0, this.leading});

  final double trailingWidth;

  /// The select-all checkbox, in the rows' checkbox slot.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // The app's wide-list header strip (`EntityListColumnHeaders`).
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: tokens.ink3,
    );
    final labels = [
      'contact',
      'user',
      'document',
      'files',
      'status',
      'created_at',
    ];
    // A fill and a divider, not a bottom border: a radius needs a uniform
    // border. Inside the card's border, so a hair under its radius.
    final strip = Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(InRadii.r3 - 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ?leading,
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(
                context.tr(labels[i]).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          if (trailingWidth > 0) SizedBox(width: trailingWidth),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [strip, const Divider(height: 1)],
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.doc,
    required this.created,
    required this.parts,
  });

  final DnDocument doc;
  final String created;
  final _RowParts parts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    Widget cell(int i, Widget child) => Expanded(flex: _flex[i], child: child);
    // A labelled slot: an empty value is an em dash, as React's table shows.
    Widget name(String s) => LtrText(
      s.isEmpty ? '—' : s,
      keepRtlScript: true,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: tokens.ink),
    );
    // A date or a count reads left-to-right in every language.
    Widget value(String s, {Color? color}) => LtrText(
      s.isEmpty ? '—' : s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color ?? tokens.ink),
    );
    return SelectableListRow(
      selected: parts.selected,
      urlSelected: false,
      // The list's separators draw the lines.
      hideBottomDivider: true,
      onTap: parts.onTap,
      onLongPress: parts.onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ?parts.leading,
              // A name, or an email when there is none: left-to-right
              // unless it is Arabic or Hebrew script.
              cell(0, name(_contactName(doc))),
              cell(1, name(_userName(doc))),
              cell(
                2,
                Text(
                  _title(context, doc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Holds a translated word, so it keeps the reading direction.
              cell(3, _PagesChip(doc: doc)),
              cell(
                4,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DocuNinjaStatusPill(document: doc),
                ),
              ),
              cell(5, value(created, color: tokens.ink2)),
              ?parts.actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _NarrowRow extends StatelessWidget {
  const _NarrowRow({
    required this.doc,
    required this.created,
    required this.parts,
  });

  final DnDocument doc;
  final String created;
  final _RowParts parts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final who = _contactName(doc).isNotEmpty
        ? _contactName(doc)
        : _userName(doc);
    final subtitle = [
      who,
      if (created.isNotEmpty) ltrIsolate(created),
    ].where((s) => s.isNotEmpty).join(' · ');
    return SelectableListRow(
      selected: parts.selected,
      urlSelected: false,
      hideBottomDivider: true,
      onTap: parts.onTap,
      onLongPress: parts.onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ?parts.leading,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(context, doc),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.ink3, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: InSpacing.sm),
              // Capped, so a long translated status at a large text size
              // ellipsizes inside the pill instead of squeezing the title.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: DocuNinjaStatusPill(document: doc),
              ),
              ?parts.actions,
            ],
          ),
        ),
      ),
    );
  }
}

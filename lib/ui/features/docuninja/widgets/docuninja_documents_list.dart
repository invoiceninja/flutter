import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_documents_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_inline_error.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_status_pill.dart';
import 'package:admin/utils/bidi.dart';
import 'package:admin/utils/formatting.dart';

/// The pane width from which the list is React's table.
const double kDocuNinjaTableMinWidth = 720;

/// React's documents table (`useTableColumns.tsx`: contact, user, document,
/// files, status, created at) on a wide pane, and a row per document on a
/// narrow one. A page at a time; the next loads near the end.
class DocuNinjaDocumentsList extends StatefulWidget {
  const DocuNinjaDocumentsList({
    super.key,
    required this.vm,
    required this.onOpen,
    this.actionsFor,
  });

  final DocuNinjaDocumentsViewModel vm;
  final ValueChanged<DnDocument> onOpen;

  /// A row's `⋮` menu (React's row actions), or none.
  final Widget Function(DnDocument doc)? actionsFor;

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

  Widget _errorNotice(DocuNinjaDocumentsViewModel vm) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: DocuNinjaInlineError(
      offline: vm.error == DnListError.offline,
      onRetry: vm.retry,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.vm,
    builder: (context, _) {
      final vm = widget.vm;
      if (!vm.hasLoaded && vm.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (vm.items.isEmpty && vm.error != null) {
        return vm.error == DnListError.offline
            ? EmptyState(
                icon: Icons.cloud_off_outlined,
                title: context.tr('offline'),
                action: TextButton(
                  onPressed: vm.refresh,
                  child: Text(context.tr('retry')),
                ),
              )
            : ErrorView(
                message: context.tr('an_error_occurred_try_again'),
                onRetry: vm.refresh,
              );
      }
      _checkAfterLayout();
      return LayoutBuilder(
        builder: (context, c) {
          final table = c.maxWidth >= kDocuNinjaTableMinWidth;
          return RefreshIndicator(
            onRefresh: vm.refresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // A failed refresh says so where the pull happened; a failed
                // next page says so under the rows.
                if (_showError(vm) && !vm.errorFromMore)
                  SliverToBoxAdapter(child: _errorNotice(vm)),
                if (table)
                  SliverToBoxAdapter(
                    child: _TableHeader(
                      // Room for the rows' `⋮`, so the columns line up.
                      trailingWidth: widget.actionsFor == null
                          ? 0
                          : actionButtonSize(),
                    ),
                  ),
                if (vm.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.draw_outlined,
                      title: context.tr('no_records_found'),
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: vm.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final doc = vm.items[i];
                      return table
                          ? _TableRow(
                              doc: doc,
                              created: _date(_createdAt(doc)),
                              onTap: () => widget.onOpen(doc),
                              actions: widget.actionsFor?.call(doc),
                            )
                          : _NarrowRow(
                              doc: doc,
                              created: _date(_createdAt(doc)),
                              onTap: () => widget.onOpen(doc),
                              actions: widget.actionsFor?.call(doc),
                            );
                    },
                  ),
                if (_showError(vm) && vm.errorFromMore)
                  SliverToBoxAdapter(child: _errorNotice(vm)),
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
        },
      );
    },
  );
}

/// A DocuNinja timestamp (`2026-02-22T21:14:25.000000Z`, UTC) as the company
/// writes dates, on the user's own calendar day.
String dnLocalDate(Formatter? f, String? iso) {
  final at = DateTime.tryParse(iso ?? '')?.toLocal();
  if (f == null || at == null) return '';
  return f.date(Date(at.year, at.month, at.day).toIso());
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

String _files(BuildContext context, DnDocument doc) {
  final pages = doc.files.fold<int>(0, (n, f) => n + f.pageCount);
  if (doc.files.isEmpty) return '';
  return '${doc.files.length} · $pages ${context.tr(pages == 1 ? 'page' : 'pages')}';
}

const _flex = [3, 3, 4, 2, 2, 2];

class _TableHeader extends StatelessWidget {
  const _TableHeader({this.trailingWidth = 0});

  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: context.inTheme.ink2,
      fontWeight: FontWeight.w600,
    );
    final labels = [
      'contact',
      'user',
      'document',
      'files',
      'status',
      'created_at',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(context.tr(labels[i]), style: style),
            ),
          if (trailingWidth > 0) SizedBox(width: trailingWidth),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.doc,
    required this.created,
    required this.onTap,
    this.actions,
  });

  final DnDocument doc;
  final String created;
  final VoidCallback onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    Widget cell(int i, Widget child) => Expanded(flex: _flex[i], child: child);
    // A labelled slot: an empty value is an em dash, as React's table shows.
    Text text(String s, {Color? color}) => Text(
      s.isEmpty ? '—' : s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color ?? tokens.ink),
    );
    // A date or a count reads left-to-right in every language.
    Widget value(String s, {Color? color}) => LtrText(
      s.isEmpty ? '—' : s,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color ?? tokens.ink),
    );
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              cell(0, text(_contactName(doc))),
              cell(1, text(_userName(doc))),
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
              cell(3, text(_files(context, doc), color: tokens.ink2)),
              cell(
                4,
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DocuNinjaStatusPill(document: doc),
                ),
              ),
              cell(5, value(created, color: tokens.ink2)),
              ?actions,
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
    required this.onTap,
    this.actions,
  });

  final DnDocument doc;
  final String created;
  final VoidCallback onTap;
  final Widget? actions;

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
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
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
              // Shrinks (and ellipsizes) before the title would: a long
              // translated status at a large text size.
              Flexible(child: DocuNinjaStatusPill(document: doc)),
              ?actions,
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Resolves the project name from the local Drift cache and renders it
/// as a `Text` (or a link when [link]). Falls back to the raw
/// `projectId` while the watch is empty; on a cache miss it triggers a
/// lazy per-id hydrate (`ProjectRepository.ensureLoaded`) so the name
/// resolves even when the project isn't on the prefetched first page.
///
/// Drift dedupes identical watch queries (and the repo dedupes the
/// hydrate fetch), so N rows for the same project share one
/// subscription and one network call.
class ProjectNameLabel extends StatefulWidget {
  const ProjectNameLabel({
    super.key,
    required this.projectId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.link = false,
  });

  final String projectId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  /// When true the resolved name renders as a hover-underlined link to
  /// the project's full-screen view. Off by default.
  final bool link;

  @override
  State<ProjectNameLabel> createState() => _ProjectNameLabelState();
}

class _ProjectNameLabelState extends State<ProjectNameLabel> {
  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(ProjectNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) _ensure();
  }

  /// Lazily hydrate the referenced project into Drift if it isn't cached
  /// (paginated lists prefetch only page 1). No-op / deduped / negative-
  /// cached in the repo, so it's safe to fire unconditionally here.
  void _ensure() {
    final id = widget.projectId;
    if (id.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    services.projects.ensureLoaded(companyId: companyId, id: id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (widget.projectId.isEmpty) {
      return Text(
        '—',
        style: widget.style ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, widget.projectId);
    }
    return StreamBuilder<Project?>(
      initialData: services.projects.peek(
        companyId: companyId,
        id: widget.projectId,
      ),
      stream: services.projects.watch(
        companyId: companyId,
        id: widget.projectId,
      ),
      builder: (context, snapshot) {
        final project = snapshot.data;
        final name = project == null || project.name.isEmpty
            ? widget.projectId
            : project.name;
        return _text(context, name);
      },
    );
  }

  Widget _text(BuildContext context, String text) => linkOrText(
    link: widget.link,
    label: text,
    onTap: widget.link
        ? () => goEntityFullDetail(context, '/projects', widget.projectId)
        : null,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
  );
}

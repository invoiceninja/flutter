import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/utils/formatting.dart';

/// Value object holding every field [EntityDetailHeader] needs.
///
/// Per-entity wrappers build one of these from their domain model and hand
/// it to [EntityDetailHeaderHost] — the host then renders the underlying
/// [EntityDetailHeader] without any per-entity glue.
class EntityHeaderFields {
  const EntityHeaderFields({
    required this.seedForAvatar,
    required this.displayName,
    this.number,
    this.numberWidget,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.isDeleted,
    required this.isDirty,
    this.subtitle,
    this.tags,
    this.nameMaxLines = 1,
    this.showStatePills = true,
  });

  /// See the same-named fields on [EntityDetailHeader].
  final Widget? subtitle;
  final Widget? tags;
  final int nameMaxLines;
  final bool showStatePills;

  final String seedForAvatar;
  final String displayName;
  final String? number;

  /// Optional widget for the secondary header slot (resolved reference,
  /// e.g. a client name). Wins over [number] when non-null.
  final Widget? numberWidget;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final bool isDeleted;
  final bool isDirty;
}

/// Generic projection-based wrapper over [EntityDetailHeader]. Per-entity
/// header widgets shrink to a one-liner that supplies the entity + a
/// `project: (T) => EntityHeaderFields` function — the only genuinely
/// entity-specific part is the display-name cascade inside the projection.
class EntityDetailHeaderHost<T> extends StatelessWidget {
  const EntityDetailHeaderHost({
    super.key,
    required this.entity,
    required this.entityType,
    required this.recordId,
    required this.project,
    this.formatter,
  });

  final T entity;

  /// Identity of the rendered entity — feeds the command palette's "Recent"
  /// group via [RecentVisitRecorder]. Every per-entity wrapper already knows
  /// both (it's projecting a typed domain model), so this is a one-liner at
  /// each call site.
  final EntityType entityType;
  final String recordId;

  final EntityHeaderFields Function(BuildContext context, T entity) project;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final f = project(context, entity);
    // `f.displayName` is already the meaningful identity for every entity
    // (client/vendor/project name, payment/expense `#number`, task
    // description, product key). `f.number` is an overloaded subtitle slot
    // (sometimes a vendor id), so it's deliberately not folded in here.
    //
    // The entity-type icon backstops number-only identities (`#0009`), whose
    // display name yields no initials and would otherwise show a bare `?`.
    final fallbackIcon = context
        .read<Services>()
        .entityRegistry[entityType]
        ?.icon;
    return RecentVisitRecorder(
      type: entityType,
      id: recordId,
      label: f.displayName,
      child: EntityDetailHeader(
        seedForAvatar: f.seedForAvatar,
        displayName: f.displayName,
        number: f.number,
        numberWidget: f.numberWidget,
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
        isDeleted: f.isDeleted,
        isArchived: f.isArchived,
        isDirty: f.isDirty,
        formatter: formatter,
        fallbackIcon: fallbackIcon,
        subtitle: f.subtitle,
        tags: f.tags,
        nameMaxLines: f.nameMaxLines,
        showStatePills: f.showStatePills,
      ),
    );
  }
}

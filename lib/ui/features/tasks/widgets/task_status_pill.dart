import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/ui/core/utils/task_status_colors.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// Compact "● Status name" badge — color dot + status name on a tinted
/// rounded-rect background. Colors come from [taskStatusColors]: a
/// per-company hex tinted at 15 % alpha, or — for a status the server left
/// colorless — the invoice/quote status token pair for that built-in.
///
/// Subscribes to `services.taskStatuses.watch(companyId, statusId)`.
/// Drift watch streams dedupe identical queries internally, so N rows
/// each showing a pill for the same status share one underlying query.
class TaskStatusPill extends StatelessWidget {
  const TaskStatusPill({
    super.key,
    required this.statusId,
    this.dotSize = 8,
    this.textStyle,
  });

  final String statusId;
  final double dotSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (statusId.isEmpty) {
      return Text(
        '—',
        style: textStyle ?? TextStyle(fontSize: 13, color: tokens.ink3),
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _label(context, status: null, tokens: tokens);
    }
    return StreamBuilder<TaskStatus?>(
      stream: services.taskStatuses.watch(companyId: companyId, id: statusId),
      builder: (context, snapshot) =>
          _label(context, status: snapshot.data, tokens: tokens),
    );
  }

  Widget _label(
    BuildContext context, {
    required TaskStatus? status,
    required InTheme tokens,
  }) {
    final colors = taskStatusColors(
      context,
      name: status?.name ?? '',
      color: status?.color ?? '',
    );
    final name = status == null || status.name.isEmpty ? statusId : status.name;
    return StatusPill(
      label: name,
      fgColor: colors.fg,
      // Null bg (custom hex / unrecognized status) → the core widget derives
      // the soft tone at 15 % alpha.
      bgColor: colors.bg,
      dotSize: dotSize,
      textStyle: textStyle ?? TextStyle(fontSize: 13, color: tokens.ink),
    );
  }
}

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';

/// What an invoice already carries, so the "Add to invoice" paths don't
/// duplicate it.
///
/// Two distinct hazards, both invisible until the customer reads the PDF:
///
///  * **Duplicate lines.** Re-running "Add to invoice" for the same project
///    (or picking a task that's already on the target) bills it twice. The
///    Add-items picker guards this with `excludedTaskIds` / `excludedExpenseIds`;
///    the direct append actions need the same sets.
///  * **Duplicate project headers.** A project's name is written into the
///    notes of the *first* of its lines. Append more of that project's tasks
///    later and a second header lands mid-document. [projectIds] names the
///    projects the target already shows, so those are skipped.
class InvoiceAppendContext {
  const InvoiceAppendContext({
    required this.taskIds,
    required this.expenseIds,
    required this.projectIds,
  });

  /// Nothing on the target yet — the "new invoice" paths.
  static const empty = InvoiceAppendContext(
    taskIds: <String>{},
    expenseIds: <String>{},
    projectIds: <String>{},
  );

  final Set<String> taskIds;
  final Set<String> expenseIds;

  /// Projects with at least one task line already on the invoice. Resolved
  /// through the tasks, because a line item has no `project_id` of its own —
  /// that absence is the whole reason the header convention exists.
  final Set<String> projectIds;

  static Future<InvoiceAppendContext> of(
    Services services,
    String companyId,
    Invoice target,
  ) async {
    final taskIds = <String>{
      for (final li in target.lineItems)
        if ((li.taskId ?? '').isNotEmpty) li.taskId!,
    };
    final expenseIds = <String>{
      for (final li in target.lineItems)
        if ((li.expenseId ?? '').isNotEmpty) li.expenseId!,
    };
    // One batch query. Tasks the local cache doesn't hold just don't
    // contribute a project id — worst case a header repeats, which is what
    // the app did before this existed.
    final tasks = await services.tasks.getByIds(
      companyId: companyId,
      ids: taskIds,
    );
    return InvoiceAppendContext(
      taskIds: taskIds,
      expenseIds: expenseIds,
      projectIds: {
        for (final t in tasks)
          if (t.projectId.isNotEmpty) t.projectId,
      },
    );
  }
}

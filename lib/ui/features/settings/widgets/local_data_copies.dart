import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/db/database_opener.dart';
import 'package:admin/data/db/salvage.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/formatting.dart';

/// Search keys, co-located with the widget that renders them — spread into
/// `kDeviceSettingsSearchKeys`.
const kLocalDataCopiesSearchKeys = <String>['local_data_copies'];

/// The old copies of this device's database that a reset kept, each with its
/// age, its size and a Delete (Device Settings → Data).
///
/// A reset moves the store aside rather than deleting it, and an
/// `.unrecovered` copy — one that could not be read, or not all of it — is
/// never pruned: it is kept in case support can recover the unsynced work in
/// it. This is
/// the only place that copy can be deleted, and the place the post-boot
/// notice sends the user to.
///
/// Renders nothing until there is a copy to list — which is always, on web.
/// It sits inside the Data section's last child rather than being a child of
/// its own, so an empty list costs the card no gap.
class LocalDataCopies extends StatefulWidget {
  const LocalDataCopies({
    super.key,
    this.list = listRetainedStores,
    this.delete = deleteRetainedStore,
    this.now = DateTime.now,
  });

  /// Injectable for tests; the platform seam by default.
  final Future<List<RetainedStore>> Function() list;
  final Future<void> Function(String path) delete;
  final DateTime Function() now;

  @override
  State<LocalDataCopies> createState() => _LocalDataCopiesState();
}

class _LocalDataCopiesState extends State<LocalDataCopies> {
  List<RetainedStore> _copies = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final copies = await widget.list();
      if (mounted) setState(() => _copies = copies);
    } catch (_) {
      // Nothing to offer is the honest fallback: the copies stay on disk.
    }
  }

  /// Always asks — a deleted copy is gone for good.
  Future<void> _delete(RetainedStore copy) async {
    final ok = await showConfirmActionDialog(
      context,
      title: context.tr('delete'),
      message: context.tr('local_data_copy_delete_body'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.delete(copy.path);
    } catch (_) {
      if (mounted) Notify.error(context, context.tr('an_error_occurred'));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_copies.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: InSpacing.lg(context)),
        const Divider(height: 1),
        SizedBox(height: InSpacing.lg(context)),
        Text(
          context.tr('local_data_copies'),
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: InSpacing.xs),
        Text(
          context.tr('local_data_copies_help'),
          style: text.bodyMedium?.copyWith(color: tokens.ink2),
        ),
        for (final copy in _copies)
          Padding(
            padding: EdgeInsets.only(top: InSpacing.md(context)),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 20, color: tokens.ink3),
                SizedBox(width: InSpacing.md(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('local_data_copy_kept', {
                          'time': formatRelativeTime(
                            context,
                            widget.now().difference(copy.keptAt),
                          ),
                          'size': formatByteSize(copy.bytes),
                        }),
                      ),
                      if (copy.unrecovered)
                        Text(
                          context.tr('local_data_copy_not_recovered'),
                          style: text.bodySmall?.copyWith(color: tokens.ink3),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _delete(copy),
                  child: Text(context.tr('delete')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

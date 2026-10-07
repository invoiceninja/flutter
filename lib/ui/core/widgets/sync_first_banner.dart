import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// Persistent strip shown on a detail/edit screen whose record is still an
/// offline-created `tmp_` placeholder. Replaces the repeated per-action "sync
/// first" toast wall with one always-visible explanation + a **Sync now**
/// action that kicks an outbox drain. Renders nothing once the record has a
/// real server id (or for a brand-new unsaved entity, where [entityId] is null).
///
/// Mirrors [OfflineBanner]'s slim-strip shape.
class SyncFirstBanner extends StatelessWidget {
  const SyncFirstBanner({required this.entityId, super.key});

  /// The viewed/edited record's id. The banner renders only when this is a
  /// local `tmp_` placeholder.
  final String? entityId;

  @override
  Widget build(BuildContext context) {
    final id = entityId;
    if (id == null || !isUnsynced(id)) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return Material(
      color: tokens.sentSoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 18, color: tokens.sent),
              const SizedBox(width: InSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('not_synced_yet'),
                  style: TextStyle(color: tokens.ink2, fontSize: 13),
                  // Two lines, not one: on a phone the sentence is cut off
                  // before it says what has not happened yet.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: InSpacing.sm),
              TextButton(
                onPressed: () => _syncNow(context),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.sent,
                  minimumSize: const Size(64, 36),
                ),
                child: Text(context.tr('sync_now')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _syncNow(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    unawaited(services.sync.flushNow(companyId: companyId));
  }
}

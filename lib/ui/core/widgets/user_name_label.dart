import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';

/// Resolves a user's display name from the local Drift cache and renders it as
/// a `Text`. Falls back to the raw [userId] while the watch is unresolved (e.g.
/// a user no longer attached to the company) and to an em-dash when [userId] is
/// empty.
///
/// Unlike [ClientNameLabel] there is no lazy per-id hydrate: the company roster
/// is seeded up front by `UserRepository.applyBundle` from the `/login` /
/// `/refresh` envelope (`GET /users/{id}` is 412 password-gated, so a
/// single-user fetch isn't available). Drift dedupes identical watch queries,
/// so N rows referencing the same user share one subscription.
class UserNameLabel extends StatelessWidget {
  const UserNameLabel({
    super.key,
    required this.userId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String userId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (userId.isEmpty) {
      return Text(
        '—',
        style:
            style ?? TextStyle(fontSize: 13, height: 1.2, color: tokens.ink3),
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, userId);
    }
    return StreamBuilder<User?>(
      stream: services.user.watch(companyId: companyId, id: userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user == null || user.displayName.isEmpty
            ? userId
            : user.displayName;
        return _text(context, name);
      },
    );
  }

  Widget _text(BuildContext context, String text) => Text(
    text,
    style:
        style ??
        TextStyle(fontSize: 13, height: 1.2, color: context.inTheme.ink),
    maxLines: maxLines,
    overflow: overflow,
  );
}

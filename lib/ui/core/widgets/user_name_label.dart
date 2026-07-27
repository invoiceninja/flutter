import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';

/// Resolves a user's display name from the local Drift cache and renders it as
/// a `Text`. Renders nothing while the watch is resolving (a blank first frame
/// beats a flash of raw hashed id) and a muted em-dash when [userId] is empty
/// OR when the id resolves to no cached user — an id absent from the roster
/// (ex-employee, revoked access) can never resolve, so showing the raw id
/// would just be permanent "random letters" in the column.
///
/// This deliberately diverges from [ClientNameLabel], which keeps the raw id
/// pre-data: the client label lazily hydrates per id, so its id is
/// transitional. Users have no hydrate path — the company roster is seeded up
/// front by `UserRepository.applyBundle` from the `/login` / `/refresh`
/// envelope (`GET /users/{id}` is 412 password-gated, so a single-user fetch
/// isn't available). Drift dedupes identical watch queries, so N rows
/// referencing the same user share one subscription.
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
    if (userId.isEmpty) {
      return _muted(context);
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _muted(context);
    }
    return StreamBuilder<User?>(
      stream: services.user.watch(companyId: companyId, id: userId),
      builder: (context, snapshot) {
        // Only blank out when there is genuinely nothing yet — a resubscribe
        // (any parent rebuild) puts the snapshot back into `waiting` with the
        // previous value still attached, and discarding it flickered the name
        // to empty for a frame.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _text(context, '');
        }
        final user = snapshot.data;
        if (user == null || user.displayName.isEmpty) {
          return _muted(context);
        }
        return _text(context, user.displayName);
      },
    );
  }

  Widget _muted(BuildContext context) => Text(
    '—',
    style:
        style ??
        TextStyle(fontSize: 13, height: 1.2, color: context.inTheme.ink3),
    maxLines: maxLines,
    overflow: overflow,
  );

  Widget _text(BuildContext context, String text) => Text(
    text,
    style:
        style ??
        TextStyle(fontSize: 13, height: 1.2, color: context.inTheme.ink),
    maxLines: maxLines,
    overflow: overflow,
  );
}

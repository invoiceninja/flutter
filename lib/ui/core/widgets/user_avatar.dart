import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/initials_avatar.dart';

/// Tinted initials badge for a user id — the avatar counterpart to
/// `UserNameLabel`, resolving the same way: a watch on the local Drift roster
/// seeded by `UserRepository.applyBundle` from the `/login` / `/refresh`
/// envelope (`GET /users/{id}` is 412 password-gated, so there is no per-id
/// hydrate path).
///
/// Used as the `defaultChild` of a list row's `LeadingSelectSlot`, where it
/// answers "who is this assigned to?" at a glance — and, when nobody is, says
/// so with a muted placeholder rather than dead space, so an unassigned row
/// reads as deliberate rather than as an avatar that failed to load.
///
/// Deliberately has no `Tooltip`: inside a `LeadingSelectSlot` the pointer
/// entering the slot swaps this widget out for the selection checkbox, so a
/// tooltip on it could never fire on desktop. The name lives in the
/// `assigned_user` column and on the detail screen instead.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.userId,
    this.companyId,
    this.size = 32,
  });

  /// Empty renders the "unassigned" placeholder.
  final String userId;

  /// Company to resolve [userId] against. Falls back to the active session's
  /// company; pass it explicitly where the caller already holds one (list rows
  /// do), so the widget doesn't depend on session state mid-company-switch.
  final String? companyId;

  final double size;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return _Unassigned(size: size);

    final services = context.read<Services>();
    final company =
        companyId ?? services.auth.session.value?.currentCompanyId ?? '';
    if (company.isEmpty) return _Unassigned(size: size);

    return StreamBuilder<User?>(
      stream: services.user.watch(companyId: company, id: userId),
      builder: (context, snapshot) {
        // Blank only when there is genuinely nothing yet. A resubscribe (any
        // parent rebuild) re-enters `waiting` with the previous value still
        // attached, and discarding it flickers the badge — same rule as
        // `UserNameLabel`.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return SizedBox(width: size, height: size);
        }
        final user = snapshot.data;
        // An id absent from the roster (ex-employee, revoked access) can never
        // resolve — but the task *is* assigned, so this stays a tinted badge
        // rather than dropping back to the unassigned placeholder.
        final label = user == null ? null : initialsFor(user.displayName);
        return Semantics(
          label: user?.displayName,
          child: InitialsAvatar(seed: userId, label: label ?? '?', size: size),
        );
      },
    );
  }
}

/// Empty avatar slot. Same footprint as [InitialsAvatar] so a list of mixed
/// rows stays column-aligned.
class _Unassigned extends StatelessWidget {
  const _Unassigned({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Semantics(
      label: context.tr('unassigned'),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        child: Icon(
          Icons.person_outline,
          size: size * 0.56,
          color: tokens.ink3,
        ),
      ),
    );
  }
}

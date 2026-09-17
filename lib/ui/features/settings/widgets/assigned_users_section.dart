import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/assignable_users.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
///
/// The two `:count` strings the card renders are deliberately **absent**:
/// `settings_search_catalog_test` fails the build on a catalog key whose
/// resolved value carries a placeholder, because the search list renders keys
/// raw. `contacts_sync_label_name` is the existing precedent for a
/// parameterised line kept out of the catalog.
const kAssignedUsersSearchKeys = <String>[
  'users',
  'hide_unverified_users',
  'hide_unverified_users_help',
];

/// Device Settings card for the "Hide unverified users" preference
/// (invoiceninja/flutter#150).
///
/// **The heading is `users`, not `assigned_user`**, and that is a correctness
/// choice rather than a stylistic one. `assigned_user` is the literal label of
/// the Tasks filter-bar picker *and* of the `assigned_user` list column on
/// eight entities — both of which this preference deliberately does not touch
/// — so a card titled "Assigned User" promises to govern three surfaces and
/// governs one. It is also Title Case out of `en.json` where every neighbouring
/// heading is sentence case, and `_app_pending.json` cannot override a
/// non-blank Transifex value.
///
/// **The count line is the only place this feature can ever show its own
/// effect**, since it deliberately puts no marker inside the picker popover.
/// Two neighbours on this same screen already do exactly this —
/// `SidebarCountersSection._BadgePreview` ("picking 'Overdue' shows the actual
/// red number you're about to get rather than making you go and look") and
/// `ContactsSyncSection`'s preflight count — and without it the switch is a
/// control with no observable consequence anywhere in the app.
///
/// Placement is 5th of 10 on Device Settings, between Contacts and Dashboard.
/// The four cards below are dashboard / list / rail chrome while this one
/// changes what a *form* offers, but the load-bearing reason is scroll reach:
/// Sidebar counters alone can render 14 rows, and a settings-search hit lands
/// at the top of the screen with no per-field anchor, so anything below that
/// block is a long way down on a phone.
class AssignedUsersSection extends StatelessWidget {
  const AssignedUsersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().hideUnverifiedUsers;
    return FormSection(
      title: context.tr('users'),
      spacing: 0,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: InSpacing.sm),
          child: Text(
            context.tr('hide_unverified_users_help'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: controller,
          builder: (context, enabled, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.person_off_outlined),
                title: Text(context.tr('hide_unverified_users')),
                value: enabled,
                onChanged: controller.set,
              ),
              _HiddenCount(hiding: enabled),
            ],
          ),
        ),
      ],
    );
  }
}

/// "N users …" plus a way to go and do something about them.
///
/// Collapses to nothing when the count is zero — the absence is the honest
/// answer, and it is what tells a single-user or all-verified account that this
/// switch will do nothing. **Only this line collapses, never the card**:
/// `phone_actions_section.dart` states the countervailing rule, that a control
/// worth seeing renders anyway because a disappearing one reads as a bug.
class _HiddenCount extends StatelessWidget {
  const _HiddenCount({required this.hiding});

  /// Drives which sentence is shown, not the number — the count is what the
  /// preference *would* hide either way.
  final bool hiding;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Listened, not a bare `context.read`: Device Settings has no listener of
    // its own for a company switch, so `SidebarCountersSection`'s listener-free
    // read goes stale there. One line avoids inheriting that.
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: services.auth.session,
      builder: (context, session, _) {
        final companyId = session?.currentCompanyId ?? '';
        if (companyId.isEmpty) return const SizedBox.shrink();
        final meId = session?.userId ?? '';
        // Keyed on the company alone: the roster the count is drawn from does
        // not depend on the toggle, only the sentence does — so flipping the
        // switch must not tear down and re-create this subscription.
        return WatchBuilder<List<User>>(
          cacheKey: companyId,
          create: () => services.user.watchAllForPicker(companyId: companyId),
          builder: (context, snap) {
            final roster = snap.data ?? const <User>[];
            final count = hiddenFromAssignmentCount(
              roster,
              signedInUserId: meId,
            );
            if (count == 0) return const SizedBox.shrink();
            // The number is always `hiddenFromAssignmentCount` — the narrow
            // rule — so the off-state sentence must describe *that*, not the
            // broad `email_verified_at` flag. "Never confirmed their email
            // address" would be a different set: an email-changer and an
            // unverified owner both satisfy it, are badged Verification
            // Pending in User Management, and are deliberately not in this
            // number. Saying "would be hidden" keeps the sentence and the
            // figure describing one rule.
            final key = hiding
                ? (count == 1
                      ? 'hidden_from_assignment_count_singular'
                      : 'hidden_from_assignment_count_plural')
                : (count == 1
                      ? 'would_be_hidden_count_singular'
                      : 'would_be_hidden_count_plural');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The switch announces its own flip; the count changing
                // afterwards is silent, and for a screen-reader user that count
                // is the entire legibility story. Same device
                // `save_failed_banner.dart` uses.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    context.tr(key, {'count': '$count'}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.inTheme.ink3,
                    ),
                  ),
                ),
                SizedBox(height: InSpacing.sm),
                // Not a `ListTile` trailing: a trailing widget is laid out in
                // the row's leftover width, which is what turned a 72 px
                // `_UserRow` into a 410 px one in User Management. `Wrap` keeps
                // the button on its own line and right-aligned at any width.
                //
                // The destination is load-bearing rather than a signpost: User
                // Management's paged `GET /users` is the only path in `lib/`
                // that upserts fresh user rows, so this is the repair for a
                // roster whose `email_verified_at` has gone stale (the delta
                // `/refresh` doesn't carry `company.users`, and users are not
                // in the Sync pass).
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: () => context.go('/settings/users'),
                    child: Text(context.tr('user_management')),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

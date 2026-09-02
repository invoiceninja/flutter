import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/features/clients/widgets/client_portal.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Contacts" card on the client detail screen. Shows the first 3 contacts
/// inline. Extra contacts surface via "+N more":
///   - ≥[Breakpoints.wide] screen width (tablet/desktop): expands inline within the same card.
///   - below: opens a bottom sheet listing every contact.
///
/// Hides entirely when the client has no contacts (matches the React
/// "hide-if-empty" behavior).
///
/// The wide/narrow decision uses `MediaQuery.sizeOf(context).width` rather than
/// `LayoutBuilder`. The grid above this card uses `IntrinsicHeight` so cards
/// align to equal heights on desktop; `IntrinsicHeight` queries children for
/// intrinsic sizes, and `LayoutBuilder` cannot answer those queries (it needs
/// real constraints first). `MediaQuery` is an inherited-widget lookup, so it
/// answers fine during the intrinsic pass.
class ClientDetailContactsCard extends StatefulWidget {
  const ClientDetailContactsCard({
    super.key,
    required this.contacts,
    required this.clientHash,
    required this.clientId,
  });

  final List<Contact> contacts;

  /// Client-level auth token appended to each contact's portal silent-login
  /// URL (`?silent=true&client_hash=…`).
  final String clientHash;

  /// The client's own id — **not** [clientHash], which is a portal token.
  /// Resolves this client's `settings.timezone_id` override so a call placed
  /// from here knows what time it is where the phone will ring.
  final String clientId;

  @override
  State<ClientDetailContactsCard> createState() =>
      _ClientDetailContactsCardState();
}

class _ClientDetailContactsCardState extends State<ClientDetailContactsCard> {
  static const int _inlineLimit = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.contacts.isEmpty) return const SizedBox.shrink();
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
    final all = widget.contacts;
    final showAll = _expanded || all.length <= _inlineLimit;
    final visible = showAll ? all : all.take(_inlineLimit).toList();
    final hiddenCount = all.length - visible.length;

    return DashboardCardShell(
      title: context.tr('contacts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DetailRowStack(
            children: visible
                .map((c) => _ContactRow(c, widget.clientHash, widget.clientId))
                .toList(),
          ),
          if (hiddenCount > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  if (wide) {
                    setState(() => _expanded = true);
                  } else {
                    _openSheet(context);
                  }
                },
                icon: const Icon(Icons.unfold_more, size: 16),
                label: Text(
                  context.tr('plus_n_more', {'count': '$hiddenCount'}),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final tokens = sheetContext.inTheme;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              InSpacing.lg(context),
              InSpacing.sm,
              InSpacing.lg(context),
              InSpacing.lg(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: InSpacing.sm),
                  child: Text(
                    sheetContext.tr('contacts'),
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: DetailRowStack(
                      children: widget.contacts
                          .map(
                            (c) => _ContactRow(
                              c,
                              widget.clientHash,
                              widget.clientId,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow(this.contact, this.clientHash, this.clientId);
  final Contact contact;
  final String clientHash;
  final String clientId;

  // `PhoneActionsScope` wraps the WHOLE row, not just the number: the Call /
  // Message buttons are built here, one level above `PhoneNumberValue`'s own
  // scope, so without this they hold whatever the preference was when the card
  // was last built. A detail screen stays mounted behind `/settings/**`, so
  // flipping the switch there left a live Call button beside a number that had
  // already gone inert.
  @override
  Widget build(BuildContext context) => PhoneActionsScope(builder: _buildRow);

  Widget _buildRow(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final name = ('${contact.firstName} ${contact.lastName}').trim();
    final hasName = name.isNotEmpty;
    final title = hasName
        ? name
        : (contact.email.isNotEmpty
              ? contact.email
              : context.tr('no_name_fallback'));
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: tokens.ink,
      fontWeight: FontWeight.w500,
    );
    final subStyle = theme.textTheme.bodySmall?.copyWith(color: tokens.ink3);
    // The email shows as a secondary line only when a name occupies the title.
    final secondaryEmail = hasName ? contact.email : '';

    final actions = <Widget>[
      if (contact.phone.isNotEmpty)
        ...phoneActionButtons(
          context,
          contact.phone,
          subject: _contactSubject(context, contact),
          clientId: clientId,
        ),
      if (contact.link.isNotEmpty) ...[
        TextButton.icon(
          style: contactActionButtonStyle,
          icon: const Icon(Icons.open_in_new, size: 14),
          label: Text(context.tr('view_portal')),
          onPressed: () => launchClientPortal(
            context,
            clientPortalUrl(contactLink: contact.link, clientHash: clientHash),
          ),
        ),
        TextButton.icon(
          style: contactActionButtonStyle,
          icon: const Icon(Icons.content_copy, size: 14),
          label: Text(context.tr('copy_link')),
          onPressed: () => copyToClipboard(
            context,
            clientPortalUrl(contactLink: contact.link, clientHash: clientHash),
          ),
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title is copyable only when it's the email (no name).
                if (hasName || contact.email.isEmpty)
                  Text(title, style: titleStyle)
                else
                  CopyableValue(
                    value: contact.email,
                    child: Text(title, style: titleStyle),
                  ),
                if (secondaryEmail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  CopyableValue(
                    value: secondaryEmail,
                    child: Text(secondaryEmail, style: subStyle),
                  ),
                ],
                if (contact.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  PhoneNumberValue(
                    phone: contact.phone,
                    style: subStyle,
                    subject: _contactSubject(context, contact),
                    clientId: clientId,
                  ),
                ],
                // One `Wrap` for every row action. It used to be gated on
                // `contact.link.isNotEmpty`, which was fine while both buttons
                // inside it were portal ones — as the home for Call / Message
                // too, that gate would have hidden them from any contact
                // without a portal link.
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: InSpacing.xs),
                  Wrap(spacing: InSpacing.sm, children: actions),
                ],
              ],
            ),
          ),
          if (contact.isLocked)
            Padding(
              padding: const EdgeInsets.only(left: InSpacing.sm, top: 2),
              child: Tooltip(
                message: context
                    .tr('user_unsubscribed')
                    .replaceAll(':link', '')
                    .trim(),
                child: Icon(
                  Icons.error_outline,
                  size: 15,
                  color: tokens.overdue,
                ),
              ),
            ),
          if (contact.isPrimary)
            Padding(
              padding: const EdgeInsets.only(left: InSpacing.sm, top: 2),
              child: Icon(Icons.star, size: 14, color: tokens.accent),
            ),
        ],
      ),
    );
  }
}

/// Who the confirmation prompt names when this contact is called. Falls back
/// through name → email → the client-level "blank contact" label, so the
/// dialog never asks the user to confirm calling nobody.
String _contactSubject(BuildContext context, Contact contact) {
  final name = ('${contact.firstName} ${contact.lastName}').trim();
  if (name.isNotEmpty) return name;
  if (contact.email.isNotEmpty) return contact.email;
  return context.tr('no_name_fallback');
}

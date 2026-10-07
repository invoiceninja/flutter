import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/phone_actions.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

/// One thing a contact row can do. [onTap] null means "not available for this
/// contact" and the action is left out entirely — a contact with no number
/// gets no Call button, greyed or otherwise.
@immutable
class PartyContactAction {
  const PartyContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

/// A person at a client or a vendor: who they are, how to reach them, and the
/// one or two things most often done with them.
///
/// Party-agnostic on purpose. `Contact` and `VendorContact` share no
/// supertype, so this takes plain strings and callbacks and each party builds
/// it from its own model.
///
/// **Actions.** The first two of [actions] that are available become icon
/// buttons, at full touch size on touch; the rest go behind a `⋮`. This
/// replaced a `Wrap` of four 32 px text buttons per contact, which was under
/// the touch floor by its own admission and, on a phone, wrapped to a second
/// line under every contact. Order [actions] most-used first; an action that
/// does not apply is skipped, so the same list yields Call + Email on a phone
/// and Email + Copy portal link on a desktop with tap-to-call off.
///
/// **Email is text, not a link.** It copies — on tap with a finger, by the
/// hover icon with a pointer — and writing to it is the Email action. Making
/// the address itself launch a mail client would put two small links two
/// pixels apart (the phone below it dials), and would take away the one thing
/// a desktop webmail user wants from an address: to copy it.
///
/// Wrap the whole row in a `PhoneActionsScope` at the call site: the Call and
/// Message actions are computed above this widget, from a preference that can
/// change while the screen is mounted behind `/settings`.
class PartyContactRow extends StatelessWidget {
  const PartyContactRow({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.actions,
    this.isPrimary = false,
    this.pills = const [],
    this.details = const [],
    this.phoneSubject,
    this.clientId,
    this.logTarget,
  });

  /// Empty falls back to [email], then to `no_name_fallback`.
  final String name;
  final String email;
  final String phone;

  /// Most-used first. See the class doc for how they are split.
  final List<PartyContactAction> actions;

  final bool isPrimary;

  /// Exceptions worth a label under the name — Unsubscribed, CC Only. Empty
  /// for the ordinary contact, which is why these are not columns.
  final List<Widget> pills;

  /// Extra read-only lines, already "Label: value" — last portal login,
  /// contact custom fields.
  final List<String> details;

  /// Passed to `PhoneNumberValue` — who the confirm prompt names, whose
  /// timezone the out-of-hours check uses, and where a finished call is logged.
  final String? phoneSubject;
  final String? clientId;
  final CallLogTarget? logTarget;

  /// How many of [actions] get their own button.
  static const int _primaryCount = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final hasName = name.trim().isNotEmpty;
    final title = hasName
        ? name.trim()
        : (email.isNotEmpty ? email : context.tr('no_name_fallback'));
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: tokens.ink,
      fontWeight: FontWeight.w500,
    );
    // `ink2`: these lines are the contact's actual details, and `ink3` at
    // this size is under the contrast floor on a card.
    final subStyle = theme.textTheme.bodySmall?.copyWith(color: tokens.ink2);
    final available = [
      for (final a in actions)
        if (a.onTap != null) a,
    ];
    final primary = available.take(_primaryCount).toList(growable: false);
    final overflow = available.skip(_primaryCount).toList(growable: false);

    Widget emailLine(TextStyle? style) => CopyableValue(
      value: email,
      child: Text(
        email,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

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
                Row(
                  children: [
                    Flexible(
                      // The title is the email only when there is no name, and
                      // then it is the copyable one.
                      child: (hasName || email.isEmpty)
                          ? Text(
                              title,
                              style: titleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : emailLine(titleStyle),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(width: 6),
                      // A bare star says nothing to a screen reader and little
                      // to anyone who has not learned it.
                      Tooltip(
                        message: context.tr('primary_contact'),
                        child: Icon(
                          Icons.star,
                          size: 14,
                          color: tokens.accent,
                          semanticLabel: context.tr('primary_contact'),
                        ),
                      ),
                    ],
                  ],
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: InSpacing.xs),
                  Wrap(spacing: 6, runSpacing: 4, children: pills),
                ],
                if (hasName && email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  emailLine(subStyle),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  PhoneNumberValue(
                    phone: phone,
                    style: subStyle,
                    subject: phoneSubject,
                    clientId: clientId,
                    logTarget: logTarget,
                  ),
                ],
                for (final line in details) ...[
                  const SizedBox(height: 2),
                  Text(line, style: subStyle),
                ],
              ],
            ),
          ),
          if (primary.isNotEmpty || overflow.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: InSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final a in primary) _ActionButton(action: a),
                  if (overflow.isNotEmpty) _OverflowButton(actions: overflow),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The side of a contact action button: the touch floor on touch, the app's
/// compact icon-button size with a pointer.
double _actionSize() => Env.isTouchPrimary ? InSizes.touchTarget : 32;

/// Pinned on both axes. Left to the theme an `IconButton` is floored at the
/// 48 px tap target on touch, which would make three of them wider than the
/// row can spare and taller than the three lines of text beside them.
ButtonStyle _pinned() {
  final size = _actionSize();
  return IconButton.styleFrom(
    fixedSize: Size.square(size),
    minimumSize: Size.zero,
    maximumSize: Size.infinite,
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final PartyContactAction action;

  @override
  Widget build(BuildContext context) => IconButton(
    style: _pinned(),
    tooltip: action.label,
    icon: Icon(action.icon, size: 18),
    onPressed: action.onTap,
  );
}

class _OverflowButton extends StatelessWidget {
  const _OverflowButton({required this.actions});

  final List<PartyContactAction> actions;

  @override
  Widget build(BuildContext context) => BackDismissibleMenuAnchor(
    consumeOutsideTap: true,
    menuChildren: [
      for (final a in actions)
        MenuItemButton(
          leadingIcon: Icon(a.icon, size: 18),
          onPressed: a.onTap,
          child: Text(a.label),
        ),
    ],
    builder: (context, controller, _) => IconButton(
      style: _pinned(),
      tooltip: context.tr('more'),
      icon: const Icon(Icons.more_vert, size: 18),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

/// A labelled exception under a contact's name. Neutral unless [alert] — an
/// unsubscribed contact is the one that explains an email that never arrived.
class PartyContactPill extends StatelessWidget {
  const PartyContactPill({super.key, required this.label, this.alert = false});

  final String label;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return StatusPill(
      label: label,
      fgColor: alert ? tokens.overdue : tokens.draft,
      bgColor: alert ? tokens.overdueSoft : tokens.draftSoft,
    );
  }
}

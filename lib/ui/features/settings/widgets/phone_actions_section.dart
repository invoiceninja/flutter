import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/phone_actions_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/phone/phone_actions_settings.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kPhoneActionsSearchKeys = <String>[
  'phone_numbers',
  'phone_numbers_help',
  'tap_to_call',
  'confirm_before_calling',
  'confirm_before_calling_help',
  'warn_outside_business_hours',
  'warn_outside_business_hours_help',
  'offer_to_log_calls',
  'offer_to_log_calls_help',
  'business_hours',
];

/// Device Settings card for tap-to-call on phone numbers
/// (invoiceninja/flutter#109, `docs/tap-to-call.md`).
///
/// Sits immediately above Contacts: that card makes an *incoming* call show a
/// name, this one makes an outgoing one one tap — the same phone, both
/// directions.
///
/// Rendered on every platform even though "Tap to call" defaults off on
/// desktop: a macOS user with FaceTime, or Windows with Phone Link, has a
/// working dialer and needs somewhere to switch it on.
class PhoneActionsSection extends StatelessWidget {
  const PhoneActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<Services>().phoneActions;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final prefs = controller.value;
        final theme = Theme.of(context);
        return FormSection(
          title: context.tr('phone_numbers'),
          spacing: 0,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: InSpacing.sm),
              child: Text(
                context.tr('phone_numbers_help'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.inTheme.ink3,
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.call_outlined),
              title: Text(context.tr('tap_to_call')),
              value: prefs.tapToCall,
              onChanged: controller.setTapToCall,
            ),
            // The two guards only mean anything while tapping dials, so they
            // grey out rather than vanish — a disappearing row reads as a bug,
            // and their state is worth seeing before you switch the master on.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.help_outline),
              title: Text(context.tr('confirm_before_calling')),
              subtitle: Text(context.tr('confirm_before_calling_help')),
              value: prefs.confirmBeforeCall,
              onChanged: prefs.tapToCall
                  ? controller.setConfirmBeforeCall
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.bedtime_outlined),
              title: Text(context.tr('warn_outside_business_hours')),
              subtitle: Text(context.tr('warn_outside_business_hours_help')),
              value: prefs.warnOutsideBusinessHours,
              onChanged: prefs.tapToCall
                  ? controller.setWarnOutsideBusinessHours
                  : null,
            ),
            if (prefs.tapToCall && prefs.warnOutsideBusinessHours)
              _BusinessHoursRow(controller: controller, prefs: prefs),
            // Last, because it is about what happens *after* a call rather
            // than before it — and greyed with the rest when tapping doesn't
            // dial, since there is then no dialer round trip to notice.
            // Native mobile only in effect (see
            // `PhoneActionsSettings.offerToLogCalls`); the row still renders
            // everywhere so the state is visible, exactly like the two guards.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.phone_in_talk_outlined),
              title: Text(context.tr('offer_to_log_calls')),
              subtitle: Text(context.tr('offer_to_log_calls_help')),
              value: prefs.offerToLogCalls,
              onChanged: prefs.tapToCall ? controller.setOfferToLogCalls : null,
            ),
          ],
        );
      },
    );
  }
}

/// The From / To pair. Shown only while the warning is on — unlike the
/// switches above it, an inert time field says nothing useful about state.
class _BusinessHoursRow extends StatelessWidget {
  const _BusinessHoursRow({required this.controller, required this.prefs});

  final PhoneActionsController controller;
  final PhoneActionsSettings prefs;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId;
    // Sync read: the field only needs the formatter to pick 12- vs 24-hour
    // display, and a null one falls back to `HH:MM` rather than blocking the
    // card on a fetch.
    final formatter = companyId == null
        ? null
        : services.formatterIfReady(companyId);
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: InSpacing.xs),
            child: Text(
              context.tr('business_hours'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InTimeField(
                  labelText: context.tr('from'),
                  formatter: formatter,
                  value: _toTimeOfDay(prefs.startMinutes),
                  onChanged: (v) => controller.setBusinessHours(
                    startMinutes: _toMinutes(v, prefs.startMinutes),
                  ),
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              Expanded(
                child: InTimeField(
                  labelText: context.tr('to'),
                  formatter: formatter,
                  value: _toTimeOfDay(prefs.endMinutes),
                  onChanged: (v) => controller.setBusinessHours(
                    endMinutes: _toMinutes(v, prefs.endMinutes),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static TimeOfDay _toTimeOfDay(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60);

  // `InTimeField` can hand back null only when `clearable` is set, which it
  // isn't here — the window has no "unset" state, so a null keeps the old
  // value rather than silently zeroing it to midnight.
  static int _toMinutes(TimeOfDay? v, int fallback) =>
      v == null ? fallback : v.hour * 60 + v.minute;
}

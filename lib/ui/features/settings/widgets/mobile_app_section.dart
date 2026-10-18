import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kMobileAppSearchKeys = <String>[
  'mobile_app_promo_section',
  'mobile_app_promo_settings_body',
  'mobile_app_promo_entry',
];

/// Device Settings card for the phone app — the mobile-app promo's permanent
/// home (docs/mobile-app-promo.md), where "Don't show again" can't reach.
///
/// The mirror image of `ContactsSyncSection`: that card renders only on a
/// phone, this one everywhere else — the features it names are the phone's.
/// Absent where the promo has nothing to offer (a phone, a demo or a
/// `localhost` session).
class MobileAppSection extends StatelessWidget {
  const MobileAppSection({super.key});

  @override
  Widget build(BuildContext context) {
    if (currentMobilePromoTargets().isEmpty ||
        !mobilePromoEligible(context.read<Services>().auth.session.value)) {
      return const SizedBox.shrink();
    }
    return FormSection(
      title: context.tr('mobile_app_promo_section'),
      children: [
        Text(
          context.tr('mobile_app_promo_settings_body'),
          style: TextStyle(color: context.inTheme.ink2, height: 1.4),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () =>
                unawaited(showMobileAppPromoDialog(context, isManual: true)),
            icon: const Icon(Icons.smartphone_outlined, size: 18),
            label: Text(context.tr('mobile_app_promo_entry')),
          ),
        ),
      ],
    );
  }
}

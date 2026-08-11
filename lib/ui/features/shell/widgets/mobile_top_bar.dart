import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/shell/widgets/company_avatar.dart';
import 'package:admin/ui/features/shell/widgets/show_company_picker.dart';

/// Compact top bar for the narrow shell. Shows the active company and (when
/// the user has more than one) opens the picker as a modal bottom sheet.
@Deprecated(
  'Replaced by AppDrawer on mobile; remove when the cleanup PR lands.',
)
class MobileTopBar extends StatelessWidget implements PreferredSizeWidget {
  const MobileTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final auth = context.read<Services>().auth;
    return Material(
      color: tokens.surface,
      child: ValueListenableBuilder<AuthSession?>(
        valueListenable: auth.session,
        builder: (context, session, _) {
          if (session == null) return const SizedBox.shrink();
          final current = session.currentCompany;
          return SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: tokens.border)),
                ),
                child: InkWell(
                  // Always tappable, single company included — see the class doc
                  // on `CompanySwitcherButton`.
                  onTap: () => showCompanyPicker(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CompanyAvatar(
                          name: current?.displayName ?? '—',
                          seed: current?.id ?? '',
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            current?.displayName ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: tokens.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.unfold_more, size: 16, color: tokens.ink3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

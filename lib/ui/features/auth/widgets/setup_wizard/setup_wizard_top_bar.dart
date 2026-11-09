import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';

/// The wizard's 56 px top bar: the wordmark (wide layouts), the step
/// progress, and a ⋮ menu holding the two ways out — switching company and
/// signing out — so they stop cluttering the form (docs/first-run-welcome.md).
class SetupWizardTopBar extends StatelessWidget {
  const SetupWizardTopBar({
    super.key,
    required this.step,
    required this.stepCount,
    required this.complete,
    required this.showWordmark,
    required this.enabled,
    required this.onSignOut,
    this.onSwitchCompany,
  });

  /// 1-based.
  final int step;
  final int stepCount;

  /// The finish moment: every segment filled.
  final bool complete;
  final bool showWordmark;
  final bool enabled;
  final VoidCallback onSignOut;

  /// Null when the user has no other company to switch to.
  final VoidCallback? onSwitchCompany;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = context.tr('setup_step_x_of_y', {
      'current': '$step',
      'total': '$stepCount',
    });
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: InSpacing.xl, end: 8),
        child: Row(
          children: [
            if (showWordmark) ...[
              Image.asset(
                isDark
                    ? 'assets/images/logo_dark.png'
                    : 'assets/images/logo_light.png',
                height: 22,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: InSpacing.xl),
            ],
            Expanded(
              child: Align(
                alignment: showWordmark
                    ? AlignmentDirectional.center
                    : AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Semantics(
                    label: label,
                    excludeSemantics: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            for (var i = 1; i <= stepCount; i++) ...[
                              if (i > 1) const SizedBox(width: 6),
                              Expanded(
                                child: _Segment(filled: complete || i <= step),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: showWordmark
                              ? TextAlign.center
                              : TextAlign.start,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showWordmark) const SizedBox(width: InSpacing.xl),
            BackDismissibleMenuAnchor(
              menuChildren: [
                if (onSwitchCompany != null)
                  MenuItemButton(
                    key: const ValueKey('setup_switch_company'),
                    leadingIcon: const Icon(Icons.swap_horiz_outlined),
                    onPressed: onSwitchCompany,
                    child: Text(context.tr('switch_company')),
                  ),
                MenuItemButton(
                  key: const ValueKey('setup_sign_out'),
                  leadingIcon: const Icon(Icons.logout_outlined),
                  onPressed: onSignOut,
                  child: Text(context.tr('logout')),
                ),
              ],
              builder: (context, controller, _) => IconButton(
                key: const ValueKey('setup_more'),
                tooltip: context.tr('more_options'),
                icon: const Icon(Icons.more_vert),
                onPressed: enabled
                    ? () => controller.isOpen
                          ? controller.close()
                          : controller.open()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: tokens.border),
            AnimatedFractionallySizedBox(
              duration: motion(InMotion.slow),
              curve: InMotion.move,
              alignment: AlignmentDirectional.centerStart,
              widthFactor: filled ? 1 : 0,
              child: ColoredBox(color: tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}

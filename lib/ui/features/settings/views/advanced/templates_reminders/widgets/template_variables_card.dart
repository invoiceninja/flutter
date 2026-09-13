import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Copyable variable chips displayed next to the body editor — the reference
/// list for the template's scope, from the same catalog as the editors' chips
/// and picker (`lib/domain/email_template_variables.dart`), so the three can't
/// disagree about which variables a template supports.
///
/// Each chip names the variable in plain words over its `$token`, so the
/// friendly labels the editors show can be matched to the token behind them.
/// Tapping still copies the token; inserting lives on the fields' own
/// "Insert variable" buttons, next to where the text goes.
///
/// On narrow viewports (< 600 px — the [InSpacing] mobile breakpoint), the
/// groups collapse into a single [ExpansionTile] so the editor stays above
/// the fold.
class TemplateVariablesCard extends StatelessWidget {
  const TemplateVariablesCard({super.key, required this.templateKey});

  /// Active template id; picks the variables its email engine supports.
  final String templateKey;

  @override
  Widget build(BuildContext context) {
    final groups = templateVariableGroups(
      templateVariableScopeForTemplate(templateKey),
    );

    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    if (isNarrow) {
      // Collapsed by default so the editor remains above the fold on a
      // 375 px phone — opening the expansion tile reveals the groups.
      return _MobileVariablesTile(
        groups: groups,
        onTapChip: (v) => _copy(context, v),
      );
    }

    return FormSection(
      title: context.tr('variables'),
      children: [
        for (final group in groups)
          _VariableGroup(group: group, onTap: (v) => _copy(context, v)),
      ],
    );
  }

  void _copy(BuildContext context, String token) {
    Clipboard.setData(ClipboardData(text: token));
    final msg = context.tr('copied_to_clipboard').replaceFirst(':value', token);
    Notify.info(context, msg);
  }
}

class _VariableGroup extends StatelessWidget {
  const _VariableGroup({required this.group, required this.onTap});

  final TemplateVariableGroup group;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(group.labelKey),
          style: theme.textTheme.labelLarge?.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.sm,
          children: [
            for (final variable in group.variables)
              _VariableChip(
                label: templateVariableLabel(context, variable),
                token: variable.token,
                onPressed: () => onTap(variable.token),
              ),
          ],
        ),
      ],
    );
  }
}

class _VariableChip extends StatelessWidget {
  const _VariableChip({
    required this.label,
    required this.token,
    required this.onPressed,
  });

  final String label;
  final String token;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r2);
    return Semantics(
      button: true,
      label: '${context.tr('copy')} $label',
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: t.surfaceAlt,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: t.border),
          borderRadius: radius,
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            // This chip is a tappable copy control, and two text lines over
            // 6+6 of padding land near 42 px — under the touch floor. A
            // `minHeight`, never a fixed height: a fixed one clamps the line
            // box and slices descenders past ~1.14x text scale.
            constraints: BoxConstraints(
              minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InSpacing.sm,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible + ellipsis is a safety net: real labels fit
                  // within a chip on a 360 px phone, but a pathologically long
                  // one degrades gracefully instead of throwing a RenderFlex
                  // overflow.
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: t.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          token,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: kMonoFontFamily,
                            fontSize: 12,
                            color: t.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: context.tr('copy_to_clipboard'),
                    child: Icon(Icons.copy, size: 14, color: t.ink2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileVariablesTile extends StatelessWidget {
  const _MobileVariablesTile({required this.groups, required this.onTapChip});

  final List<TemplateVariableGroup> groups;
  final ValueChanged<String> onTapChip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(InRadii.r3),
          border: Border.all(color: t.border),
          boxShadow: t.shadow1,
        ),
        child: Theme(
          // ExpansionTile pulls the divider color from the inherited
          // ThemeData — null it out so the open state doesn't draw a
          // 1px line that fights the FormSection-style card chrome.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(),
            title: Text(
              context.tr('variables'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: t.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            childrenPadding: EdgeInsets.symmetric(
              horizontal: InSpacing.lg(context),
              vertical: InSpacing.md(context),
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) SizedBox(height: InSpacing.lg(context)),
                _VariableGroup(group: groups[i], onTap: onTapChip),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

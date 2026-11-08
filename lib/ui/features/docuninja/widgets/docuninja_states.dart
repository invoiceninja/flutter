import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';

/// The screens React shows before the DocuNinja documents
/// (`pages/documents/join/Join.tsx`, `components/DocumentStates.tsx`),
/// in the app's chrome. docs/docuninja.md.

/// React's Join page: what DocuNinja does, then Create (an Invoice Ninja
/// owner or admin on Pro or Enterprise), Upgrade (an owner or admin on
/// another plan) or "contact your admin" (everyone else).
class DocuNinjaJoinView extends StatelessWidget {
  const DocuNinjaJoinView({
    super.key,
    required this.isAdmin,
    required this.isEligible,
    required this.isCreating,
    required this.onCreate,
    required this.onUpgrade,
  });

  /// An Invoice Ninja owner or admin (React's `useAdmin`).
  final bool isAdmin;

  /// The Invoice Ninja plan is Pro or Enterprise (`account.plan`).
  final bool isEligible;
  final bool isCreating;
  final VoidCallback onCreate;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    Widget feature(IconData icon, Color tint, String title, String help) =>
        Padding(
          padding: const EdgeInsets.all(InSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(InRadii.r2),
                ),
                child: Icon(icon, color: tint),
              ),
              const SizedBox(height: InSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                help,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
              ),
            ],
          ),
        );
    final features = [
      feature(
        Icons.send_outlined,
        tokens.accent,
        context.tr('docuninja_join_esignatures'),
        context.tr('docuninja_join_esignatures_help'),
      ),
      feature(
        Icons.check_circle_outline,
        tokens.paid,
        context.tr('templates'),
        context.tr('docuninja_join_templates_help'),
      ),
      feature(
        Icons.schedule_outlined,
        tokens.partial,
        context.tr('docuninja_join_integration'),
        context.tr('docuninja_join_integration_help'),
      ),
    ];
    final Widget action;
    if (!isAdmin) {
      action = Text(
        context.tr('docuninja_contact_admin_for_access'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink2),
      );
    } else if (isEligible) {
      action = FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
        onPressed: isCreating ? null : onCreate,
        icon: const Icon(Icons.send_outlined, size: 18),
        label: Text(
          context.tr(
            isCreating
                ? 'docuninja_creating_account'
                : 'create_docuninja_account',
          ),
        ),
      );
    } else {
      action = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('upgrade_plan_docuninja'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink2),
          ),
          const SizedBox(height: InSpacing.sm),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: onUpgrade,
            child: Text(context.tr('upgrade')),
          ),
        ],
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(InSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.draw_outlined, size: 40, color: tokens.accent),
              SizedBox(height: InSpacing.md(context)),
              Semantics(
                header: true,
                headingLevel: 1,
                child: Text(
                  context.tr('welcome_to_docuninja'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: InSpacing.sm),
              Text(
                context.tr('docuninja_join_tagline'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: tokens.ink2),
              ),
              SizedBox(height: InSpacing.lg(context)),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border.all(color: tokens.border),
                  borderRadius: BorderRadius.circular(InRadii.r3),
                ),
                child: Padding(
                  padding: EdgeInsets.all(InSpacing.lg(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_outline,
                            size: 18,
                            color: tokens.ink2,
                          ),
                          const SizedBox(width: InSpacing.sm),
                          Expanded(
                            child: Semantics(
                              header: true,
                              headingLevel: 2,
                              child: Text(
                                context.tr('docuninja_join_features_title'),
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: InSpacing.md(context)),
                      LayoutBuilder(
                        builder: (context, c) => c.maxWidth >= 480
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final f in features) Expanded(child: f),
                                ],
                              )
                            : Column(children: features),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: InSpacing.lg(context)),
              Center(child: action),
            ],
          ),
        ),
      ),
    );
  }
}

/// React's company setup: the user has DocuNinja, but not for this company.
class DocuNinjaCompanySetupView extends StatelessWidget {
  const DocuNinjaCompanySetupView({
    super.key,
    required this.isWorking,
    required this.onSetUp,
  });

  final bool isWorking;
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.draw_outlined,
    title: context.tr('welcome_to_docuninja'),
    subtitle: context.tr('docuninja_company_setup_help'),
    action: FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
      onPressed: isWorking ? null : onSetUp,
      child: Text(context.tr(isWorking ? 'setting_up' : 'setup_company')),
    ),
  );
}

/// React's plan wall: a DocuNinja admin whose DocuNinja plan is not Pro.
class DocuNinjaPlanWallView extends StatelessWidget {
  const DocuNinjaPlanWallView({super.key, required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.draw_outlined,
    title: context.tr('upgrade_plan_docuninja'),
    action: FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
      onPressed: onUpgrade,
      child: Text(context.tr('upgrade_plan')),
    ),
  );
}

/// A DocuNinja page other than the home (a document, the templates, users
/// or settings) when DocuNinja is not ready for this user: a sentence on
/// why, and the way to DocuNinja's home, which shows Join, company setup,
/// the plan wall or the error with what to do about it.
class DocuNinjaGoHomeState extends StatelessWidget {
  const DocuNinjaGoHomeState({super.key, required this.access});

  final DocuNinjaAccess access;

  @override
  Widget build(BuildContext context) {
    final why = switch (access) {
      DocuNinjaAccess.notJoined => 'docuninja_join_tagline',
      DocuNinjaAccess.companySetup => 'docuninja_company_setup_help',
      DocuNinjaAccess.planWall => 'upgrade_plan_docuninja',
      DocuNinjaAccess.offline => 'offline',
      DocuNinjaAccess.failed => 'an_error_occurred_try_again',
      _ => null,
    };
    return EmptyState(
      icon: Icons.draw_outlined,
      title: context.tr('docuninja'),
      subtitle: why == null ? null : context.tr(why),
      action: TextButton(
        onPressed: () => context.go('/docuninja'),
        child: Text(context.tr('docuninja')),
      ),
    );
  }
}

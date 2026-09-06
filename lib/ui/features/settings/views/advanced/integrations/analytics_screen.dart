import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/company_settings_gate.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// `/settings/account_management/integrations/analytics` — Google Analytics + Matomo tracking
/// IDs. Mirrors React's dedicated Analytics page. Fields write to the
/// top-level company record (`google_analytics_key`, `matomo_id`,
/// `matomo_url`) via `services.company.updateCompany`.
///
/// Editor pattern: local draft + inline Save button (the button shows only
/// when the draft differs from the persisted values). Stream-watches the
/// company so server-side changes (refresh, another device) repopulate the
/// controllers when the form isn't dirty.
class IntegrationsAnalyticsScreen extends StatefulWidget {
  const IntegrationsAnalyticsScreen({super.key});

  @override
  State<IntegrationsAnalyticsScreen> createState() =>
      _IntegrationsAnalyticsScreenState();
}

class _IntegrationsAnalyticsScreenState
    extends State<IntegrationsAnalyticsScreen> {
  final _gaCtrl = TextEditingController();
  final _matomoIdCtrl = TextEditingController();
  final _matomoUrlCtrl = TextEditingController();

  Company? _company;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pull the canonical company (GET /companies/{id}) on mount so the cached
    // Drift row holds the server's real SMTP / expense / task / payment-
    // conversion values BEFORE a Save here PUTs the whole company. After a
    // full sync (login / refresh / force-resync) the login envelope + insert
    // omit those columns, leaving them at Drift table defaults; saving an
    // analytics key would otherwise enqueue the full company body with those
    // defaulted fields and clobber the server values. Mirrors the cascade
    // settings pages' `unawaited(kickRefresh())` -> `repo.refresh(companyId)`
    // (draft_stream_host.dart / settings_draft_view_model.dart). refresh()
    // is best-effort (swallows errors), so the page still renders offline.
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null && companyId.isNotEmpty) {
      unawaited(services.company.refresh(companyId));
    }
  }

  @override
  void dispose() {
    _gaCtrl.dispose();
    _matomoIdCtrl.dispose();
    _matomoUrlCtrl.dispose();
    super.dispose();
  }

  void _syncFromCompany(Company c) {
    if (_dirty) return; // Don't trample the user's in-progress edits.
    // Only reassign when the value differs — a blind `controller.text =` on
    // every Drift tick resets the cursor/selection to offset 0 mid-view
    // (before the user's first keystroke flips `_dirty`).
    _seedController(_gaCtrl, c.googleAnalyticsKey);
    _seedController(_matomoIdCtrl, c.matomoId);
    _seedController(_matomoUrlCtrl, c.matomoUrl);
    _company = c;
  }

  static void _seedController(TextEditingController ctrl, String value) {
    if (ctrl.text != value) ctrl.text = value;
  }

  void _markDirty() {
    if (_company == null) return;
    final next =
        _gaCtrl.text != _company!.googleAnalyticsKey ||
        _matomoIdCtrl.text != _company!.matomoId ||
        _matomoUrlCtrl.text != _company!.matomoUrl;
    if (next == _dirty) return;
    setState(() => _dirty = next);
  }

  Future<void> _save() async {
    final company = _company;
    if (company == null || _saving) return;
    setState(() => _saving = true);
    try {
      await context.read<Services>().company.updateCompany(
        draft: company.copyWith(
          googleAnalyticsKey: _gaCtrl.text.trim(),
          matomoId: _matomoIdCtrl.text.trim(),
          matomoUrl: _matomoUrlCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      Notify.success(context, context.tr('saved_settings'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      Notify.error(context, context.tr('error_refresh_page'), error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    return SettingsScreenScaffold(
      titleKey: 'analytics',
      body: (companyId == null || companyId.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : CompanySettingsGate(
              companyId: companyId,
              builder: (context, ready) {
                // Save PUTs the whole company, so saving (and typing) is gated
                // until the canonical row is fetched (the mount refresh above /
                // CompanySettingsGate) — otherwise cached server-only defaults
                // would clobber the server's real values.
                final canSave = _dirty && !_saving && ready;
                return StreamBuilder<Company?>(
                  stream: services.company.watchCompany(companyId),
                  builder: (context, snapshot) {
                    final company = snapshot.data;
                    if (company == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    _syncFromCompany(company);

                    return SettingsFormShell(
                      sections: [
                        if (!ready) const CompanySettingsLockedBanner(),
                        FormSection(
                          title: context.tr('analytics'),
                          children: [
                            TextField(
                              controller: _gaCtrl,
                              enabled: ready,
                              onChanged: (_) => _markDirty(),
                              decoration: InputDecoration(
                                labelText: context.tr(
                                  'google_analytics_tracking_id',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                            ),
                            TextField(
                              controller: _matomoIdCtrl,
                              enabled: ready,
                              onChanged: (_) => _markDirty(),
                              decoration: InputDecoration(
                                labelText: context.tr('matomo_id'),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                            ),
                            TextField(
                              controller: _matomoUrlCtrl,
                              enabled: ready,
                              onChanged: (_) => _markDirty(),
                              decoration: InputDecoration(
                                labelText: context.tr('matomo_url'),
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.url,
                              autocorrect: false,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (canSave) _save();
                              },
                            ),
                            // Inline Save, hidden when the draft matches the
                            // persisted values.
                            if (_dirty || _saving)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(120, 44),
                                  ),
                                  onPressed: canSave ? _save : null,
                                  child: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(context.tr('save')),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

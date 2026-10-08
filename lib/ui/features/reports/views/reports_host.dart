import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Owns what every Reports route shares: the [ReportsViewModel] and the
/// company's [Formatter].
///
/// **Above the routes, not in them.** The gallery and each report are
/// separate routes of one branch, and the view model has to outlive a move
/// between them — it is what remembers each report's state, holds the result
/// on screen, and writes the one blob all of that is persisted in. A view
/// model per route would be two writers flushing the same blob during every
/// switch, and a result thrown away every time the reader glanced at the
/// gallery.
///
/// Both are rebuilt when the session's company changes (from the session
/// listener, never from `build`, which would dispose a notifier mid-rebuild).
class ReportsHost extends StatefulWidget {
  const ReportsHost({super.key, required this.child});

  final Widget child;

  @override
  State<ReportsHost> createState() => _ReportsHostState();
}

class _ReportsHostState extends State<ReportsHost> {
  late Services _services;
  late ReportsViewModel _vm;
  late String _companyId;
  late bool _hadAccess;
  Formatter? _formatter;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value?.currentCompanyId ?? '';
    _hadAccess = _hasAccess;
    _vm = _buildVm();
    _services.auth.session.addListener(_onSessionChanged);
    if (_companyId.isNotEmpty) _loadFormatter();
  }

  /// Reports are Pro on hosted; a trial counts. With no session there is
  /// nothing to gate.
  bool get _hasAccess => _services.auth.session.value?.hasProAccess ?? true;

  ReportsViewModel _buildVm() {
    final companyId = _companyId;
    return ReportsViewModel(
      repo: _services.reports,
      statics: _services.statics,
      navStateDao: _services.db.navStateDao,
      companyId: companyId,
      fetchRowIds: true,
      autoRun: true,
      // Read when a run would start, so a plan that lapses or is upgraded
      // mid-session is honoured without rebuilding anything.
      canRun: () => _hasAccess,
      online: _services.connectivity.isOnlineStream,
      companyCurrencyId: companyId.isEmpty
          ? null
          : () async =>
                (await _services.formatterFor(companyId)).settings.currencyId,
    );
  }

  void _loadFormatter() {
    final loadingFor = _companyId;
    _services.formatterFor(loadingFor).then((f) {
      if (!mounted || loadingFor != _companyId) return;
      setState(() => _formatter = f);
    });
  }

  void _onSessionChanged() {
    final nextId = _services.auth.session.value?.currentCompanyId ?? '';
    if (nextId == _companyId) {
      // Same company: the one thing that can have changed for this screen is
      // whether the plan lets a report run. Make the run it was owed.
      final access = _hasAccess;
      if (access != _hadAccess) {
        _hadAccess = access;
        if (access) _vm.retryOwed();
        if (mounted) setState(() {});
      }
      return;
    }
    final oldVm = _vm;
    setState(() {
      _companyId = nextId;
      _formatter = null;
      _hadAccess = _hasAccess;
      _vm = _buildVm();
    });
    oldVm.dispose();
    if (_companyId.isNotEmpty) _loadFormatter();
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The view model has no BuildContext; feed it the localized headers it
    // can't resolve itself here (re-applied on locale change since build
    // re-runs). Used only on the next run: the synthetic Product-report
    // `stock_value` column, and the optional date column, whose header the
    // server answers with an unresolved `"texts."`.
    _vm.firstMonthOfYear = _formatter?.settings.firstMonthOfYear ?? 1;
    _vm.stockValueLabel = context.tr('stock_value');
    _vm.optionalDateColumnLabel = context.tr('created_at');
    return ChangeNotifierProvider<ReportsViewModel>.value(
      value: _vm,
      // Always mounted, formatter or not: switching the scope in when the
      // formatter lands would change the tree's shape and remount everything
      // under it.
      child: FormatterScope(formatter: _formatter, child: widget.child),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/reports_body.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/utils/formatting.dart';

/// Top-level Reports page reachable from the sidebar at `/reports`.
///
/// Owns the [Formatter] and the [ReportsViewModel] — both rebuilt on
/// company-switch via the auth session listener (not via `build`, which
/// would dispose a notifier mid-rebuild).
///
/// First-paint rule (per the plan): Clients report preselected,
/// `This year` range; the EmptyState invites the user to Run.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Services _services;
  late ReportsViewModel _vm;
  late String _companyId;
  Formatter? _formatter;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value?.currentCompanyId ?? '';
    _vm = _buildVm();
    _services.auth.session.addListener(_onSessionChanged);
    if (_companyId.isNotEmpty) _loadFormatter();
  }

  ReportsViewModel _buildVm() => ReportsViewModel(
    repo: _services.reports,
    statics: _services.statics,
    navStateDao: _services.db.navStateDao,
    companyId: _companyId,
  );

  void _loadFormatter() {
    final loadingFor = _companyId;
    _services.formatterFor(loadingFor).then((f) {
      if (!mounted || loadingFor != _companyId) return;
      setState(() => _formatter = f);
    });
  }

  void _onSessionChanged() {
    final s = _services.auth.session.value;
    final nextId = s?.currentCompanyId ?? '';
    if (nextId == _companyId) return;
    final oldVm = _vm;
    setState(() {
      _companyId = nextId;
      _formatter = null;
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
    final globalNav = Breakpoints.isGlobalNavVisible(context);
    // The VM has no BuildContext; feed it the localized header for the
    // synthetic Product-report `stock_value` column here (re-applied on locale
    // change since build re-runs). Used only on the next Run.
    _vm.stockValueLabel = context.tr('stock_value');
    return ChangeNotifierProvider<ReportsViewModel>.value(
      value: _vm,
      child: Scaffold(
        drawer: globalNav ? null : const AppDrawer(),
        appBar: AppBar(
          title: Text(context.tr('reports')),
          leading: globalNav ? null : const DrawerHamburger(),
          automaticallyImplyLeading: !globalNav,
        ),
        body: ReportsBody(formatter: _formatter),
      ),
    );
  }
}

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';

/// Tracks whether the active company sends by PEPPOL, for a list whose rows
/// show the PEPPOL sent / failed mark (`PeppolStatusScope`). Read from the
/// company stream the list already holds, so no row reads the company.
mixin PeppolListCompany<T> on GenericListViewModel<T> {
  bool _companyUsesPeppol = false;

  /// The company's `e_invoice_type` is `PEPPOL` — the company layer, which is
  /// the tier React reads.
  bool get companyUsesPeppol => _companyUsesPeppol;

  @override
  void onCompanyChanged(Company? company) {
    super.onCompanyChanged(company);
    final next = company?.settings.eInvoiceType == kEInvoiceTypePEPPOL;
    if (next == _companyUsesPeppol) return;
    _companyUsesPeppol = next;
    notifyListeners();
  }
}

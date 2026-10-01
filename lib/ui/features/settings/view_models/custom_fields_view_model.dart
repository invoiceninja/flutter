import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/custom_field_pdf_offer.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';

/// State holder for the Custom Fields screen — every tab in the
/// [CustomFieldsShell] binds to one instance, scoped to the active company.
///
/// The lifecycle (load, watch, dirty, reset, save), the override path, and the
/// field-error plumbing all live on [SettingsDraftViewModel]. The one addition
/// is the PDF offer (React #3360): a save that gives an invoice / product /
/// surcharge field its first label leaves [pendingPdfOffers] set, and the
/// shell asks whether to print them.
class CustomFieldsViewModel extends SettingsDraftViewModel {
  CustomFieldsViewModel({required super.repo, required super.companyId});

  List<PdfFieldOffer> _pendingPdfOffers = const [];

  /// Fields the last save labelled for the first time that the PDF could
  /// show. The shell consumes them with [takePdfOffers].
  List<PdfFieldOffer> get pendingPdfOffers => _pendingPdfOffers;

  /// Returns and clears [pendingPdfOffers] — so a rebuild can't ask twice.
  List<PdfFieldOffer> takePdfOffers() {
    final offers = _pendingPdfOffers;
    _pendingPdfOffers = const [];
    return offers;
  }

  @override
  Future<Company?> save() async {
    final before = initialValue?.customFields ?? const <String, String>{};
    final after = draft?.customFields ?? const <String, String>{};
    final result = await super.save();
    if (result != null) {
      final offers = newlyLabelledPdfFields(before: before, after: after);
      if (offers.isNotEmpty) {
        _pendingPdfOffers = offers;
        notifyListeners();
      }
    }
    return result;
  }

  /// Appends [offers] to the company's PDF variables and saves — a second,
  /// ordinary company save through the outbox.
  Future<Company?> addFieldsToPdf(List<PdfFieldOffer> offers) {
    if (offers.isEmpty) return Future.value(null);
    updateSettings(
      (s) => s.copyWith(pdfVariables: withPdfFields(s.pdfVariables, offers)),
    );
    return super.save();
  }
}

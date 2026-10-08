import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';

/// What the designer takes from the company it is opened in. One place, so
/// the builder and the starter gallery — which is shown before a builder
/// exists — draw the same letterhead in the same colours.

/// The sample document with the company's own name, logo and address over
/// the made-up ones.
DesignerSampleData designerSampleFor(CompanySettings settings) =>
    DesignerSampleData.fallback.withCompany(
      name: settings.name,
      logo: settings.companyLogo,
      address1: settings.address1,
      address2: settings.address2,
      city: settings.city,
      state: settings.state,
      postalCode: settings.postalCode,
      phone: settings.phone,
      email: settings.email,
      website: settings.website,
      vatNumber: settings.vatNumber,
      idNumber: settings.idNumber,
    );

/// The company's primary and secondary colours, as upper-case hex, the ones
/// it has set.
List<String> designerBrandColors(CompanySettings settings) => [
  for (final c in [settings.primaryColor, settings.secondaryColor])
    if (c != null && c.trim().isNotEmpty) c.trim().toUpperCase(),
];

/// Whether the company has uploaded a logo.
bool companyHasLogo(Company company) =>
    (company.settings.companyLogo ?? '').trim().isNotEmpty;

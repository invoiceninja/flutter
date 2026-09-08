import 'package:admin/data/db/dao/company_gateway_dao.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/column_factories.dart';

typedef CompanyGatewayColumn = ColumnDefinition<CompanyGateway>;

const List<String> kDefaultCompanyGatewayColumns = <String>[
  CompanyGatewayFieldIds.label,
  CompanyGatewayFieldIds.gatewayKey,
  CompanyGatewayFieldIds.updatedAt,
];

final List<CompanyGatewayColumn> kAllCompanyGatewayColumns =
    <CompanyGatewayColumn>[
      CompanyGatewayColumn(
        id: CompanyGatewayFieldIds.label,
        labelKey: 'label',
        cellBuilder: (g, _) =>
            cellText(g.label.isEmpty ? '—' : g.label, bold: true),
        valueBuilder: (g) => cellNonZeroString(g.label),
      ),
      CompanyGatewayColumn(
        id: CompanyGatewayFieldIds.gatewayKey,
        labelKey: 'gateway_type',
        width: 220,
        // Until the statics-driven provider lookup is wired into the tile,
        // surface the raw key as a non-bold caption so the list compiles
        // and still tells the user which provider a row is.
        cellBuilder: (g, _) => cellText(g.gatewayKey),
        valueBuilder: (g) => cellNonZeroString(g.gatewayKey),
      ),
      // `updatedAt` is epoch SECONDS here, not a DateTime, so the lift is done
      // at the call site. Hand-rolling this column is what let its copy value
      // drift to raw epoch seconds while every other list copies ISO-8601.
      colUpdatedAt<CompanyGateway>(
        CompanyGatewayFieldIds.updatedAt,
        (g) => DateTime.fromMillisecondsSinceEpoch(g.updatedAt * 1000),
        width: 160,
      ),
    ];

final Map<String, CompanyGatewayColumn> companyGatewayColumnsById = {
  for (final c in kAllCompanyGatewayColumns) c.id: c,
};

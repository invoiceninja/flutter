// The expense-category record screen, assembled — the record layout end to
// end against a real `Services` graph and a real local database, with the
// network played by a `MockClient`. The harness is
// `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/models/api/expense_category_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/expense_categories/views/expense_category_detail_screen.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_color.dart';
import 'package:admin/ui/features/expense_categories/widgets/detail/expense_category_detail_header.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_actions.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

ExpenseCategoryApi _category({
  String id = 'e1',
  String color = '#2F7DC3',
  bool isDeleted = false,
  int archivedAt = 0,
}) => ExpenseCategoryApi.fromJson({
  'id': id,
  'name': 'Travel & Lodging',
  'color': color,
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'updated_at': 1710000000,
  'created_at': 1700000000,
});

const _categories = '/api/v1/expense_categories';

/// Records every request, and answers the category list with nothing new.
class _Server {
  final List<Uri> requests = [];

  Iterable<Uri> get listAsks => requests.where((u) => u.path == _categories);

  http.Client get client => MockClient((request) async {
    requests.add(request.url);
    if (request.method == 'GET' && request.url.path == _categories) {
      return jsonOk({'data': <Object>[]});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

/// The category screen over a category seeded into the local database.
void _screenTest(
  String description,
  ExpenseCategoryApi category,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
}) => recordScreenTest(
  description,
  seed: (services) => services.expenseCategories.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: category,
  ),
  screen: () => ExpenseCategoryDetailScreen(id: category.id),
  ready: () => find.byType(ExpenseCategoryDetailHeader),
  body: body,
  httpClient: server?.client,
  company: company,
);

Finder _header(String text) => find.descendant(
  of: find.byType(ExpenseCategoryDetailHeader),
  matching: find.text(text),
);

void main() {
  _screenTest(
    'an active category: identity and Details — and nothing it has no use for',
    _category(),
    (tester, screen) async {
      expect(_header('Travel & Lodging'), findsOneWidget);
      // Its own colour under the name, and again — copyable — in Details.
      expect(_header('#2F7DC3'), findsOneWidget);
      expect(find.byType(ExpenseCategorySwatch), findsNWidgets(2));
      expect(find.text('Color'), findsOneWidget);
      // The name is the title; Details does not repeat it.
      expect(find.text('Name'), findsNothing);

      // No figure the server keeps, and no action beyond the bar's.
      expect(find.byType(StandingCard), findsNothing);
      expect(
        find.byType(EntityQuickActions<ExpenseCategoryAction>),
        findsNothing,
      );
      // A settings page like any other: centred and capped.
      expect(find.byType(SettingsFormShell), findsOneWidget);
    },
  );

  _screenTest(
    'a category with no colour falls back to its dates, and draws no swatch',
    _category(color: ''),
    (tester, screen) async {
      expect(find.byType(ExpenseCategorySwatch), findsNothing);
      expect(find.text('Color'), findsNothing);
      expect(_header('Travel & Lodging'), findsOneWidget);
    },
  );

  _screenTest(
    'a deleted category is read-only, and says so once',
    _category(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
    },
  );

  _screenTest(
    'an archived category says so, with Restore',
    _category(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may not edit categories gets the banner without Restore',
    _category(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_expense',
    ),
  );

  _screenTest(
    'an unsynced category gets the sync banner',
    _category(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
    },
  );

  final server = _Server();
  _screenTest(
    'opening asks the server nothing; R refreshes the categories, with '
    'nothing clicked first',
    _category(),
    (tester, screen) async {
      // Past the quiet re-check: categories are bundled reference data, and
      // there is no by-id fetch for it to make.
      await screen.quiet();
      expect(server.listAsks, isEmpty);

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
      await screen.until(() => server.listAsks.isNotEmpty, 'the refresh');
    },
    server: server,
  );
}

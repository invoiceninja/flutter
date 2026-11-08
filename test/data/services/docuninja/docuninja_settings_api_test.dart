import 'dart:convert';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Tokens implements DocuNinjaTokenSource {
  @override
  String? token = 'dn';

  @override
  Future<String?> refreshToken() async => token;

  @override
  int get epoch => 0;
}

/// DocuNinja's own settings, as React's settings pages save them.
void main() {
  late List<http.Request> sent;

  DocuNinjaApi api(Object body) {
    sent = [];
    return DocuNinjaApi(
      DocuNinjaClient(
        tokens: _Tokens(),
        httpClient: MockClient((r) async {
          sent.add(r);
          return http.Response(jsonEncode(body), 200);
        }),
      ),
    );
  }

  test(
    'a settings page puts the whole company back, settings replaced',
    () async {
      final company = DnCompany.fromJson({
        'id': 'c1',
        'name': 'Acme',
        'date_format': 'd/M/Y',
        'settings': {'widget_show_label': false, 'keep': 1},
      });
      await api(
        <String, dynamic>{},
      ).updateCompanySettings(company, {'widget_show_label': true, 'keep': 1});
      expect(sent.single.method, 'PUT');
      expect(sent.single.url.path, '/api/companies/c1');
      final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
      expect(body['name'], 'Acme');
      expect(body['date_format'], 'd/M/Y');
      expect(body['settings'], {'widget_show_label': true, 'keep': 1});
    },
  );

  test(
    'email templates save together, keeping what the app does not edit',
    () async {
      final a = api({
        'data': [
          {
            'id': 't1',
            'name': 'Sent',
            'subject': 's',
            'body': 'b',
            'type_id': 2,
          },
        ],
      });
      final templates = await a.emailTemplates();
      await a.saveEmailTemplates([templates.single.copyWith(subject: 'New')]);
      expect(sent.last.url.path, '/api/templates/bulk');
      expect(jsonDecode(sent.last.body), {
        'action': 'update',
        'templates': [
          {
            'id': 't1',
            'name': 'Sent',
            'subject': 'New',
            'body': 'b',
            'type_id': 2,
          },
        ],
      });
    },
  );

  test('reminder schedules: archived and deleted ones are hidden', () async {
    final rows = await api({
      'data': [
        {'id': 'r1', 'name': 'Live', 'num_days': 3, 'enabled': true},
        {'id': 'r2', 'name': 'Gone', 'is_deleted': true},
        {'id': 'r3', 'name': 'Old', 'archived_at': '2026-01-01'},
      ],
    }).reminderSchedules();
    expect(rows.map((r) => r.id), ['r1']);
    expect(rows.single.direction, 'after_event');
  });

  test('a schedule is created, updated, toggled and deleted', () async {
    final a = api(<String, dynamic>{});
    const s = DnReminderSchedule(
      id: '',
      name: 'Nudge',
      subject: 'Please sign',
      body: 'Hi',
      numDays: 2,
      direction: 'after_event',
      enabled: true,
      isDeleted: false,
    );
    await a.saveReminderSchedule(s);
    expect(
      (sent.last.method, sent.last.url.path),
      ('POST', '/api/reminder_schedules'),
    );
    expect(jsonDecode(sent.last.body), {
      'name': 'Nudge',
      'subject': 'Please sign',
      'body': 'Hi',
      'num_days': 2,
      'schedule_direction': 'after_event',
      'enabled': true,
    });
    await a.saveReminderSchedule(s, id: 'r1');
    expect(
      (sent.last.method, sent.last.url.path),
      ('PUT', '/api/reminder_schedules/r1'),
    );
    await a.setReminderScheduleEnabled('r1', false);
    expect(jsonDecode(sent.last.body), {'enabled': false});
    await a.deleteReminderSchedule('r1');
    expect(
      (sent.last.method, sent.last.url.path),
      ('DELETE', '/api/reminder_schedules/r1'),
    );
  });
}

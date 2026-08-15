import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/domain/tasks/task_invoice_notes.dart';
import 'package:admin/utils/formatting.dart';

/// A US-style `MM/dd/yyyy` company — the shape that exposes the date-ordering
/// bug, since those strings don't sort chronologically.
final _usFormatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: 'US',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {'US': DatetimeFormat(id: 'US', format: 'MM/dd/yyyy')},
);

/// The forum ask behind this file (#23511): several projects' tasks on one
/// invoice. An invoice has a single `project_id` and a line item has none, so
/// the project is written into the notes of the first line of each project's
/// run — these tests pin that text.
Task _task({
  String id = 't1',
  String description = '',
  String number = '',
  String timeLog = '',
}) => Task.fromApi(
  TaskApi(id: id, description: description, number: number, timeLog: timeLog),
);

Project _project({String id = 'p1', String name = 'Acme Redesign'}) =>
    Project.fromApi(ProjectApi(id: id, name: name));

Company _company({
  bool markdown = true,
  bool project = false,
  bool projectHeader = true,
  bool datelog = false,
  bool timelog = false,
  bool hours = false,
  bool itemDescription = false,
}) => Company(
  id: 'co',
  markdownEnabled: markdown,
  invoiceTaskProject: project,
  invoiceTaskProjectHeader: projectHeader,
  invoiceTaskDatelog: datelog,
  invoiceTaskTimelog: timelog,
  invoiceTaskHours: hours,
  invoiceTaskItemDescription: itemDescription,
);

// 2023-11-14 22:13:20Z → 23:13:20Z, one billable hour.
const _oneHour = '[[1700000000,1700003600,"",true]]';
const _oneHourWithNote = '[[1700000000,1700003600,"Wireframes",true]]';
const _nonBillable = '[[1700000000,1700003600,"",false]]';
// Two entries on the same UTC day, 1h and 30m.
const _twoEntriesSameDay =
    '[[1700000000,1700003600,"",true],[1700007200,1700009000,"",true]]';

void main() {
  group('taskInvoiceNotes', () {
    test('with every toggle off it is just the description — the pre-existing '
        'behaviour, and the default for a company that never opted in', () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work', timeLog: _oneHour),
        company: _company(),
        project: _project(),
        includeProjectHeader: true,
      );
      expect(notes, 'Design work');
    });

    test('emits the styled project header in BOTH markdown modes — every PDF '
        'design styles .project-header and none style h1-h6, so the markdown '
        "'## Name' v1 emits lands as an unstyled <h2>", () {
      const expected =
          '<div class="project-header">Acme Redesign</div>\nDesign work';
      for (final markdown in [true, false]) {
        expect(
          taskInvoiceNotes(
            _task(description: 'Design work'),
            company: _company(markdown: markdown, project: true),
            project: _project(),
            includeProjectHeader: true,
          ),
          expected,
          reason: 'markdownEnabled: $markdown',
        );
      }
    });

    test('separates time lines with <br/> in BOTH markdown modes — a bare '
        'newline collapses in HTML, running every entry onto one line, and '
        'markdown is off by default', () {
      for (final markdown in [true, false]) {
        expect(
          taskInvoiceNotes(
            _task(timeLog: _twoEntriesSameDay),
            company: _company(markdown: markdown, hours: true),
          ),
          '<div class="task-time-details">\n1 hour<br/>\n0.5 hours\n</div>',
          reason: 'markdownEnabled: $markdown',
        );
      }
    });

    test('no header unless the caller asks for one — only the first line of a '
        "project's run carries it", () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work'),
        company: _company(project: true),
        project: _project(),
      );
      expect(notes, 'Design work');
    });

    test('no header when Project Location is Service — the project name goes '
        'in product_key instead (taskToLineItem handles that half)', () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work'),
        company: _company(project: true, projectHeader: false),
        project: _project(),
        includeProjectHeader: true,
      );
      expect(notes, 'Design work');
    });

    test('hours-only lists the duration per entry (server parity — v1 emits '
        'nothing, leaving the setting inert on its own)', () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work', timeLog: _twoEntriesSameDay),
        company: _company(hours: true),
      );
      expect(
        notes,
        'Design work\n'
        '<div class="task-time-details">\n'
        '1 hour<br/>\n'
        '0.5 hours\n'
        '</div>',
      );
    });

    test('datelog + timelog + hours renders one line per entry, separated by '
        'an explicit <br/>', () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work', timeLog: _twoEntriesSameDay),
        company: _company(datelog: true, timelog: true, hours: true),
      );
      expect(notes, startsWith('Design work\n<div class="task-time-details">'));
      expect(notes, contains(' - '));
      expect(notes, contains(' • 1 hour'));
      expect(notes, contains(' • 0.5 hours'));
      expect(notes, endsWith('</div>'));
      // Between the two entries — and only between them.
      expect('<br/>'.allMatches(notes).length, 1);
    });

    test('a 30-minute entry pluralizes and formats the fraction', () {
      final notes = taskInvoiceNotes(
        _task(timeLog: '[[1700000000,1700001800,"",true]]'),
        company: _company(timelog: true, hours: true),
      );
      expect(notes, contains(' • 0.5 hours'));
    });

    test('datelog-only orders dates chronologically, not by the rendered '
        'string — 12/31 must not outrank 01/15 of the next year', () {
      final notes = taskInvoiceNotes(
        // One hour on 2025-12-31, one on 2026-01-15 (noon UTC each, so the
        // local day is stable across timezones).
        _task(
          timeLog:
              '[[1767182400,1767186000,"",true],'
              '[1768478400,1768482000,"",true]]',
        ),
        company: _company(datelog: true),
        formatter: _usFormatter,
      );
      expect(
        notes,
        '<div class="task-time-details">\n'
        '01/15/2026<br/>\n'
        '12/31/2025\n'
        '</div>',
      );
    });

    test(
      'datelog-only aggregates hours per date instead of listing entries',
      () {
        final notes = taskInvoiceNotes(
          _task(timeLog: _twoEntriesSameDay),
          company: _company(datelog: true, hours: true),
        );
        // Both entries fall on one date → a single aggregated line of 1.5 hours,
        // not two lines.
        expect(' • '.allMatches(notes).length, 1);
        expect(notes, contains(' • 1.5 hours'));
      },
    );

    test('non-billable entries are skipped — they are not in the quantity '
        'either, so listing them would bill hours nobody charged for', () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work', timeLog: _nonBillable),
        company: _company(timelog: true, hours: true),
      );
      // And no wrapper at all: an empty <div class="task-time-details"></div>
      // is visible junk on the invoice, and for a task with no description it
      // would be the entire notes body.
      expect(notes, 'Design work');
    });

    test(
      'a task with nothing to list produces no wrapper, not an empty one',
      () {
        expect(
          taskInvoiceNotes(
            _task(),
            company: _company(timelog: true, hours: true),
          ),
          '',
        );
        expect(
          taskInvoiceNotes(
            _task(timeLog: _nonBillable),
            company: _company(datelog: true),
          ),
          '',
        );
      },
    );

    test('a running entry is skipped (no stop timestamp)', () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work', timeLog: '[[1700000000,0,"",true]]'),
        company: _company(timelog: true, hours: true),
      );
      expect(notes, 'Design work');
    });

    test('the details block closes without a dangling <br/> (v1 leaves one, '
        'which renders a blank line inside the box)', () {
      final notes = taskInvoiceNotes(
        _task(timeLog: _oneHour),
        company: _company(timelog: true, hours: true),
      );
      expect(notes, isNot(contains('<br/>\n</div>')));
      expect(notes, endsWith('</div>'));
    });

    test("the entry's own note appears only when item descriptions are on", () {
      final off = taskInvoiceNotes(
        _task(timeLog: _oneHourWithNote),
        company: _company(timelog: true),
      );
      expect(off, isNot(contains('Wireframes')));

      final on = taskInvoiceNotes(
        _task(timeLog: _oneHourWithNote),
        company: _company(timelog: true, itemDescription: true),
      );
      expect(on, contains('Wireframes'));
    });

    test('header and time details combine, header first', () {
      final notes = taskInvoiceNotes(
        _task(description: 'Design work', timeLog: _oneHour),
        company: _company(project: true, timelog: true, hours: true),
        project: _project(),
        includeProjectHeader: true,
      );
      expect(
        notes,
        startsWith(
          '<div class="project-header">Acme Redesign</div>\nDesign work\n',
        ),
      );
      expect(notes, contains('<div class="task-time-details">'));
    });

    test('an empty description still produces a time-details block without a '
        'leading blank line', () {
      final notes = taskInvoiceNotes(
        _task(timeLog: _oneHour),
        company: _company(timelog: true),
      );
      expect(notes, startsWith('<div class="task-time-details">'));
    });
  });
}

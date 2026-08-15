import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/tasks/line_item_notes_display.dart';
import 'package:admin/domain/tasks/task_invoice_notes.dart';

void main() {
  group('lineItemNotesPlainText', () {
    test('a plain description is returned untouched — the common case must '
        'never be mangled', () {
      expect(
        lineItemNotesPlainText('Homepage wireframes'),
        'Homepage wireframes',
      );
      expect(lineItemNotesPlainText(''), '');
      expect(
        lineItemNotesPlainText('Fixed the < and > comparison bug'),
        'Fixed the < and > comparison bug',
      );
    });

    test('round-trips what taskInvoiceNotes actually generates', () {
      // Build the input through the real producer rather than hand-writing the
      // markup, so the two can't drift apart.
      final notes = taskInvoiceNotes(
        Task.fromApi(
          TaskApi(
            id: 't1',
            description: 'Homepage wireframes',
            // Two billable hours-worth of entries.
            timeLog:
                '[[1700000000,1700003600,"",true],[1700007200,1700009000,"",true]]',
          ),
        ),
        company: const Company(
          id: 'co',
          invoiceTaskProject: true,
          invoiceTaskProjectHeader: true,
          invoiceTaskHours: true,
        ),
        project: Project.fromApi(ProjectApi(id: 'p1', name: 'Acme Redesign')),
        includeProjectHeader: true,
      );
      // Sanity: the stored form is markup, which is the whole point.
      expect(notes, contains('<div class="project-header">'));

      expect(
        lineItemNotesPlainText(notes),
        'Acme Redesign\n'
        'Homepage wireframes\n'
        '1 hour\n'
        '0.5 hours',
      );
    });

    test("unwraps admin-portal's markdown header form too — those invoices "
        'sync into this app', () {
      expect(
        lineItemNotesPlainText('## Acme Redesign\nHomepage wireframes'),
        'Acme Redesign\nHomepage wireframes',
      );
    });

    test('strips a stray tag but keeps its words (legacy Quill residue)', () {
      expect(
        lineItemNotesPlainText('<p>Homepage wireframes</p>'),
        'Homepage wireframes',
      );
    });

    test('a note that is only markup collapses to empty, not to a tag', () {
      expect(
        lineItemNotesPlainText('<div class="task-time-details"></div>'),
        '',
      );
    });
  });

  group('lineItemNotesSummary', () {
    test('takes the first readable line, not the opening tag', () {
      expect(
        lineItemNotesSummary(
          '<div class="project-header">Acme Redesign</div>\n'
          'Homepage wireframes',
        ),
        'Acme Redesign',
      );
    });

    test('falls back to empty when there is nothing to show', () {
      expect(lineItemNotesSummary(''), '');
      expect(lineItemNotesSummary('<div class="project-header"></div>'), '');
    });
  });
}

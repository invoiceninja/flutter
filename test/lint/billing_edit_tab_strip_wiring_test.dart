import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the narrow billing-doc edit strip
/// (invoiceninja/flutter#140).
///
/// Scanned rather than exercised because pumping one of these layouts for
/// real needs a live `Services`, a Drift-backed repository per picker and a
/// `TabBarView` whose first page opens client / project / design streams —
/// and because **every failure here is silent**: re-add the `PDF` tab and the
/// app compiles, the strip still works, it just scrolls again on a phone;
/// forget `showPdfTab` on one of the five and that entity alone regresses.
/// Same reasoning as `tasks_view_wiring_test.dart` and
/// `status_tab_wiring_test.dart`.
///
/// The chrome itself (the `TabAlignment`, the fades, the controller
/// lifecycle) now lives in ONE widget, so it is asserted once here and
/// behaviourally in `billing_doc_edit_tab_strip_width_test.dart`, which
/// renders the real thing with the bundled font. What is left per entity is
/// the wiring a shared widget cannot own.
void main() {
  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path has moved');
    return file.readAsStringSync();
  }

  /// [read] with every `//` tail removed, so a rule can't be satisfied — or
  /// broken — by the prose that explains it. The trap
  /// `no_list_tile_name_link_test.dart` already records.
  String codeOf(String path) => read(path)
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i < 0 ? line : line.substring(0, i);
      })
      .join('\n');

  /// Every `Tab(text: context.tr('<key>'))` in [path] sits behind an `if` on
  /// its own line.
  ///
  /// The layout state spells the gate `_showEInvoice`; the desktop notes
  /// card, which is handed it, spells it `widget.showEInvoice`.
  ///
  /// This rule shipped **dead** for one commit: the needle was written as a
  /// non-raw string with an escaped `$`, so it looked for a literal
  /// `context.tr('` + dollar + `key')` that exists in no file, `allMatches`
  /// returned nothing and the loop never ran. The self-test below is here so
  /// that cannot recur silently — an empty match set is indistinguishable
  /// from a clean scan.
  void expectTabGated(String path, String key) {
    final needle = "Tab(text: context.tr('$key'))";
    final code = codeOf(path);
    final matches = needle.allMatches(code).toList();
    expect(
      matches,
      isNotEmpty,
      reason:
          'no `$needle` found in $path — either the tab is gone (update this '
          'rule) or the needle no longer matches how it is written',
    );
    for (final match in matches) {
      final lineStart = code.lastIndexOf('\n', match.start) + 1;
      expect(
        code.substring(lineStart, match.start),
        anyOf(
          contains('if (_showEInvoice) '),
          contains('if (widget.showEInvoice) '),
        ),
        reason: 'an ungated $key tab at offset ${match.start} of $path',
      );
    }
  }

  const strip =
      'lib/ui/features/billing_shared/edit/billing_doc_edit_tab_strip.dart';

  /// layout file -> (screen file, the layout's widget, its button).
  const docs = {
    'invoices': (
      layout: 'lib/ui/features/invoices/widgets/edit/invoice_edit_layout.dart',
      screen: 'lib/ui/features/invoices/views/invoice_edit_screen.dart',
      widget: 'InvoiceEditLayout',
      button: 'invoiceDraftPreviewButton',
      eInvoice: true,
    ),
    'quotes': (
      layout: 'lib/ui/features/quotes/widgets/edit/quote_edit_layout.dart',
      screen: 'lib/ui/features/quotes/views/quote_edit_screen.dart',
      widget: 'QuoteEditLayout',
      button: 'quoteDraftPreviewButton',
      eInvoice: false,
    ),
    'credits': (
      layout: 'lib/ui/features/credits/widgets/edit/credit_edit_layout.dart',
      screen: 'lib/ui/features/credits/views/credit_edit_screen.dart',
      widget: 'CreditEditLayout',
      button: 'creditDraftPreviewButton',
      eInvoice: true,
    ),
    'purchase orders': (
      layout:
          'lib/ui/features/purchase_orders/widgets/edit/purchase_order_edit_layout.dart',
      screen:
          'lib/ui/features/purchase_orders/views/purchase_order_edit_screen.dart',
      widget: 'PurchaseOrderEditLayout',
      button: 'purchaseOrderDraftPreviewButton',
      eInvoice: false,
    ),
    'recurring invoices': (
      layout:
          'lib/ui/features/recurring_invoices/widgets/edit/recurring_invoice_edit_layout.dart',
      screen:
          'lib/ui/features/recurring_invoices/views/recurring_invoice_edit_screen.dart',
      widget: 'RecurringInvoiceEditLayout',
      button: 'recurringInvoiceDraftPreviewButton',
      eInvoice: true,
    ),
  };

  group('the shared strip', () {
    test('drops M3\'s 52 px leading offset', () {
      // `TabAlignment.startOffset` is the M3 default for a scrollable TabBar,
      // so the failure mode is writing nothing at all — no grep for
      // `startOffset` could ever find it. It cannot live in `theme.dart`
      // either: `TabAlignment.start` ASSERTS on a non-scrollable TabBar, and
      // the app has three of those.
      expect(codeOf(strip), contains('tabAlignment: TabAlignment.start'));
    });

    test('says when it still scrolls', () {
      // German, 360 px phones and large text still overflow. Before #140 none
      // of the five strips had a fade, a scroll controller or a reveal: the
      // last tab was simply cut off.
      expect(codeOf(strip), contains('ScrollEdgeFades('));
    });

    test('sizes its controller from the tab list, and can resize it', () {
      final code = codeOf(strip);
      expect(
        code,
        contains('TabController(length: widget.tabs.length'),
        reason: 'a hardcoded length goes stale the moment a tab is gated',
      );
      expect(code, contains('void didUpdateWidget(BillingDocEditTabStrip'));
      // `SingleTickerProviderStateMixin.createTicker` asserts `_ticker ==
      // null` and never resets it, so rebuilding the controller throws
      // "multiple tickers were created" on exactly the resize this handles.
      expect(code, isNot(contains('SingleTickerProviderStateMixin')));
      expect(code, contains('TickerProviderStateMixin'));
    });
  });

  docs.forEach((name, doc) {
    group(name, () {
      test('renders its narrow tabs through the shared strip', () {
        final code = codeOf(doc.layout);
        expect(code, contains('BillingDocEditTabStrip('));
        // A local TabBar would silently opt out of the alignment, the fades
        // and the controller resize all at once.
        expect(
          code,
          isNot(contains('isScrollable: true,\n              tabs')),
        );
        expect(code, isNot(contains('late TabController _tab')));
      });

      test('the PDF tab is gated, never unconditional', () {
        final code = codeOf(doc.layout);
        expect(
          code,
          contains('if (widget.showPdfTab) _Tab.pdf'),
          reason: 'the narrow strip has no room for it below 600 px',
        );
        // The parallel `tabs:` / `children:` lists this replaced could drop a
        // tab from one and not the other; the keyed switch cannot.
        expect(code, isNot(contains("Tab(text: context.tr('pdf'))")));
      });

      test('the screen computes ONE width and threads it to both halves', () {
        final code = codeOf(doc.screen);
        // The AppBar is built outside the body, so a second read inside the
        // layout would disagree with this one and render both chromes or
        // neither — CLAUDE.md's Tasks filter-bar rule.
        expect(code, contains('!Breakpoints.isWide(constraints)'));
        expect(code, contains('showPdfTab: !narrow'));
        expect(
          code,
          contains('${doc.button}(ctx, vm)'),
          reason:
              'dropping the button leaves the PDF unreachable on a phone, '
              'silently — the tab is already gone',
        );
        // Gated, or the >= 1024 desktop layout carries a button beside its
        // always-on inline PDF pane.
        expect(code, contains('leading: narrow'));
      });

      if (doc.eInvoice) {
        test('the E-Invoice tab is gated on the company, on BOTH widths', () {
          final code = codeOf(doc.layout);
          // Ungated since M3, against the file's own class doc. The narrow
          // strip and the desktop notes card must agree or a company sees the
          // form at one width and not the other.
          expect(code, contains('if (_showEInvoice) _Tab.eInvoice'));
          expect(
            code,
            contains('showEInvoice: _showEInvoice'),
            reason:
                'the desktop notes card takes the gate from the layout — '
                'resolving it twice lets the two widths disagree',
          );
          expectTabGated(doc.layout, 'e_invoice');

          // The seed mirror is refreshed only as a side effect of a
          // `resolved()` call, so a company that switches e-invoicing on
          // would keep the stale answer for the rest of the session.
          // `peek_is_seed_only_test.dart` fails the build on the attempt;
          // this says the same thing where the temptation lives.
          expect(code, contains('resolveEInvoiceTabVisible('));
          expect(code, isNot(contains('resolvedIfReady(')));
        });
      } else {
        test('has no E-Invoice tab to gate', () {
          expect(codeOf(doc.layout), isNot(contains("tr('e_invoice')")));
        });
      }
    });
  });

  test('the shared gate reads the async cascade, not the seed', () {
    final code = codeOf(
      'lib/ui/features/billing_shared/edit/e_invoice_tab_gate.dart',
    );
    expect(code, contains('settings.resolved('));
    expect(code, isNot(contains('resolvedIfReady(')));
  });

  test('the preview button previews the DRAFT, not the saved record', () {
    // `⋮ → PDF → View PDF` navigates to `/invoices/:id/pdf`, which renders
    // what the server last stored. The tab this replaced posted the dirty
    // draft to `live_preview`, and on a create form the saved document does
    // not exist at all.
    final code = codeOf(
      'lib/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart',
    );
    expect(code, contains('BillingDocPdfScreen('));
    expect(code, isNot(contains('context.go(')));
  });
}

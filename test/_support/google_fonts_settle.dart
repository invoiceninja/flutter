import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lets the fonts `GoogleFonts.getFont` started finish loading, then runs the
/// re-layout frame their `fontsChange` schedules.
///
/// The invoice designer's page renders its font through google_fonts, and its
/// default, Roboto, comes from a bundled asset: a real read on the real event
/// loop, outside the test's fake clock. The finished load sends `fontsChange`,
/// and `RelayoutWhenSystemFontsChangeMixin` schedules a frame for it. A test
/// that ends before that frame fails with "An animation is still running even
/// after the widget tree was disposed". On Flutter 3.47 the load happened to
/// land inside a later pump; on 3.50 it lands after the test body. Call this
/// right after pumping a widget that shows a designer page.
Future<void> settleGoogleFonts(WidgetTester tester) async {
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pump();
}

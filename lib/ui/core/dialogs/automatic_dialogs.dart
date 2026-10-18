/// What this launch has already put in front of the user unasked.
///
/// A launch that opened with the local-data recovery notice or the
/// missing-name prompt has asked enough of the user; the mobile-app promo
/// waits for a launch that hasn't (docs/mobile-app-promo.md). Process-wide,
/// not per shell: the shell unmounts on a sign-out, and a second sign-in in
/// the same launch is still the same launch.
abstract final class AutomaticDialogs {
  static bool _shownThisLaunch = false;

  /// True once anything has called [noteShown] in this process.
  static bool get shownThisLaunch => _shownThisLaunch;

  /// Called by each automatic dialog as it opens.
  static void noteShown() => _shownThisLaunch = true;

  /// For tests — a process-wide flag otherwise leaks between them.
  static void resetForTest() => _shownThisLaunch = false;
}

/// Where the two shared tabs sit in every detail strip that leads with them.
///
/// The two leading tabs are addressed by position: every host that mounts them
/// puts them first, so an index is exact. Naming the two that other code aims
/// at keeps the magic number in one place and gives
/// `comments_surface_wiring_test.dart` something to check membership against:
/// a bare `select(0)` still passes that test on a host whose Comments tab has
/// moved, a named constant cannot.
///
/// Every *other* tab is module-gated on at least one host, so its index moves
/// with the company's settings. Those are addressed by the ids at the foot of
/// this file (`EntityDetailTab.id` / `TabSelectionController.selectId`).
///
/// The values are pinned to the strip's real shape by that same test, which
/// already asserts entry 0 is the `commentsOnly` tab and entry 1 the Activity
/// one on all eleven hosts.
///
/// There is deliberately **no** landing-tab constant: the hosts' `initialIndex:
/// 2` is asserted as a literal string, and converting it would buy nothing.
library;

/// The Comments tab — first on every host that mounts `EntityActivityTab`.
const int kCommentsTabIndex = 0;

/// The Activity tab — always immediately after Comments; the two are one feed
/// rendered two ways.
const int kActivityTabIndex = 1;

/// Stable names for `EntityDetailTab.id`. Shared across entities so "the
/// Invoices tab" means the same thing on a client and on a project, and so
/// `comments_surface_wiring_test.dart` can check every `selectId(` argument
/// against one list.
abstract final class DetailTabIds {
  static const String comments = 'comments';
  static const String activity = 'activity';
  static const String overview = 'overview';
  static const String invoices = 'invoices';
  static const String quotes = 'quotes';
  static const String payments = 'payments';
  static const String recurringInvoices = 'recurring_invoices';
  static const String credits = 'credits';
  static const String projects = 'projects';
  static const String tasks = 'tasks';
  static const String expenses = 'expenses';
  static const String ledger = 'ledger';
  static const String locations = 'locations';
  static const String documents = 'documents';
  static const String emailHistory = 'email_history';
  static const String systemLogs = 'system_logs';
  static const String purchaseOrders = 'purchase_orders';
  static const String recurringExpenses = 'recurring_expenses';
  static const String transactions = 'transactions';
  static const String timeLog = 'time_log';
  static const String history = 'history';
  static const String schedule = 'schedule';
  static const String analytics = 'analytics';
  static const String settings = 'settings';
}

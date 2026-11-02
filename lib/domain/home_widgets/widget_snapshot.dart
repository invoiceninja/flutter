/// The file the app writes for its home-screen widgets, and the only thing
/// they read — see `docs/home-screen-widgets.md`.
///
/// A leaf: no Flutter, no Drift, nothing from `lib/ui`. Everything in it is
/// display-ready — money pre-formatted by the company's `Formatter`, labels
/// pre-translated — because the widget code (Swift, Kotlin) formats nothing
/// but a live clock and "N days late". Every field is optional on the native
/// side, and an unknown figure is `null`, never `0`.
///
/// **Bump [kWidgetSnapshotVersion] only for a change an older widget would
/// misread.** Adding a field is not one; renaming or re-typing one is. A
/// widget that meets a newer version than it knows says "Update Invoice
/// Ninja" instead of guessing.
library;

const int kWidgetSnapshotVersion = 1;

/// The periods a Business snapshot widget can show. The wire value is the
/// dashboard preset's server name, which the native config pickers list.
enum WidgetPeriod {
  thisMonth('this_month'),
  last30Days('last30_days'),
  thisYear('this_year');

  const WidgetPeriod(this.wire);
  final String wire;

  static WidgetPeriod? fromWire(String? value) {
    for (final p in values) {
      if (p.wire == value) return p;
    }
    return null;
  }
}

/// The widget kinds the native side can report as installed. Matches the
/// WidgetKit `kind` strings and the Android provider names.
enum WidgetKind {
  snapshot('snapshot'),
  attention('attention'),
  timer('timer');

  const WidgetKind(this.wire);
  final String wire;

  static WidgetKind? fromWire(String? value) {
    for (final k in values) {
      if (k.wire == value) return k;
    }
    return null;
  }
}

class WidgetSnapshot {
  const WidgetSnapshot({
    required this.signedIn,
    this.userId = '',
    this.appLock = false,
    this.rtl = false,
    this.activeCompanyId = '',
    this.strings = const {},
    this.companies = const [],
  });

  /// What every session end leaves behind: the widgets say "Sign in", not
  /// "Open Invoice Ninja to load your data" (a missing file).
  const WidgetSnapshot.signedOut({this.strings = const {}, this.rtl = false})
    : signedIn = false,
      userId = '',
      appLock = false,
      activeCompanyId = '',
      companies = const [];

  final bool signedIn;
  final String userId;

  /// Whether App Lock (biometric unlock) is on — what a widget's "Hide
  /// amounts: Automatic" follows.
  final bool appLock;

  /// The app's language reads right to left. The widget lays out by this, not
  /// by the device's language, which can differ.
  final bool rtl;
  final String activeCompanyId;

  /// Every user-visible text the widgets draw, keyed by its translation key,
  /// in the app's language.
  final Map<String, String> strings;
  final List<WidgetCompany> companies;

  Map<String, Object?> toJson({required DateTime writtenAt}) => {
    'v': kWidgetSnapshotVersion,
    'writtenAt': writtenAt.millisecondsSinceEpoch,
    'signedIn': signedIn,
    if (signedIn) 'userId': userId,
    'appLock': appLock,
    'rtl': rtl,
    if (signedIn) 'activeCompanyId': activeCompanyId,
    'strings': strings,
    'companies': [for (final c in companies) c.toJson()],
  };

  /// The payload without its write time — what the publisher compares, so an
  /// unchanged snapshot is not rewritten (and no widget reloaded) just because
  /// the clock moved.
  Map<String, Object?> comparable() =>
      toJson(writtenAt: DateTime.fromMillisecondsSinceEpoch(0));
}

class WidgetCompany {
  const WidgetCompany({
    required this.id,
    required this.name,
    this.accent = '',
    this.canViewDashboard = false,
    this.figures,
    this.timers = const [],
    this.runningCount = 0,
    this.recentTasks = const [],
    this.today,
  });

  final String id;
  final String name;

  /// `#rrggbb`, or empty. Used only to tell companies apart — never for paid
  /// or past due.
  final String accent;
  final bool canViewDashboard;

  /// Null when the user can't see dashboard figures, or nothing is cached yet.
  final WidgetFigures? figures;

  /// Running timers, newest first, at most [kWidgetMaxTimers].
  final List<WidgetTimer> timers;

  /// Every running timer of the user's, of which [timers] is the newest few:
  /// the widget's "+N running" (`runningCount - timers.length`). Added in v1
  /// without a version bump — an older widget ignores it.
  final int runningCount;

  /// The most recently worked tasks that are not running — the idle Timer
  /// widget's "resume" rows.
  final List<WidgetTask> recentTasks;

  /// The user's time worked today, for the Timer widget's "Today" line —
  /// null when its task rows weren't read.
  final WidgetToday? today;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'accent': accent,
    'canViewDashboard': canViewDashboard,
    if (figures != null) 'figures': figures!.toJson(),
    'timers': [for (final t in timers) t.toJson()],
    'runningCount': runningCount,
    'recentTasks': [for (final t in recentTasks) t.toJson()],
    if (today != null) 'today': today!.toJson(),
  };
}

/// Time worked today, as of the snapshot.
///
/// [doneSeconds] counts **finished** entries only, clipped to the day: the
/// widget adds each listed running timer itself
/// (`now - max(runningSince, midnight)`), so the total keeps ticking without
/// a write. A widget whose local day is no longer [date] hides the line.
class WidgetToday {
  const WidgetToday({required this.date, required this.doneSeconds});

  /// `yyyy-MM-dd`, the device's local day.
  final String date;
  final int doneSeconds;

  Map<String, Object?> toJson() => {'date': date, 'doneSeconds': doneSeconds};
}

const int kWidgetMaxTimers = 3;
const int kWidgetRecentTasks = 2;
const int kWidgetAttentionRows = 5;

/// A pre-formatted amount: the full form and the compact one (`$12.4K`) for a
/// small widget or the lock screen.
class WidgetMoney {
  const WidgetMoney({required this.text, required this.compact});

  final String text;
  final String compact;

  Map<String, Object?> toJson() => {'text': text, 'compact': compact};
}

class WidgetFigures {
  const WidgetFigures({
    this.fetchedAt,
    this.outstanding,
    this.periods = const {},
    this.attention,
    this.inCurrency = '',
  });

  /// When the oldest figure here was fetched — the "Updated 3 hr ago" stamp.
  /// Never the snapshot's write time: an offline launch rewrites the file
  /// from old cache rows.
  final DateTime? fetchedAt;
  final WidgetOutstanding? outstanding;
  final Map<WidgetPeriod, WidgetPeriodFigures> periods;
  final WidgetAttention? attention;

  /// The currency code the figures were converted into ("in USD"), or empty
  /// when the company has only its own currency.
  final String inCurrency;

  Map<String, Object?> toJson() => {
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.millisecondsSinceEpoch,
    if (outstanding != null) 'outstanding': outstanding!.toJson(),
    'periods': {for (final e in periods.entries) e.key.wire: e.value.toJson()},
    if (attention != null) 'attention': attention!.toJson(),
    if (inCurrency.isNotEmpty) 'inCurrency': inCurrency,
  };
}

class WidgetOutstanding {
  const WidgetOutstanding({
    required this.amount,
    required this.unpaidCount,
    this.pastDueCount,
    this.pastDueExact = true,
    this.pastDueAmount,
    this.pastDueShare,
  });

  final WidgetMoney amount;
  final int unpaidCount;

  /// Null while the past-due list has not loaded.
  final int? pastDueCount;

  /// False when [pastDueCount] is a lower bound ("50+").
  final bool pastDueExact;

  /// Only when proven: every past-due invoice fetched, all in one currency.
  final WidgetMoney? pastDueAmount;

  /// [pastDueAmount] as a share of [amount], 0–1 to two places, for the
  /// widgets' past-due bar. Only when both are in one currency and the
  /// amount is above zero.
  final double? pastDueShare;

  Map<String, Object?> toJson() => {
    'amount': amount.toJson(),
    'unpaidCount': unpaidCount,
    if (pastDueCount != null) 'pastDueCount': pastDueCount,
    'pastDueExact': pastDueExact,
    if (pastDueAmount != null) 'pastDueAmount': pastDueAmount!.toJson(),
    if (pastDueShare != null) 'pastDueShare': pastDueShare,
  };
}

class WidgetPeriodFigures {
  const WidgetPeriodFigures({
    required this.label,
    required this.name,
    required this.endsOn,
    this.fetchedAt,
    this.invoices,
    this.payments,
    this.expenses,
  });

  /// The period as the user picked it ("This Month").
  final String label;

  /// The concrete period ("October", "2026") — shown once the clock has left
  /// it, so last month's numbers never sit under "This Month".
  final String name;

  /// `yyyy-MM-dd`, the period's last day as fetched.
  final String endsOn;
  final DateTime? fetchedAt;
  final WidgetFigure? invoices;
  final WidgetFigure? payments;

  /// Null when the user's expense permission or module hides it in the app.
  final WidgetFigure? expenses;

  Map<String, Object?> toJson() => {
    'label': label,
    'name': name,
    'endsOn': endsOn,
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.millisecondsSinceEpoch,
    if (invoices != null) 'invoices': invoices!.toJson(),
    if (payments != null) 'payments': payments!.toJson(),
    if (expenses != null) 'expenses': expenses!.toJson(),
  };
}

class WidgetFigure {
  const WidgetFigure({required this.amount, this.deltaPct, this.good});

  final WidgetMoney amount;

  /// Against the same elapsed span of the previous period. Null when there is
  /// nothing honest to compare (see `trendFor`).
  final int? deltaPct;

  /// Whether the change is the good direction (spending less is good).
  final bool? good;

  Map<String, Object?> toJson() => {
    ...amount.toJson(),
    if (deltaPct != null) 'deltaPct': deltaPct,
    if (good != null) 'good': good,
  };
}

class WidgetAttention {
  const WidgetAttention({
    this.pastDue = const [],
    this.dueSoon = const [],
    this.nextDue,
  });

  final List<WidgetInvoiceRow> pastDue;
  final List<WidgetInvoiceRow> dueSoon;

  /// The next invoice to fall due however far off — the quiet line on a day
  /// with nothing past due.
  final WidgetInvoiceRow? nextDue;

  Map<String, Object?> toJson() => {
    'pastDue': [for (final r in pastDue) r.toJson()],
    'dueSoon': [for (final r in dueSoon) r.toJson()],
    if (nextDue != null) 'nextDue': nextDue!.toJson(),
  };
}

class WidgetInvoiceRow {
  const WidgetInvoiceRow({
    required this.id,
    required this.number,
    required this.client,
    required this.amount,
    this.lateSince,
    this.dueOn,
  });

  final String id;
  final String number;
  final String client;
  final WidgetMoney amount;

  /// `yyyy-MM-dd` the lateness counts from — the deposit's date when only the
  /// deposit is late (`daysLate`). The widget works out "12 days late" itself
  /// so it stays right after midnight.
  final String? lateSince;

  /// `yyyy-MM-dd` the next thing on it falls due.
  final String? dueOn;

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'client': client,
    'amount': amount.toJson(),
    if (lateSince != null) 'lateSince': lateSince,
    if (dueOn != null) 'dueOn': dueOn,
  };
}

class WidgetTimer {
  const WidgetTimer({
    required this.taskId,
    required this.description,
    required this.client,
    required this.runningSince,
    required this.priorSeconds,
    this.canStop = false,
  });

  final String taskId;
  final String description;
  final String client;

  /// When the running entry started. Also the stop command's guard: a stop is
  /// dropped if the task's running entry no longer starts here.
  final DateTime runningSince;

  /// Worked time before the running entry — the clock shows this plus the
  /// time since [runningSince].
  final int priorSeconds;

  /// Whether this user may stop it. A teammate's timer is listed without a
  /// Stop button — the server refuses the save (`TaskActions.canTimeTask`).
  final bool canStop;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'description': description,
    'client': client,
    'runningSince': runningSince.millisecondsSinceEpoch,
    'priorSeconds': priorSeconds,
    'canStop': canStop,
  };
}

class WidgetTask {
  const WidgetTask({
    required this.taskId,
    required this.description,
    required this.client,
  });

  final String taskId;
  final String description;
  final String client;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    'description': description,
    'client': client,
  };
}

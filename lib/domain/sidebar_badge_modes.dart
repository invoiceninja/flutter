/// What the count badge next to a sidebar row actually counts.
///
/// The rail has always shown one number per entity — "every row we have
/// cached". Issue #9 asked for that number to become a *choice*: a user who
/// lives in the app all day wants the sidebar to read like an email inbox,
/// where a number means "work waiting for you", not "size of the archive".
///
/// So every sidebar row picks a **mode** from the list declared here, stored
/// device-locally by `SidebarBadgeModeController`. Every mode is answerable
/// from columns already denormalized into Drift — the badge never issues a
/// network call.
///
/// Two ids are universal: [kBadgeModeTotal] (the default, and what every
/// install shows today) and [kBadgeModeNone], which hides the badge entirely.
library;

/// Colour weight of a badge. Maps to `InTheme` tokens in the widget layer —
/// deliberately an enum here so this file stays free of a UI import.
///
/// The tones mirror the language the status pills already use, so a red
/// sidebar badge reads the same as a red status pill: [danger] is
/// `overdue`/`overdueSoft`, [warning] is `warning`/`warningSoft` (what the
/// products list already uses for low stock), [muted] is `draft`/`draftSoft`,
/// and [neutral] keeps the badge exactly as it renders today.
enum SidebarBadgeTone { neutral, warning, danger, muted }

/// One selectable counter for a sidebar row.
class SidebarBadgeMode {
  const SidebarBadgeMode(
    this.id, {
    required this.labelKey,
    this.tone = SidebarBadgeTone.neutral,
    this.requiresInventoryTracking = false,
  });

  /// Persisted token. **Never rename a shipped id** — it's what lands in
  /// `nav_state.sidebar_badge_modes_json`. Renaming orphans the user's choice
  /// (the controller drops unknown ids back to [kBadgeModeTotal], so it
  /// degrades quietly rather than crashing, but the setting is still lost).
  final String id;

  /// Localization key for the picker label and the badge tooltip. Named (and
  /// spelled out even when it matches [id]) because the settings-search
  /// consistency test scans source for literal `labelKey: '…'` occurrences —
  /// that scan is what lets "overdue" in settings search find this feature.
  final String labelKey;

  final SidebarBadgeTone tone;

  /// Only the two product stock modes set this — on-hand stock is meaningless
  /// when the company has `track_inventory` off, so both pickers drop these
  /// modes for such a company. A plain flag rather than a general
  /// `bool Function(Company)` because exactly one gate exists; generalize when
  /// a second one shows up.
  final bool requiresInventoryTracking;
}

/// Count every active row — the default, and what the badge did before this
/// existed.
const String kBadgeModeTotal = 'total';

/// Hide the badge on this row.
const String kBadgeModeNone = 'none';

/// Rows assigned to the signed-in user. Offered on every entity that carries
/// an assignment; the DAOs that have no `assigned_user_id` column (tasks,
/// expenses) read it out of the payload JSON instead.
const String kBadgeModeAssignedToMe = 'assigned_to_me';

const SidebarBadgeMode _total = SidebarBadgeMode(
  kBadgeModeTotal,
  labelKey: 'total',
);
const SidebarBadgeMode _none = SidebarBadgeMode(
  kBadgeModeNone,
  labelKey: 'none',
);
const SidebarBadgeMode _assignedToMe = SidebarBadgeMode(
  kBadgeModeAssignedToMe,
  labelKey: 'assigned_to_me',
);

/// Fallback for any entity that declares no modes of its own — total, or
/// nothing. Every sidebar entity passes an explicit list, so in practice this
/// covers only the settings-only modules.
const List<SidebarBadgeMode> kDefaultBadgeModes = [_total, _none];

// Per-entity lists. Convention: `total` first, `none` last, the most
// actionable status right after `total` so it's the obvious pick.

const List<SidebarBadgeMode> kClientBadgeModes = [
  _total,
  SidebarBadgeMode(
    'overdue',
    labelKey: 'overdue',
    tone: SidebarBadgeTone.danger,
  ),
  SidebarBadgeMode(
    'outstanding',
    labelKey: 'outstanding',
    tone: SidebarBadgeTone.warning,
  ),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kProductBadgeModes = [
  _total,
  SidebarBadgeMode(
    'out_of_stock',
    labelKey: 'out_of_stock',
    tone: SidebarBadgeTone.danger,
    requiresInventoryTracking: true,
  ),
  SidebarBadgeMode(
    'low_stock',
    labelKey: 'low_stock',
    tone: SidebarBadgeTone.warning,
    requiresInventoryTracking: true,
  ),
  _none,
];

const List<SidebarBadgeMode> kInvoiceBadgeModes = [
  _total,
  SidebarBadgeMode(
    'overdue',
    labelKey: 'overdue',
    tone: SidebarBadgeTone.danger,
  ),
  SidebarBadgeMode(
    'unpaid',
    labelKey: 'unpaid',
    tone: SidebarBadgeTone.warning,
  ),
  SidebarBadgeMode('draft', labelKey: 'draft', tone: SidebarBadgeTone.muted),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kRecurringInvoiceBadgeModes = [
  _total,
  SidebarBadgeMode('active', labelKey: 'active'),
  SidebarBadgeMode('paused', labelKey: 'paused', tone: SidebarBadgeTone.muted),
  SidebarBadgeMode('draft', labelKey: 'draft', tone: SidebarBadgeTone.muted),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kPaymentBadgeModes = [
  _total,
  SidebarBadgeMode(
    'unapplied',
    labelKey: 'unapplied',
    tone: SidebarBadgeTone.warning,
  ),
  SidebarBadgeMode('failed', labelKey: 'failed', tone: SidebarBadgeTone.danger),
  SidebarBadgeMode(
    'pending',
    labelKey: 'pending',
    tone: SidebarBadgeTone.muted,
  ),
  _none,
];

const List<SidebarBadgeMode> kQuoteBadgeModes = [
  _total,
  SidebarBadgeMode(
    'expired',
    labelKey: 'expired',
    tone: SidebarBadgeTone.danger,
  ),
  SidebarBadgeMode('draft', labelKey: 'draft', tone: SidebarBadgeTone.muted),
  SidebarBadgeMode('sent', labelKey: 'sent'),
  SidebarBadgeMode('approved', labelKey: 'approved'),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kCreditBadgeModes = [
  _total,
  SidebarBadgeMode(
    'unapplied',
    labelKey: 'unapplied',
    tone: SidebarBadgeTone.warning,
  ),
  SidebarBadgeMode('draft', labelKey: 'draft', tone: SidebarBadgeTone.muted),
  SidebarBadgeMode('sent', labelKey: 'sent'),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kProjectBadgeModes = [
  _total,
  SidebarBadgeMode(
    'overdue',
    labelKey: 'overdue',
    tone: SidebarBadgeTone.danger,
  ),
  SidebarBadgeMode(
    'over_budget',
    labelKey: 'over_budget',
    tone: SidebarBadgeTone.warning,
  ),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kTaskBadgeModes = [
  _total,
  SidebarBadgeMode('running', labelKey: 'running'),
  SidebarBadgeMode(
    'uninvoiced',
    labelKey: 'uninvoiced',
    tone: SidebarBadgeTone.muted,
  ),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kVendorBadgeModes = [
  _total,
  SidebarBadgeMode(
    'unpaid_expenses',
    labelKey: 'unpaid_expenses',
    tone: SidebarBadgeTone.danger,
  ),
  SidebarBadgeMode(
    'open_purchase_orders',
    labelKey: 'open_purchase_orders',
    tone: SidebarBadgeTone.warning,
  ),
  _none,
];

const List<SidebarBadgeMode> kPurchaseOrderBadgeModes = [
  _total,
  SidebarBadgeMode('draft', labelKey: 'draft', tone: SidebarBadgeTone.muted),
  SidebarBadgeMode('sent', labelKey: 'sent'),
  SidebarBadgeMode('accepted', labelKey: 'accepted'),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kExpenseBadgeModes = [
  _total,
  SidebarBadgeMode('unpaid', labelKey: 'unpaid', tone: SidebarBadgeTone.danger),
  SidebarBadgeMode(
    'pending',
    labelKey: 'pending',
    tone: SidebarBadgeTone.muted,
  ),
  SidebarBadgeMode('logged', labelKey: 'logged', tone: SidebarBadgeTone.muted),
  _assignedToMe,
  _none,
];

const List<SidebarBadgeMode> kRecurringExpenseBadgeModes = [
  _total,
  SidebarBadgeMode(
    'pending',
    labelKey: 'pending',
    tone: SidebarBadgeTone.warning,
  ),
  SidebarBadgeMode('active', labelKey: 'active'),
  SidebarBadgeMode('paused', labelKey: 'paused', tone: SidebarBadgeTone.muted),
  SidebarBadgeMode('draft', labelKey: 'draft', tone: SidebarBadgeTone.muted),
  _none,
];

const List<SidebarBadgeMode> kTransactionBadgeModes = [
  _total,
  SidebarBadgeMode(
    'unmatched',
    labelKey: 'unmatched',
    tone: SidebarBadgeTone.muted,
  ),
  SidebarBadgeMode('matched', labelKey: 'matched'),
  _none,
];

/// The subset of [modes] this company can actually use. Today that's only the
/// product stock counters, which mean nothing with inventory tracking off —
/// offering them would be offering a counter guaranteed to read zero.
///
/// Both pickers (the row's right-click menu and the Sidebar counters settings
/// card) filter through this, so they can't disagree about what's on offer.
List<SidebarBadgeMode> availableBadgeModes(
  List<SidebarBadgeMode> modes, {
  required bool trackInventory,
}) {
  if (trackInventory) return modes;
  return [
    for (final m in modes)
      if (!m.requiresInventoryTracking) m,
  ];
}

/// Every per-entity list declared above. Lets the controller and the coherence
/// test walk the whole catalog without re-listing it.
const List<List<SidebarBadgeMode>> kAllSidebarBadgeModeLists = [
  kClientBadgeModes,
  kProductBadgeModes,
  kInvoiceBadgeModes,
  kRecurringInvoiceBadgeModes,
  kPaymentBadgeModes,
  kQuoteBadgeModes,
  kCreditBadgeModes,
  kProjectBadgeModes,
  kTaskBadgeModes,
  kVendorBadgeModes,
  kPurchaseOrderBadgeModes,
  kExpenseBadgeModes,
  kRecurringExpenseBadgeModes,
  kTransactionBadgeModes,
];

/// Every mode id offered anywhere. The controller drops a stored id that isn't
/// in here, so a mode renamed or removed in a later release leaves that row on
/// its default instead of persisting a dead value.
final Set<String> kSidebarBadgeModeIds = {
  for (final list in kAllSidebarBadgeModeLists)
    for (final mode in list) mode.id,
};

/// The mode labels worth surfacing in settings search, so typing "overdue"
/// finds the Sidebar counters card — without this the feature is invisible to
/// search, because the rows render `context.tr(<variable>)` rather than a
/// literal the catalog's source scan can see.
///
/// **A curated subset, deliberately.** The generic status words every billing
/// doc shares — `total`, `none`, `active`, `sent`, `draft`, `paused`,
/// `pending`, `failed`, `approved`, `expired`, `accepted`, `logged`,
/// `running`, `matched` — are left out. `settings_screen.dart` renders the
/// whole catalog as its resting state when the query is empty, so including
/// them would pad that list with a dozen-plus one-word rows all pointing at the
/// same page, and nobody searches settings for "Sent" hoping to find a sidebar
/// counter. What's here is the vocabulary someone would actually type when
/// looking for *this* feature.
///
/// Hand-written because `kSettingsSearchCatalog` is `const`; a test asserts
/// every entry is still a real mode `labelKey`.
const List<String> kSidebarBadgeModeSearchKeys = [
  'assigned_to_me',
  'overdue',
  'outstanding',
  'out_of_stock',
  'low_stock',
  'over_budget',
  'unapplied',
  'unpaid',
  'unpaid_expenses',
  'open_purchase_orders',
  'uninvoiced',
  'unmatched',
];

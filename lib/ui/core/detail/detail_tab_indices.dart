/// Where the two shared tabs sit in every detail strip that leads with them.
///
/// `EntityDetailTab` carries no id and no slug — a tab is identified by its
/// position and nothing else — so an index is the only handle a caller has.
/// Naming the two that other code aims at keeps the magic number in one place
/// and gives `comments_surface_wiring_test.dart` something to check membership
/// against: a bare `select(0)` still passes that test on a host whose Comments
/// tab has moved, a named constant cannot.
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

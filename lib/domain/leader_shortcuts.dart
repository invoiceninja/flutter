import 'package:admin/domain/entity_registry.dart' show FixedBranchKind;
import 'package:admin/domain/entity_type.dart';

/// One `G`-leader destination: the second key, and the branch it jumps to.
///
/// Exactly one of [entity] / [fixed] is set — the two kinds of
/// `StatefulShellRoute` branch (`EntityBranch` / `FixedBranch`).
class LeaderTarget {
  const LeaderTarget.entity(this.key, EntityType this.entity, this.labelKey)
    : fixed = null;
  const LeaderTarget.fixed(this.key, FixedBranchKind this.fixed, this.labelKey)
    : entity = null;

  /// The second key, as its uppercase printed letter — which is what
  /// `LogicalKeyboardKey.keyLabel` yields, so the match stays on the *logical*
  /// key and carries across keyboard layouts.
  final String key;

  final EntityType? entity;
  final FixedBranchKind? fixed;

  /// Translation key naming the destination, for the `?` dialog's letter →
  /// destination list.
  ///
  /// Carried here rather than resolved from `EntityRegistry.effectiveLabelKey`
  /// so this stays a leaf and the dialog needs no `Services`: its widget test
  /// pumps a fake that throws on every getter it has not been told to expect,
  /// deliberately, and a registry read there would either break it or make the
  /// entity rows silently vanish from the list. These mirror the `labelKey` of
  /// the matching entry in `kWiredEntityModules`; a drift is cosmetic (one
  /// word in one dialog), which is what makes the trade worth taking.
  final String labelKey;
}

/// The whole `G`-leader table, in the order the `?` dialog lists it.
///
/// **This is the only copy.** It used to be spelled out three times — the
/// shell's `_leaderTarget` switch, `in_sidebar`'s `_entityLeaderKey` /
/// `_fixedLeaderKey` (which drive the per-row `G`-then-x tooltips) and the `?`
/// dialog's hardcoded letter list — and the drift was invisible in every
/// direction: a missing sidebar entry is a working shortcut nobody can
/// discover, a missing dialog entry the same, and a sidebar hint with no
/// matching shell case is a documented shortcut that does nothing.
///
/// Letters are the destination's own first letter wherever that is free, and
/// otherwise a letter from inside the word (`J` = pro**j**ects, `Y` =
/// pa**y**ments, `O` = purchase **o**rders, `B` = **b**ank transactions).
/// Credits and the recurring pair are deliberately unbound: every letter in
/// "credits" is already taken, and inventing one for a destination whose name
/// does not contain it makes a shortcut that can only be looked up, never
/// remembered. Free letters, if you want to bind more: F H K L M N U W X Z.
///
/// Adding one is a single entry here; the shell, the sidebar hints and the
/// dialog all follow. A target whose module is off for the active company, or
/// whose permission the user lacks, is refused by `_goBranch` — so an entry
/// here is safe even for a destination not everyone can reach.
const kLeaderTargets = <LeaderTarget>[
  LeaderTarget.fixed('D', FixedBranchKind.dashboard, 'dashboard'),
  LeaderTarget.entity('C', EntityType.client, 'clients'),
  LeaderTarget.entity('P', EntityType.product, 'products'),
  LeaderTarget.entity('I', EntityType.invoice, 'invoices'),
  LeaderTarget.entity('Q', EntityType.quote, 'quotes'),
  LeaderTarget.entity('O', EntityType.purchaseOrder, 'purchase_orders'),
  LeaderTarget.entity('Y', EntityType.payment, 'payments'),
  LeaderTarget.entity('E', EntityType.expense, 'expenses'),
  LeaderTarget.entity('V', EntityType.vendor, 'vendors'),
  LeaderTarget.entity('T', EntityType.task, 'tasks'),
  LeaderTarget.entity('J', EntityType.project, 'projects'),
  LeaderTarget.entity('B', EntityType.transaction, 'transactions'),
  LeaderTarget.fixed('R', FixedBranchKind.reports, 'reports'),
  LeaderTarget.fixed('A', FixedBranchKind.activity, 'activity'),
  LeaderTarget.fixed('S', FixedBranchKind.settings, 'settings'),
];

final Map<String, LeaderTarget> _byKey = {
  for (final target in kLeaderTargets) target.key: target,
};

/// The target for a pressed second key, or null if that letter is unbound (the
/// shell then cancels the sequence and lets the key through).
LeaderTarget? leaderTargetForKey(String key) => _byKey[key.toUpperCase()];

/// The second key for an entity row's `G`-then-x hint, or null when that
/// entity has no leader jump.
String? leaderKeyForEntity(EntityType type) {
  for (final target in kLeaderTargets) {
    if (target.entity == type) return target.key;
  }
  return null;
}

/// The second key for a fixed row's `G`-then-x hint, or null when that branch
/// has no leader jump.
String? leaderKeyForFixed(FixedBranchKind kind) {
  for (final target in kLeaderTargets) {
    if (target.fixed == kind) return target.key;
  }
  return null;
}

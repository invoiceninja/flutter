import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';

/// Opens the Keyboard Shortcuts helper dialog. Lists every non-obvious
/// shortcut wired into the shell, master-detail pane, token search, and
/// form save scope so power users can find them without spelunking.
Future<void> showKeyboardShortcutsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _KeyboardShortcutsDialog(),
  );
}

class _KeyboardShortcutsDialog extends StatelessWidget {
  const _KeyboardShortcutsDialog();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final mod = platformModifierLabel();
    final navMod = platformHistoryModifierLabel();

    // Global + create rows come from the resolved bindings (override → default)
    // so the dialog matches the live `Shortcuts` map + the hint bar. Cleared
    // shortcuts and unbound create actions are omitted.
    final controller = context.read<Services>().keyboardShortcuts;
    List<_RowSpec> rowsFor(ShortcutGroup group) => [
      for (final def in kShortcutCatalog)
        if (def.group == group)
          if (controller.resolvedBinding(def.id) case final b?)
            _Row(
              keys: [b.displayGlyphs(mod).join()],
              description: context.tr(def.labelKey),
            ),
    ];

    final sections = <_Section>[
      _Section(
        icon: Icons.public_outlined,
        title: context.tr('shortcuts_global'),
        rows: [
          ...rowsFor(ShortcutGroup.general),
          // Bound "create X" shortcuts (empty by default — they ship unbound).
          ...rowsFor(ShortcutGroup.create),
          _LeaderRow(
            leader: 'G',
            targets: ['D', 'C', 'I', 'P', 'S', 'T'],
            description: context.tr('jump_to_section'),
          ),
        ],
      ),
      _Section(
        icon: Icons.list_alt,
        title: context.tr('shortcuts_records'),
        rows: [
          _Row(keys: ['N'], description: context.tr('new_record')),
          _Row(keys: ['E'], description: context.tr('edit_current')),
        ],
      ),
      _Section(
        icon: Icons.unfold_more,
        title: context.tr('shortcuts_navigation'),
        rows: [
          _Row(keys: ['J', '↓'], description: context.tr('next_record')),
          _Row(keys: ['K', '↑'], description: context.tr('previous_record')),
          _Row(keys: ['$navMod←'], description: context.tr('go_back')),
          _Row(keys: ['$navMod→'], description: context.tr('go_forward')),
          _Row(keys: ['F'], description: context.tr('toggle_full_screen')),
          _Row(keys: ['Esc'], description: context.tr('close')),
        ],
      ),
      _Section(
        icon: Icons.search,
        title: context.tr('shortcuts_search'),
        rows: [
          // `/` (focus search) is a global, remappable shortcut — it's rendered
          // dynamically in the Global section above (reflecting any rebind), so
          // it's intentionally not repeated here.
          _Row(keys: ['↑', '↓'], description: context.tr('move_selection')),
          _Row(keys: ['Enter'], description: context.tr('apply_filter')),
          _Row(
            keys: ['Backspace'],
            description: context.tr('remove_last_filter'),
          ),
          _Row(keys: ['Esc'], description: context.tr('dismiss_menu')),
        ],
      ),
      _Section(
        icon: Icons.edit_note,
        title: context.tr('shortcuts_forms'),
        rows: [
          _Row(keys: ['Enter'], description: context.tr('save')),
          _Row(keys: ['${mod}S'], description: context.tr('save')),
        ],
      ),
    ];

    // Desktop windows get a wider 2-column layout; narrow viewports
    // (phone, split-screen, small browser windows) stay single-column.
    // The threshold is window-wide via MediaQuery — dialogs render in
    // an overlay above the route tree, so the local LayoutBuilder
    // constraints inside a route don't apply here.
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final body = wide
        ? _twoColumnBody(context, sections)
        : _singleColumnBody(context, sections);

    // OverflowBar (AlertDialog's actions host) doesn't accept Flexible;
    // size-to-content via MainAxisSize.min and let the bar stack on the
    // rare overflow.
    final hint = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, size: 14, color: tokens.ink3),
        const SizedBox(width: 6),
        Text(
          context.tr('shortcuts_ignored_while_typing'),
          style: TextStyle(fontSize: 12, color: tokens.ink3),
        ),
      ],
    );

    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('keyboard_shortcuts')),
          const SizedBox(height: 4),
          // Seeds discovery of the hold-modifier hint bar — nothing else
          // tells users it exists.
          Row(
            children: [
              Icon(Icons.keyboard_outlined, size: 14, color: tokens.ink3),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  context.tr('hold_modifier_to_preview', {'modifier': mod}),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: tokens.ink3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(width: wide ? 880 : 480, child: body),
      // `spaceBetween` pins the hint at the leading edge and the Close
      // button at the trailing edge so they share the actions row.
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        hint,
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('close')),
        ),
      ],
    );
  }

  Widget _singleColumnBody(BuildContext context, List<_Section> sections) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) SizedBox(height: InSpacing.lg(context)),
            _SectionView(section: sections[i]),
          ],
        ],
      ),
    );
  }

  Widget _twoColumnBody(BuildContext context, List<_Section> sections) {
    // Section order from `build`: 0 Global, 1 Records, 2 Navigation,
    // 3 Search, 4 Forms. The split puts "anywhere" + "record actions"
    // on the left and "moving within a screen" on the right — close
    // enough in row count that neither column dwarfs the other.
    final left = [sections[0], sections[1], sections[4]];
    final right = [sections[2], sections[3]];
    final tokens = context.inTheme;
    return SingleChildScrollView(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _columnOfSections(context, left)),
            // Thin vertical rule between columns. The horizontal margin
            // is the breathing room each column gets from the divider;
            // combined it roughly equals the previous 24-px gap.
            Container(
              margin: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
              width: 1,
              color: tokens.border,
            ),
            Expanded(child: _columnOfSections(context, right)),
          ],
        ),
      ),
    );
  }

  Widget _columnOfSections(BuildContext context, List<_Section> sections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: InSpacing.lg(context)),
          _SectionView(section: sections[i]),
        ],
      ],
    );
  }
}

class _Section {
  const _Section({required this.icon, required this.title, required this.rows});

  final IconData icon;
  final String title;
  final List<_RowSpec> rows;
}

sealed class _RowSpec {
  const _RowSpec();
  String get description;
}

class _Row extends _RowSpec {
  const _Row({required this.keys, required this.description});

  final List<String> keys;
  @override
  final String description;
}

/// Two-key sequence (leader + one of several second keys). Renders as
/// `[G] then [D] [C] [I] [P] [S] [T]`.
class _LeaderRow extends _RowSpec {
  const _LeaderRow({
    required this.leader,
    required this.targets,
    required this.description,
  });

  final String leader;
  final List<String> targets;
  @override
  final String description;
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 16, color: tokens.ink2),
            const SizedBox(width: 8),
            Text(
              section.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tokens.ink2,
              ),
            ),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        for (final row in section.rows) _RowView(row: row),
      ],
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({required this.row});

  final _RowSpec row;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final keysWidget = switch (row) {
      _Row r => Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < r.keys.length; i++) ...[
            if (i > 0)
              Text(
                context.tr('or'),
                style: TextStyle(fontSize: 11, color: tokens.ink3),
              ),
            KeyCap(label: r.keys[i]),
          ],
        ],
      ),
      _LeaderRow r => Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          KeyCap(label: r.leader),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              context.tr('then'),
              style: TextStyle(fontSize: 11, color: tokens.ink3),
            ),
          ),
          for (var i = 0; i < r.targets.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  context.tr('or'),
                  style: TextStyle(fontSize: 11, color: tokens.ink3),
                ),
              ),
            KeyCap(label: r.targets[i]),
          ],
        ],
      ),
    };
    // Leader rows render more badges horizontally than plain rows, so
    // give them a wider key column. 130 px is comfortable for ⌘+letter
    // and "A or B" patterns; the leader sequence is full-width.
    final isLeader = row is _LeaderRow;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: isLeader
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                keysWidget,
                const SizedBox(height: 4),
                Text(
                  row.description,
                  style: TextStyle(fontSize: 13, color: tokens.ink2),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 130, child: keysWidget),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.description,
                    style: TextStyle(fontSize: 13, color: tokens.ink2),
                  ),
                ),
              ],
            ),
    );
  }
}

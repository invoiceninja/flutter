import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/utils/formatting.dart';

/// Floor for an editable cell — a **minimum**, never a fixed height. The
/// fields inside are 12–14 px `TextField`s with vertical content padding, so
/// their intrinsic height is already 49 px at normal text size and 57 px at
/// the app's 1.4x setting. Pinning the box to 36 px clipped them silently
/// (a `SizedBox` gives tight constraints — nothing is thrown, the field is
/// just sliced), which is why this shipped unnoticed.
const double _kCellMinHeight = 36;

/// Desktop time-log editor: a tabular layout with inline-editable cells
/// per entry plus a full-width description `TextField` underneath. Lives
/// alongside the mobile [TimeEntryRow] list — `TaskEditTimesSection`
/// switches between them on `Breakpoints.isWide(constraints)`.
///
/// Cells are private to this file (`_DateCell`, `_TimeCell`,
/// `_DurationCell`, `_BillableCell`, `_DeleteCell`). Promote to a shared
/// directory only when a second entity (invoice line items, expense
/// items) needs the same shapes.
class TimeEntryTable extends StatefulWidget {
  const TimeEntryTable({
    super.key,
    required this.vm,
    required this.locked,
    required this.onAddEntry,
    this.allowBillable = true,
    this.showDescription = true,
    this.formatter,
  });

  final TaskEditViewModel vm;
  final bool locked;

  /// Company `allow_billable_task_items` — hides the Billable column when
  /// false. `show_task_item_description` hides the per-row description.
  final bool allowBillable;
  final bool showDescription;

  /// Called when the trailing "+ Add row" tile is tapped. The parent
  /// section already owns the seed defaults; routing through the same
  /// handler keeps both paths consistent.
  final VoidCallback onAddEntry;

  final Formatter? formatter;

  // Column widths chosen to fill the time-log card content area while
  // keeping each cell's input text comfortably visible. The DATE column
  // accommodates long formats (`15/May/2026`, `Wed, May 14, 2026`); the
  // TIME and DURATION columns absorb the trailing picker icon without
  // crowding the value; BILLABLE fits its uppercase letter-spaced
  // header label without wrapping.
  static const double _wDate = 180;
  static const double _wTime = 132;
  static const double _wDuration = 140;
  static const double _wBillable = 96;
  static const double _wDelete = 40;
  static const double _gap = InSpacing.sm;

  @override
  State<TimeEntryTable> createState() => _TimeEntryTableState();
}

class _TimeEntryTableState extends State<TimeEntryTable> {
  // Tracks whether the most recent VM emission added an entry. Set in
  // `build()` by comparing the current `timeLog.length` against the prev
  // count; consumed by the first row's start cell as `autofocus: true`
  // so a freshly-added row grabs focus without the user reaching for
  // the mouse.
  int _prevTimeLogLength = 0;
  bool _autofocusNextBuild = false;

  @override
  void initState() {
    super.initState();
    _prevTimeLogLength = widget.vm.draft.timeLog.length;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final entries = widget.vm.draft.timeLog.reversed.toList(growable: false);

    // Detect an append (length grew) since the previous build and stash
    // the autofocus flag for the new latest row.
    final currentLength = widget.vm.draft.timeLog.length;
    if (currentLength > _prevTimeLogLength) {
      _autofocusNextBuild = true;
    }
    _prevTimeLogLength = currentLength;
    final shouldAutoFocus = _autofocusNextBuild;
    _autofocusNextBuild = false;

    // Display index of the entry a fresh add should focus. Normally the
    // last timeLog entry (display i == 0 in reversed order) — but when a
    // timer is running, `addEntry` deliberately inserts the new manual row
    // BEFORE the trailing running entry (the `.last`-based running checks
    // require the running entry to stay last), so the newest row sits at
    // display i == 1. Targeting i == 0 there would autofocus the RUNNING
    // entry's start cell, and a user typing immediately would silently
    // rewrite the running timer's start time.
    final focusDisplayIndex =
        (entries.isNotEmpty && entries.first.isRunning && entries.length > 1)
        ? 1
        : 0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Headers(tokens: tokens, allowBillable: widget.allowBillable),
        Divider(height: 1, color: tokens.border),
        // Empty-state text dropped on wide — with inline `+ Add row` the
        // user just clicks the affordance below instead of reading a
        // placeholder string.
        for (var i = 0; i < entries.length; i++)
          _EntryBlock(
            // The running entry (always timeLog.last) gets a STABLE key so a
            // manual entry inserted before it (see `addEntry`) doesn't bump
            // the running row onto a new positional key — which made the new
            // row REUSE an existing element (so its `autofocus` never fired)
            // and needlessly remounted the running row's live ticker. With a
            // stable running key, the new manual row gets a genuinely fresh
            // positional key → remounts → `autofocus` lands on it; on a
            // timer start/resume the new running row is the only fresh mount
            // and isn't the autofocus target, so nothing is focused (right —
            // a running "now" start cell isn't meant to be typed into).
            // Non-running rows keep their `timeLog`-index positional key
            // (stable under insert-before-running).
            // Running entries are keyed by their running-sequence rank, not
            // a constant: normally there's exactly one (the VM's timer
            // methods keep at most one running entry, always last) so this
            // is a stable `running-entry-0` — stable across the
            // insert-before-running case so the new manual row still gets a
            // fresh positional key and remounts for `autofocus`. But the
            // draft is seeded from `Task.timeLog` (server data) which the
            // app never validates, so a task with TWO open (`stop==null`)
            // entries — legacy / imported / other-client data — would
            // otherwise collide on one constant key and crash the table with
            // a duplicate-key error. Ranking keeps them unique.
            key: entries[i].isRunning
                ? ValueKey(
                    'running-entry-'
                    '${entries.take(i).where((e) => e.isRunning).length}',
                  )
                : ValueKey('entry-${widget.vm.draft.timeLog.length - 1 - i}'),
            vm: widget.vm,
            entry: entries[i],
            actualIndex: widget.vm.draft.timeLog.length - 1 - i,
            locked: widget.locked,
            formatter: widget.formatter,
            allowBillable: widget.allowBillable,
            showDescription: widget.showDescription,
            // Focus the newest entry's start cell on append (see
            // focusDisplayIndex above for the running-timer case).
            autofocusStart: i == focusDisplayIndex && shouldAutoFocus,
          ),
        if (!widget.locked) ...[
          Divider(height: 1, color: tokens.border),
          _AddTimeRow(onTap: widget.onAddEntry),
        ],
      ],
    );

    // Lock-state pattern matches `_ClientPicker` / `_StatusPicker` in
    // task_edit_layout.dart — IgnorePointer kills hit-testing without
    // graying out individual fields, Opacity reads as "muted content".
    return IgnorePointer(
      ignoring: widget.locked,
      child: Opacity(opacity: widget.locked ? 0.5 : 1, child: body),
    );
  }
}

class _Headers extends StatelessWidget {
  const _Headers({required this.tokens, this.allowBillable = true});
  final InTheme tokens;
  final bool allowBillable;

  Widget _label(
    BuildContext context,
    String key, {
    double? width,
    bool flex = false,
  }) {
    final text = Text(
      context.tr(key).toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: tokens.ink3,
        letterSpacing: 0.4,
      ),
    );
    if (flex) return Expanded(child: text);
    return SizedBox(width: width, child: text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Horizontal `InSpacing.lg(context)` matches the canonical card-interior
      // padding (CLAUDE.md § Design system (v2)) so the column labels
      // line up with the section header above and the cell values below.
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          _label(context, 'date', width: TimeEntryTable._wDate),
          const SizedBox(width: TimeEntryTable._gap),
          _label(context, 'start_time', width: TimeEntryTable._wTime),
          const SizedBox(width: TimeEntryTable._gap),
          _label(context, 'end_time', width: TimeEntryTable._wTime),
          const SizedBox(width: TimeEntryTable._gap),
          _label(context, 'duration', width: TimeEntryTable._wDuration),
          const SizedBox(width: TimeEntryTable._gap),
          if (allowBillable) ...[
            _label(context, 'billable', width: TimeEntryTable._wBillable),
            const SizedBox(width: TimeEntryTable._gap),
          ],
          // Delete column has no header label — the icon is self-evident.
          const SizedBox(width: TimeEntryTable._wDelete),
        ],
      ),
    );
  }
}

class _EntryBlock extends StatelessWidget {
  const _EntryBlock({
    super.key,
    required this.vm,
    required this.entry,
    required this.actualIndex,
    required this.locked,
    required this.formatter,
    this.allowBillable = true,
    this.showDescription = true,
    this.autofocusStart = false,
  });

  final TaskEditViewModel vm;
  final TimeEntry entry;
  final int actualIndex;
  final bool locked;
  final Formatter? formatter;
  final bool allowBillable;
  final bool showDescription;

  /// When `true`, the start `_TimeCell` requests focus on its first
  /// build. Set by `_TimeEntryTableState` for the newest row after an
  /// append so a freshly added row is immediately keyboard-typeable.
  final bool autofocusStart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isRunning = entry.isRunning;
    // Wrap in a FocusTraversalGroup so Tab inside the row walks
    // date → start → stop → duration → description in reading order,
    // then advances to the next row's date cell.
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Container(
        decoration: BoxDecoration(
          color: isRunning ? tokens.accentSoft.withValues(alpha: 0.3) : null,
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        // Horizontal `InSpacing.lg(context)` keeps each row's first cell aligned
        // with the column header and the section title above — the
        // canonical card-interior inset (CLAUDE.md § Design system v2).
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: TimeEntryTable._wDate,
                  child: _DateCell(
                    vm: vm,
                    entry: entry,
                    actualIndex: actualIndex,
                    formatter: formatter,
                  ),
                ),
                const SizedBox(width: TimeEntryTable._gap),
                SizedBox(
                  width: TimeEntryTable._wTime,
                  child: _TimeCell(
                    vm: vm,
                    entry: entry,
                    actualIndex: actualIndex,
                    field: _TimeField.start,
                    formatter: formatter,
                    autofocus: autofocusStart,
                  ),
                ),
                const SizedBox(width: TimeEntryTable._gap),
                SizedBox(
                  width: TimeEntryTable._wTime,
                  child: _TimeCell(
                    vm: vm,
                    entry: entry,
                    actualIndex: actualIndex,
                    field: _TimeField.stop,
                    formatter: formatter,
                  ),
                ),
                const SizedBox(width: TimeEntryTable._gap),
                SizedBox(
                  width: TimeEntryTable._wDuration,
                  child: _DurationCell(
                    vm: vm,
                    entry: entry,
                    actualIndex: actualIndex,
                  ),
                ),
                const SizedBox(width: TimeEntryTable._gap),
                if (allowBillable) ...[
                  SizedBox(
                    width: TimeEntryTable._wBillable,
                    child: _BillableCell(
                      vm: vm,
                      entry: entry,
                      actualIndex: actualIndex,
                    ),
                  ),
                  const SizedBox(width: TimeEntryTable._gap),
                ],
                SizedBox(
                  width: TimeEntryTable._wDelete,
                  child: locked
                      ? const SizedBox.shrink()
                      : _DeleteCell(vm: vm, actualIndex: actualIndex),
                ),
              ],
            ),
            if (showDescription) ...[
              const SizedBox(height: InSpacing.sm),
              _DescriptionField(vm: vm, entry: entry, actualIndex: actualIndex),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Cells
// ─────────────────────────────────────────────────────────────────────

/// Wraps the shared [InDateField] with the duration-shift / stop-preserve
/// logic specific to the time-log table: when the date moves, the
/// time-of-day is preserved and the stop time shifts alongside so the
/// entry's duration stays positive.
class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.vm,
    required this.entry,
    required this.actualIndex,
    required this.formatter,
  });

  final TaskEditViewModel vm;
  final TimeEntry entry;
  final int actualIndex;
  final Formatter? formatter;

  void _commit(DateTime? picked) {
    if (picked == null) return; // Date cell isn't clearable in this table.
    final hour = entry.start?.toLocal().hour ?? 9;
    final minute = entry.start?.toLocal().minute ?? 0;
    final nextStart = DateTime(
      picked.year,
      picked.month,
      picked.day,
      hour,
      minute,
    );
    DateTime? nextStop;
    final oldStop = entry.stop;
    final oldStart = entry.start;
    if (oldStop != null) {
      if (oldStart != null) {
        nextStop = nextStart.add(oldStop.difference(oldStart));
      } else {
        nextStop = oldStop;
      }
    }
    vm.updateEntry(
      actualIndex,
      entry.copyWith(start: nextStart, stop: nextStop),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A row floor, not a fixed height: `InDateField` is a 14 px `TextField`
    // with 14 px of vertical content padding, so it wants 49 px at normal
    // text size and 57 px at the app's 1.4x setting. `SizedBox(height: 36)`
    // silently crushed it — no overflow is thrown, the field is just sliced.
    // See CLAUDE.md § Design system — express floors as minHeight.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kCellMinHeight),
      child: InDateField(
        value: entry.start,
        onChanged: _commit,
        formatter: formatter,
      ),
    );
  }
}

enum _TimeField { start, stop }

/// Wraps the shared [InTimeField] with the start/stop selection,
/// running-entry disable, and the date-anchoring logic the time-log
/// row needs (the picked time-of-day is anchored to the entry's
/// existing date, not "today").
class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.vm,
    required this.entry,
    required this.actualIndex,
    required this.field,
    required this.formatter,
    this.autofocus = false,
  });

  final TaskEditViewModel vm;
  final TimeEntry entry;
  final int actualIndex;
  final _TimeField field;
  final Formatter? formatter;

  /// `autofocus: true` is set by `_TimeEntryTableState` on the start
  /// cell of a freshly-added entry so the user can type immediately
  /// after `+ Add row` without reaching for the mouse.
  final bool autofocus;

  bool get _isDisabled => field == _TimeField.stop && entry.isRunning;

  DateTime? get _value => field == _TimeField.start ? entry.start : entry.stop;

  TimeOfDay? get _valueAsTimeOfDay {
    final v = _value?.toLocal();
    if (v == null) return null;
    return TimeOfDay(hour: v.hour, minute: v.minute);
  }

  void _commit(TimeOfDay? picked) {
    if (picked == null || _isDisabled) return;
    final base = _value?.toLocal() ?? entry.start?.toLocal() ?? DateTime.now();
    final next = DateTime(
      base.year,
      base.month,
      base.day,
      picked.hour,
      picked.minute,
    );
    if (field == _TimeField.start) {
      vm.updateEntry(actualIndex, entry.copyWith(start: next));
    } else {
      vm.updateEntry(actualIndex, entry.copyWith(stop: next));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kCellMinHeight),
      child: InTimeField(
        value: _valueAsTimeOfDay,
        onChanged: _commit,
        formatter: formatter,
        enabled: !_isDisabled,
        autofocus: autofocus,
        // For running entries the stop cell shows the localized
        // "Running" label as its hint — the field is disabled, so the
        // user can't type, but the placeholder communicates state.
        hintText: _isDisabled ? context.tr('running') : null,
      ),
    );
  }
}

class _DurationCell extends StatefulWidget {
  const _DurationCell({
    required this.vm,
    required this.entry,
    required this.actualIndex,
  });

  final TaskEditViewModel vm;
  final TimeEntry entry;
  final int actualIndex;

  @override
  State<_DurationCell> createState() => _DurationCellState();
}

class _DurationCellState extends State<_DurationCell> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String _externalText = '';

  @override
  void initState() {
    super.initState();
    _externalText = _format(widget.entry);
    _controller = TextEditingController(text: _externalText);
    _focusNode.addListener(_onFocusChange);
  }

  /// Silent revert on blur — the contract `InDateField` / `InTimeField`
  /// implement, and which the newer `create_task_from_line_item_sheet`
  /// re-implements as `_syncDurationText`.
  ///
  /// [_onChanged] bails on unparseable input BEFORE touching [_externalText],
  /// so `didUpdateWidget`'s re-seed guard (`next != _externalText`) sees no
  /// change and never restores the text. Clearing the field therefore left it
  /// blank for the rest of the screen's life while the entry still held — and
  /// still saved and invoiced — its original duration. Typing garbage left the
  /// garbage on screen with the old value underneath it.
  void _onFocusChange() {
    if (_focusNode.hasFocus) return;
    final text = _controller.text;
    // Only UNPARSEABLE text is reverted. Comparing against `_format` instead
    // would clobber a perfectly good edit whenever `widget.entry` hasn't caught
    // up with the commit yet (the parent rebuild lands a frame later), and a
    // valid-but-differently-spelled entry — `2:30` for `2:30:00` — is not a
    // lie, so there is nothing to correct.
    if (parseDurationInput(text) != null) return;
    final canonical = _format(widget.entry);
    if (text == canonical) return;
    setState(() {
      _externalText = canonical;
      _controller.text = canonical;
    });
  }

  @override
  void didUpdateWidget(covariant _DurationCell old) {
    super.didUpdateWidget(old);
    final next = _format(widget.entry);
    // Re-seed only when the external value changed *and* the user isn't
    // currently typing (controller text out of sync). Avoids cursor
    // jumps on every parent rebuild.
    if (next != _externalText && next != _controller.text) {
      _externalText = next;
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  String _format(TimeEntry e) {
    if (e.isRunning) return ''; // running cell uses RunningDurationLabel
    final s = e.start;
    final p = e.stop;
    if (s == null || p == null) return '';
    return formatDuration(p.difference(s), compactDays: true);
  }

  void _onChanged(String raw) {
    final parsed = parseDurationInput(raw);
    if (parsed == null) return;
    final s = widget.entry.start;
    if (s == null) return;
    final nextStop = s.add(parsed);
    // Stash the *canonical* duration text before the VM update so the
    // `didUpdateWidget` re-seed branch sees `next == _externalText` and
    // skips overwriting the controller (which would jump the cursor to
    // end on every keystroke). Mirrors _DescriptionField's pattern.
    _externalText = formatDuration(nextStop.difference(s), compactDays: true);
    widget.vm.updateEntry(
      widget.actualIndex,
      widget.entry.copyWith(stop: nextStop),
    );
  }

  /// Apply a quick-pick preset (admin-portal parity, 15/30/45/.../120
  /// minutes). Anchors at the existing `start`; if the entry has no
  /// start yet, seeds it 30 minutes back so the preset always lands a
  /// valid duration.
  void _applyPreset(int minutes) {
    final start =
        widget.entry.start ??
        DateTime.now().subtract(const Duration(minutes: 30));
    final nextStop = start.add(Duration(minutes: minutes));
    final newText = formatDuration(
      nextStop.difference(start),
      compactDays: true,
    );
    // Refresh both the canonical shadow *and* the controller — the
    // preset path isn't a typing path, so writing the controller
    // directly is safe (cursor-stable guard in `didUpdateWidget` only
    // matters mid-keystroke). Without the controller write, the field
    // would keep showing the old value because the guard sees
    // `next == _externalText` and skips the re-seed.
    _externalText = newText;
    _controller.text = newText;
    widget.vm.updateEntry(
      widget.actualIndex,
      widget.entry.copyWith(start: start, stop: nextStop),
    );
  }

  static const _presetMinutes = [15, 30, 45, 60, 75, 90, 105, 120];

  @override
  Widget build(BuildContext context) {
    if (widget.entry.isRunning && widget.entry.start != null) {
      // Running entries can't have their stop time written directly via
      // the duration cell — show the live ticker instead.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: RunningDurationLabel(start: widget.entry.start!),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kCellMinHeight),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 12,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          // Trailing quick-pick menu matching admin-portal's
          // DurationPicker (15 → 120-minute presets). Hidden when the
          // entry has no start yet, since we'd have nothing to anchor
          // the duration against.
          suffixIcon: PopupMenuButton<int>(
            tooltip: context.tr('duration'),
            icon: const Icon(Icons.arrow_drop_down, size: 18),
            padding: EdgeInsets.zero,
            iconSize: 18,
            onSelected: _applyPreset,
            itemBuilder: (_) => [
              for (final m in _presetMinutes)
                PopupMenuItem<int>(
                  value: m,
                  child: Text(
                    formatDuration(Duration(minutes: m), showSeconds: false),
                    // Tabular figures lock each digit to the same width
                    // so colons line up across `0:15` / `1:00` / `2:00`.
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
          ),
        ),
        onChanged: _onChanged,
      ),
    );
  }
}

class _BillableCell extends StatelessWidget {
  const _BillableCell({
    required this.vm,
    required this.entry,
    required this.actualIndex,
  });

  final TaskEditViewModel vm;
  final TimeEntry entry;
  final int actualIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final billable = entry.billable;
    return IconButton(
      tooltip: context.tr(billable ? 'billable' : 'non_billable'),
      icon: Icon(
        billable ? Icons.attach_money : Icons.money_off_outlined,
        size: 18,
        color: billable ? tokens.accent : tokens.ink3,
      ),
      onPressed: () =>
          vm.updateEntry(actualIndex, entry.copyWith(billable: !billable)),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _DeleteCell extends StatelessWidget {
  const _DeleteCell({required this.vm, required this.actualIndex});

  final TaskEditViewModel vm;
  final int actualIndex;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('remove'),
      icon: const Icon(Icons.close, size: 16),
      onPressed: () => vm.removeEntry(actualIndex),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
    );
  }
}

class _DescriptionField extends StatefulWidget {
  const _DescriptionField({
    required this.vm,
    required this.entry,
    required this.actualIndex,
  });

  final TaskEditViewModel vm;
  final TimeEntry entry;
  final int actualIndex;

  @override
  State<_DescriptionField> createState() => _DescriptionFieldState();
}

class _DescriptionFieldState extends State<_DescriptionField> {
  late final TextEditingController _controller;
  String _externalText = '';

  @override
  void initState() {
    super.initState();
    _externalText = widget.entry.description;
    _controller = TextEditingController(text: _externalText);
  }

  @override
  void didUpdateWidget(covariant _DescriptionField old) {
    super.didUpdateWidget(old);
    final next = widget.entry.description;
    if (next != _externalText && next != _controller.text) {
      _externalText = next;
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 1,
      maxLines: 3,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: context.tr('description'),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: (v) {
        _externalText = v;
        widget.vm.updateEntry(
          widget.actualIndex,
          widget.entry.copyWith(description: v),
        );
      },
    );
  }
}

class _AddTimeRow extends StatelessWidget {
  const _AddTimeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        // Horizontal `InSpacing.lg(context)` aligns the `+` with the column
        // headers + cell values above (canonical card padding,
        // CLAUDE.md § Design system v2).
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.add, size: 18, color: tokens.ink3),
            const SizedBox(width: 8),
            Text(
              context.tr('add_time'),
              style: TextStyle(
                color: tokens.ink3,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

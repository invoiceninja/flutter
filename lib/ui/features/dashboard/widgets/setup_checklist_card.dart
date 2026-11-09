import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/welcome_controller.dart';
import 'package:admin/domain/setup_checklist.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/haptics.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/dashboard/view_models/setup_checklist_view_model.dart';

/// The routes the checklist leads to.
const String kChecklistLogoRoute = '/settings/company_details/logo';
const String kChecklistInvoiceRoute = '/invoices/new';
const String kChecklistGatewayRoute = '/settings/company_gateways/new';
const String kChecklistClientRoute = '/clients/new';
const String kChecklistImportRoute = '/settings/import_export';

/// The dashboard's first child on both layouts: the "Start getting paid"
/// checklist a new company gets after `/setup` (docs/first-run-welcome.md).
///
/// **Always one child.** The dashboard bodies are `ListView`s that match
/// children by index, so a slot that came and went would rebuild everything
/// below it; "off" is a zero-size box in the same place, as for
/// `DashboardAttentionSlot`.
class DashboardSetupChecklistSlot extends StatefulWidget {
  const DashboardSetupChecklistSlot({
    super.key,
    required this.companyId,
    required this.onNavigate,
    this.onEmptyChanged,
  });

  final String companyId;
  final void Function(String route) onNavigate;

  /// Told whether the card is showing over a company with no invoices — the
  /// dashboard then lets its zero figures step back.
  final ValueChanged<bool>? onEmptyChanged;

  @override
  State<DashboardSetupChecklistSlot> createState() =>
      _DashboardSetupChecklistSlotState();
}

class _DashboardSetupChecklistSlotState
    extends State<DashboardSetupChecklistSlot> {
  WelcomeController? _welcome;
  SetupChecklistViewModel? _vm;

  /// The card is collapsing (Hide or Done) before its state is written.
  bool _collapsing = false;

  /// All four done was seen in this session: the card stays to say so, and
  /// Done (or the next visit) retires it.
  bool _celebrated = false;
  bool? _lastEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WelcomeController? welcome;
    try {
      welcome = context.read<WelcomeController?>();
    } on ProviderNotFoundException {
      welcome = null;
    }
    if (!identical(welcome, _welcome)) {
      _welcome?.removeListener(_onWelcome);
      _welcome = welcome?..addListener(_onWelcome);
      _sync();
    }
  }

  @override
  void didUpdateWidget(DashboardSetupChecklistSlot old) {
    super.didUpdateWidget(old);
    if (old.companyId != widget.companyId) {
      _dropVm();
      _celebrated = false;
      _sync();
    }
  }

  bool get _armed {
    final w = _welcome;
    if (w == null || widget.companyId.isEmpty) return false;
    return w.showsChecklist(widget.companyId);
  }

  bool get _isAdmin {
    try {
      final c = context.read<Services>().auth.session.value?.currentCompany;
      return c != null && (c.isAdmin || c.isOwner);
    } catch (_) {
      return false;
    }
  }

  void _onWelcome() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  /// Opens the streams only while the card can show.
  void _sync() {
    // A checklist completed in this visit stays to say so until Done or the
    // dashboard goes; the record already says it's complete.
    if ((_armed || _celebrated) && _isAdmin) {
      if (_vm == null) {
        final services = context.read<Services>();
        _vm = SetupChecklistViewModel(
          db: services.db,
          companyId: widget.companyId,
          session: services.auth.session,
          welcome: _welcome!,
          drain: (id) => services.sync.drainOnce(companyId: id),
        )..addListener(_onVm);
      }
    } else if (!_collapsing) {
      _dropVm();
    }
    _reportEmpty();
  }

  void _onVm() {
    if (!mounted) return;
    final vm = _vm!;
    if (vm.loaded && completedCount(vm.rows) == vm.rows.length) {
      if (!_celebrated) {
        // Once: the record is marked complete now, so the next visit shows
        // nothing and nothing buzzes again.
        _celebrated = true;
        unawaited(InHaptics.success());
        unawaited(_welcome?.noteChecklistCompleted(widget.companyId));
      }
    }
    _reportEmpty();
    setState(() {});
  }

  void _reportEmpty() {
    final vm = _vm;
    // Only for a company that is new: an old company named in /setup can
    // have invoices on the server that this device hasn't downloaded yet.
    final fresh = _welcome?.checklistFor(widget.companyId)?.fresh ?? false;
    final empty =
        fresh && vm != null && vm.loaded && vm.hasNoInvoices && !_collapsing;
    if (empty != _lastEmpty) {
      _lastEmpty = empty;
      final cb = widget.onEmptyChanged;
      if (cb != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cb(empty);
        });
      }
    }
  }

  void _dropVm() {
    _vm
      ?..removeListener(_onVm)
      ..dispose();
    _vm = null;
  }

  @override
  void dispose() {
    _welcome?.removeListener(_onWelcome);
    _dropVm();
    super.dispose();
  }

  Future<void> _collapse(Future<void> Function() then) async {
    setState(() => _collapsing = true);
    _reportEmpty();
    await Future<void>.delayed(
      InMotion.of(context)(const Duration(milliseconds: 280)),
    );
    await then();
    if (!mounted) return;
    setState(() => _collapsing = false);
    _sync();
  }

  void _hide() {
    final welcome = _welcome;
    if (welcome == null) return;
    final companyId = widget.companyId;
    final hidden = context.tr('checklist_hidden');
    final undo = context.tr('undo');
    unawaited(
      _collapse(() async {
        await welcome.hideChecklist(companyId);
        if (!mounted) return;
        Notify.info(
          context,
          hidden,
          action: NotifyAction(
            undo,
            () => unawaited(welcome.unhideChecklist(companyId)),
          ),
        );
      }),
    );
  }

  void _done() {
    final welcome = _welcome;
    if (welcome == null) return;
    final companyId = widget.companyId;
    unawaited(
      _collapse(() async {
        _celebrated = false;
        await welcome.noteChecklistCompleted(companyId);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final motion = InMotion.of(context);
    final show = vm != null && vm.loaded;
    return AnimatedSize(
      duration: motion(const Duration(milliseconds: 280)),
      curve: InMotion.move,
      alignment: AlignmentDirectional.topStart,
      child: !show || _collapsing
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: InSpacing.xl),
              child: _RevealOnce(
                child: SetupChecklistCard(
                  vm: vm,
                  onNavigate: widget.onNavigate,
                  onHide: _hide,
                  onDone: _done,
                ),
              ),
            ),
    );
  }
}

/// The card's first appearance: a fade and a 12 px rise after a beat, so it
/// arrives with the dashboard rather than with the frame.
class _RevealOnce extends StatefulWidget {
  const _RevealOnce({required this.child});

  final Widget child;

  @override
  State<_RevealOnce> createState() => _RevealOnceState();
}

class _RevealOnceState extends State<_RevealOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: InMotion.slow,
  );
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0 || _delay != null) return;
    if (!InMotion.of(context).enabled) {
      _c.value = 1;
      return;
    }
    _delay = Timer(const Duration(milliseconds: 120), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: InMotion.out);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - a.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// The card itself: a title, a progress bar, and the five rows — only the
/// next one carries a filled button.
class SetupChecklistCard extends StatefulWidget {
  const SetupChecklistCard({
    super.key,
    required this.vm,
    required this.onNavigate,
    required this.onHide,
    required this.onDone,
  });

  final SetupChecklistViewModel vm;
  final void Function(String route) onNavigate;
  final VoidCallback onHide;
  final VoidCallback onDone;

  @override
  State<SetupChecklistCard> createState() => _SetupChecklistCardState();
}

class _SetupChecklistCardState extends State<SetupChecklistCard> {
  /// Ticks to animate on this visit — read once, then remembered as shown.
  late final Set<String> _animate = widget.vm.newlyDone;

  @override
  void initState() {
    super.initState();
    if (_animate.isNotEmpty) unawaited(InHaptics.light());
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.vm.noteShown());
  }

  @override
  void didUpdateWidget(SetupChecklistCard old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.vm.noteShown();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    final rows = widget.vm.rows;
    final done = completedCount(rows);
    final total = rows.length;
    final allDone = done == total;
    final next = nextChecklistItem(rows);
    final barColor = allDone ? tokens.paid : tokens.accent;
    final pad = InSpacing.lg(context);

    return Container(
      key: const ValueKey('setup_checklist'),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.shadow1,
      ),
      padding: EdgeInsets.fromLTRB(pad, pad, pad, InSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: motion(const Duration(milliseconds: 200)),
                      child: Semantics(
                        key: ValueKey(allDone),
                        header: true,
                        headingLevel: 2,
                        child: Text(
                          context.tr(
                            allDone
                                ? 'checklist_done_title'
                                : 'checklist_get_paid_title',
                          ),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('checklist_progress', {
                        'count': '$done',
                        'total': '$total',
                      }),
                      style: TextStyle(fontSize: 13, color: tokens.ink3),
                    ),
                  ],
                ),
              ),
              if (allDone)
                FilledButton(
                  key: const ValueKey('setup_checklist_done'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: widget.onDone,
                  child: Text(context.tr('done')),
                )
              else
                TextButton(
                  key: const ValueKey('setup_checklist_hide'),
                  onPressed: widget.onHide,
                  child: Text(context.tr('hide')),
                ),
            ],
          ),
          const SizedBox(height: InSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(InRadii.r1),
            child: SizedBox(
              height: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: tokens.border),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: done / total),
                    duration: motion(const Duration(milliseconds: 400)),
                    curve: InMotion.move,
                    builder: (context, v, _) => FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: v,
                      child: AnimatedContainer(
                        duration: motion(const Duration(milliseconds: 300)),
                        color: barColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: InSpacing.md(context)),
          for (final row in rows)
            _ChecklistRow(
              row: row,
              isNext: row.item == next,
              animateTick: _animate.contains(row.id),
              allDone: allDone,
              onNavigate: widget.onNavigate,
              onRetry: () => unawaited(widget.vm.retryLogo()),
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.row,
    required this.isNext,
    required this.animateTick,
    required this.allDone,
    required this.onNavigate,
    required this.onRetry,
  });

  final SetupChecklistRow row;
  final bool isNext;
  final bool animateTick;
  final bool allDone;
  final void Function(String route) onNavigate;
  final VoidCallback onRetry;

  (String, String) get _copy => switch (row.item) {
    SetupChecklistItem.business => (
      'checklist_business_title',
      'checklist_business_body',
    ),
    SetupChecklistItem.logo => ('setup_logo_title', 'checklist_logo_body'),
    SetupChecklistItem.invoice => (
      'checklist_invoice_title',
      'checklist_invoice_body',
    ),
    SetupChecklistItem.payments => (
      'checklist_payments_title',
      'checklist_payments_body',
    ),
    SetupChecklistItem.clients => (
      'checklist_clients_title',
      'checklist_clients_body',
    ),
  };

  /// The row's action: its label key and route; null for one with none.
  (String, String)? get _action => switch (row.item) {
    SetupChecklistItem.business => null,
    SetupChecklistItem.logo => ('setup_add_logo', kChecklistLogoRoute),
    SetupChecklistItem.invoice => ('create_invoice', kChecklistInvoiceRoute),
    SetupChecklistItem.payments => ('connect', kChecklistGatewayRoute),
    SetupChecklistItem.clients => ('new_client', kChecklistClientRoute),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (titleKey, bodyKey) = _copy;
    final complete = row.isComplete;
    final failed = row.state == ChecklistRowState.failed;
    final action = complete ? null : _action;
    final body = switch (row.state) {
      ChecklistRowState.uploading => context.tr('checklist_logo_uploading'),
      ChecklistRowState.failed => context.tr('checklist_logo_failed'),
      _ => context.tr(bodyKey),
    };
    final touch = Env.isTouchPrimary;

    // The row's action: Retry, the next step's button(s), or a chevron.
    Widget? buttons;
    if (failed) {
      buttons = OutlinedButton(
        key: const ValueKey('setup_checklist_retry'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        onPressed: onRetry,
        child: Text(context.tr('checklist_retry')),
      );
    } else if (action != null && isNext) {
      buttons = Wrap(
        spacing: InSpacing.sm,
        runSpacing: InSpacing.xs,
        children: [
          if (row.item == SetupChecklistItem.clients)
            TextButton(
              key: const ValueKey('setup_checklist_import'),
              onPressed: () => onNavigate(kChecklistImportRoute),
              child: Text(context.tr('import')),
            ),
          FilledButton(
            key: ValueKey('setup_checklist_${row.id}'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => onNavigate(action.$2),
            child: Text(context.tr(action.$1)),
          ),
        ],
      );
    }
    final chevron = action != null && !isNext && !failed
        ? Icon(Icons.chevron_right, size: 20, color: tokens.ink3)
        : null;

    // The tick and the text are one node for a screen reader, which hears
    // whether the step is done — the tick alone says it only to the eye.
    final label = MergeSemantics(
      child: Semantics(
        checked: complete,
        child: Row(
          children: [
            _Tick(state: row.state, animate: animateTick, allDone: allDone),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(titleKey),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: complete ? tokens.ink3 : tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: failed
                          ? Theme.of(context).colorScheme.error
                          : (complete ? tokens.ink4 : tokens.ink3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Beside the text where there is room; under it, aligned with the text,
    // where there isn't — a phone, a long locale, a large text size — so the
    // buttons never squeeze the words to a letter a line.
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final beside = constraints.maxWidth >= 560 * scale.clamp(1.0, 2.0);
          if (buttons == null || beside) {
            return Row(
              children: [
                Expanded(child: label),
                if (buttons != null || chevron != null) ...[
                  const SizedBox(width: InSpacing.sm),
                  ?buttons,
                  ?chevron,
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label,
              Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 24 + InSpacing.md(context),
                  top: InSpacing.sm,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: buttons,
                ),
              ),
            ],
          );
        },
      ),
    );

    final sized = ConstrainedBox(
      constraints: BoxConstraints(minHeight: touch ? InSizes.touchTarget : 0),
      child: content,
    );
    // A quiet row that leads somewhere is one tap target; the next row's
    // button is its own target, so the row itself stays inert.
    if (action == null || isNext || failed) return sized;
    return Semantics(
      // The whole row is the one destination (no name link inside it).
      link: action.$2.isNotEmpty,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey('setup_checklist_row_${row.id}'),
          borderRadius: BorderRadius.circular(InRadii.r2),
          onTap: () => onNavigate(action.$2),
          child: sized,
        ),
      ),
    );
  }
}

/// ✓ in a filled circle when done (scaling in once when it just became so),
/// an upload arrow while the logo is on its way, a warning when it failed,
/// an empty ring otherwise.
class _Tick extends StatelessWidget {
  const _Tick({
    required this.state,
    required this.animate,
    required this.allDone,
  });

  final ChecklistRowState state;
  final bool animate;
  final bool allDone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    const size = 24.0;
    switch (state) {
      case ChecklistRowState.todo:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tokens.borderStrong, width: 1.5),
          ),
        );
      case ChecklistRowState.failed:
        return Icon(
          Icons.error_outline,
          size: size,
          color: Theme.of(context).colorScheme.error,
        );
      case ChecklistRowState.uploading:
        return Icon(
          Icons.cloud_upload_outlined,
          size: size,
          color: tokens.ink3,
        );
      case ChecklistRowState.done:
        final color = allDone ? tokens.paid : tokens.accent;
        final dot = AnimatedContainer(
          duration: motion(const Duration(milliseconds: 300)),
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(Icons.check, size: 16, color: tokens.onAccent),
        );
        if (!animate || !motion.enabled) return dot;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: InMotion.base,
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(
            scale: v,
            child: Opacity(
              opacity: ((v - 0.6) / 0.4).clamp(0, 1),
              child: child,
            ),
          ),
          child: dot,
        );
    }
  }
}

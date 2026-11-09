import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/local_data_disposer.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/setup_defaults.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_sign_out_dialog.dart';
import 'package:admin/ui/core/utils/haptics.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';
import 'package:admin/ui/core/widgets/document_capture.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/auth/view_models/setup_wizard_view_model.dart';
import 'package:admin/ui/features/auth/widgets/setup_wizard/setup_invoice_preview.dart';
import 'package:admin/ui/features/auth/widgets/setup_wizard/setup_wizard_steps.dart';
import 'package:admin/ui/features/auth/widgets/setup_wizard/setup_wizard_top_bar.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/logo_crop_screen.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';
import 'package:admin/ui/features/shell/widgets/show_company_picker.dart';
import 'package:admin/utils/formatting.dart';

/// The gate a company with no name yet sits behind (`isCompanySetupRequired`)
/// — for a new account, the first screen of the app. Two steps, **Your
/// business** then **Add your logo**, beside a live invoice preview, ending
/// in a short finish moment before the one commit (docs/first-run-welcome.md).
///
/// A full-screen route outside the shell, so it gates every deep link the
/// same way; only the business name is required.
class SetupWizardScreen extends StatelessWidget {
  const SetupWizardScreen({super.key});

  /// Keyed on the active company: switching to another unnamed company from
  /// the ⋮ menu keeps the same `/setup` page, and a wizard still bound to the
  /// previous company would name the wrong one and leave the gate shut.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AuthSession?>(
    valueListenable: context.read<Services>().auth.session,
    builder: (context, session, _) =>
        _SetupWizard(key: ValueKey(session?.currentCompanyId ?? '')),
  );
}

class _SetupWizard extends StatefulWidget {
  const _SetupWizard({super.key});

  @override
  State<_SetupWizard> createState() => _SetupWizardScreenState();
}

/// Width at which the preview gets its own pane beside the form.
const double _kSplitWidth = 720;

/// The 1,250 the preview's total shows, in the chosen currency.
final Decimal _kPreviewTotal = Decimal.fromInt(1250);

const int _kMaxLogoBytes = 5 * 1024 * 1024;

class _SetupWizardScreenState extends State<_SetupWizard>
    with SingleTickerProviderStateMixin {
  late final Services _services;
  late final SetupWizardViewModel _vm;
  final _nameController = TextEditingController();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _nameFocus = FocusNode();
  final _firstFocus = FocusNode();
  final _headingFocus = FocusNode(skipTraversal: true);
  final _primaryFocus = FocusNode();

  /// The first frame's entrance: heading, subtitle and fields rise in.
  late final AnimationController _entrance;

  bool _regionExpanded = false;

  /// The finish moment is playing; the commit follows it.
  bool _finishing = false;

  /// Which way the last step change went, for the slide.
  bool _forward = true;
  bool _logoBusy = false;
  String? _logoError;
  Formatter? _formatter;
  bool _regionSeeded = false;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    final session = _services.auth.session.value;
    _vm = SetupWizardViewModel(
      companyId: session?.currentCompanyId ?? '',
      session: session,
      company: _services.company,
      user: _services.user,
      sync: _services.sync,
      passwordCache: _services.passwordCache,
      welcome: _readWelcome(),
      warmFormatter: (id) => _services.formatterFor(id),
      onNameQueued: (first, last) =>
          _services.auth.noteQueuedUserName(first: first, last: last),
    )..addListener(_onVm);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final statics = _services.statics;
    if (statics.currencies.isEmpty || statics.languages.isEmpty) {
      statics.ensureLoaded().then((_) {
        if (mounted) _seedRegion();
      });
    }
    unawaited(_loadFormatter());
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter());
  }

  WelcomeController? _readWelcome() {
    try {
      return context.read<WelcomeController?>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _loadFormatter() async {
    final id = _vm.companyId;
    if (id.isEmpty) return;
    try {
      final f = await _services.formatterFor(id);
      if (mounted) setState(() => _formatter = f);
    } catch (_) {
      // The preview's total waits on its placeholder; nothing else needs it.
    }
  }

  /// Play the entrance, then focus the first field — after it on a phone, so
  /// the keyboard and the page don't move at the same time.
  void _enter() {
    if (!mounted) return;
    final motion = InMotion.of(context);
    if (motion.enabled) {
      _entrance.forward();
    } else {
      _entrance.value = 1;
    }
    final wait = motion(
      Env.isMobile ? const Duration(milliseconds: 320) : Duration.zero,
    );
    _focusTimer = Timer(wait, () {
      if (!mounted || _vm.step != SetupWizardStep.business) return;
      if (MediaQuery.maybeAccessibleNavigationOf(context) ?? false) {
        _headingFocus.requestFocus();
      } else {
        (_vm.askUserName ? _firstFocus : _nameFocus).requestFocus();
      }
    });
  }

  Timer? _focusTimer;

  final _regionPickersKey = GlobalKey();

  /// Opens or closes the currency and language pickers. Opening drops the
  /// keyboard and brings them into view once they have grown — on a phone
  /// they would otherwise open behind the keyboard and the footer.
  void _toggleRegion() {
    final opening = !_regionExpanded;
    setState(() => _regionExpanded = opening);
    if (!opening) return;
    if (Env.isTouchPrimary) FocusScope.of(context).unfocus();
    final motion = InMotion.of(context);
    Future<void>.delayed(
      motion(InMotion.base) + const Duration(milliseconds: 40),
      () {
        final target = _regionPickersKey.currentContext;
        if (!mounted || target == null || !target.mounted) return;
        Scrollable.ensureVisible(
          target,
          alignment: 0.9,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: motion(InMotion.base),
          curve: InMotion.move,
        );
      },
    );
  }

  Timer? _unstick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_regionSeeded) _seedRegion();
  }

  /// The company's own currency and language if it has them, else the
  /// device locale's — once statics are warm.
  void _seedRegion() {
    final statics = _services.statics;
    if (statics.currencies.isEmpty || statics.languages.isEmpty) return;
    if (_vm.companyId.isEmpty) return;
    _regionSeeded = true;
    final locale = Localizations.maybeLocaleOf(context);
    _services.company.get(_vm.companyId).then((company) {
      if (!mounted) return;
      final cur = company?.settings.currencyId ?? '';
      final lang = company?.settings.languageId ?? '';
      _vm.seedRegion(
        currencyId: cur.isNotEmpty
            ? cur
            : defaultCurrencyId(statics.currencies.values, locale),
        languageId: lang.isNotEmpty
            ? lang
            : defaultLanguageId(statics.languages.values, locale),
      );
    });
  }

  void _onVm() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm
      ..removeListener(_onVm)
      ..dispose();
    _focusTimer?.cancel();
    _unstick?.cancel();
    _entrance.dispose();
    _nameController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    _nameFocus.dispose();
    _firstFocus.dispose();
    _headingFocus.dispose();
    _primaryFocus.dispose();
    super.dispose();
  }

  bool get _busy => _finishing || _vm.committing || _logoBusy;

  // ─── Navigation ──────────────────────────────────────────────────────

  void _onPrimary() {
    if (_busy) return;
    switch (_vm.step) {
      case SetupWizardStep.business:
        _forward = true;
        if (_vm.advance()) {
          unawaited(InHaptics.selection());
          _focusAfterStepChange();
        } else {
          _nameFocus.requestFocus();
        }
      case SetupWizardStep.logo:
        unawaited(_finish());
    }
  }

  bool _back() {
    if (_busy) return false;
    _forward = false;
    final moved = _vm.back();
    if (moved) {
      unawaited(InHaptics.selection());
      _focusAfterStepChange();
    }
    return moved;
  }

  /// A screen reader is taken to the new step's heading; a keyboard user to
  /// where they will act next — the name field, or the primary on step 2 so
  /// Enter still finishes.
  void _focusAfterStepChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeAccessibleNavigationOf(context) ?? false) {
        _headingFocus.requestFocus();
      } else if (_vm.step == SetupWizardStep.business) {
        _nameFocus.requestFocus();
      } else if (!Env.isTouchPrimary) {
        _primaryFocus.requestFocus();
      } else {
        // Off the name field, so the keyboard drops — but still inside the
        // wizard, so a hardware Esc keeps going back a step.
        _headingFocus.requestFocus();
      }
    });
  }

  /// The finish moment — the button turns into a check, the progress fills,
  /// the content settles — and then the one commit. The commit comes last
  /// because the router leaves `/setup` as soon as the name is saved.
  Future<void> _finish() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = context.tr('setup_save_failed');
    // The name save is password-protected, and the password primed at
    // sign-up may have lapsed (five minutes, or the app went to the
    // background). Ask now, while the wizard is up — never as a sheet with
    // no context on the dashboard. Declining still saves the company.
    if (_vm.nameNeedsPassword) {
      final ok = await showConfirmPasswordSheet(
        context,
        cache: _services.passwordCache,
      );
      if (!mounted) return;
      if (!ok) _vm.skipUserName = true;
    }
    setState(() => _finishing = true);
    unawaited(InHaptics.light());
    await Future<void>.delayed(
      InMotion.of(context)(const Duration(milliseconds: 450)),
    );
    if (!mounted) return;
    try {
      await _vm.commit();
      // Success is felt only once the save is written, never before an error.
      unawaited(InHaptics.success());
      // The router redirect lands the user on the dashboard and tears this
      // screen down. Should it still be up a moment later, the gate did not
      // open: hand the controls back rather than sit frozen on a check.
      _unstick = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _finishing = false);
        _vm.resetCommitting();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      Notify.error(context, failed, error: e, messenger: messenger);
    }
  }

  // ─── Logo ────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final intake = intakeOf(context);
    final sources = await pickGalleryPhotos(context, multiple: false);
    if (!mounted) return;
    try {
      await _takeLogo(sources);
    } finally {
      unawaited(releaseCapturedPhotos(intake, sources));
    }
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: kSetupLogoExtensions,
    );
    if (!mounted || picked == null) return;
    final sources = await uploadSourcesFromPicked([picked]);
    if (!mounted) return;
    await _takeLogo(sources);
  }

  /// Validate, crop, keep. Nothing is uploaded until the wizard is finished;
  /// a file that can't be a logo says so under the box, not in a toast.
  Future<void> _takeLogo(List<UploadSource> sources) async {
    if (sources.isEmpty || _logoBusy) return;
    final source = sources.first;
    final invalid = context.tr('setup_logo_error');
    final tooLarge = context.tr('upload_too_large_with_size', {
      'size': '${_kMaxLogoBytes ~/ (1024 * 1024)}',
    });
    setState(() {
      _logoBusy = true;
      _logoError = null;
    });
    try {
      final ext = p.extension(source.fileName).toLowerCase();
      if (!kSetupLogoExtensions.contains(ext.replaceFirst('.', ''))) {
        setState(() => _logoError = invalid);
        return;
      }
      final size = await source.length();
      if (!mounted) return;
      if (size > _kMaxLogoBytes) {
        setState(() => _logoError = tooLarge);
        return;
      }
      final bytes = await source.readRange(0, size);
      if (!mounted) return;
      final cropped = await showLogoCropScreen(context, bytes);
      if (!mounted || cropped == null) return;
      if (cropped.lengthInBytes > _kMaxLogoBytes) {
        setState(() => _logoError = tooLarge);
        return;
      }
      _vm.setLogo(cropped);
      unawaited(InHaptics.light());
    } catch (_) {
      if (mounted) setState(() => _logoError = invalid);
    } finally {
      if (mounted) setState(() => _logoBusy = false);
    }
  }

  // ─── Ways out ────────────────────────────────────────────────────────

  Future<void> _onSignOut() async {
    // Resolved before the first await (`use_build_context_synchronously`).
    final services = _services;
    if (!await showConfirmSignOutDialog(context)) return;
    if (!mounted) return;
    // A full logout wipes every company's local DB — quiesce pending offline
    // rows first, the same guard as every other sign-out entry point.
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      final outbox = await confirmPendingOutboxIfAny(
        context,
        companyId: companyId,
        checkAllCompanies: true,
      );
      if (outbox == OutboxConfirmResult.cancelled || !mounted) return;
    }
    await services.auth.logout(data: LocalDataPolicy.destroy);
  }

  // ─── Build ───────────────────────────────────────────────────────────

  String? _previewTotal(List<Currency> currencies) {
    final f = _formatter;
    if (f == null || _vm.currencyId.isEmpty) return null;
    if (!currencies.any((c) => c.id == _vm.currencyId)) return null;
    return f.money(_kPreviewTotal, currencyId: _vm.currencyId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final session = context.watch<Services>().auth.session.value;
    final canSwitch = (session?.companies.length ?? 0) > 1;
    final statics = _services.statics;
    final currencies = statics.currencies.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final languages = statics.languages.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return PopScope(
      // Android back goes back a step; on the first it leaves as usual.
      canPop: _vm.isFirstStep && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CallbackShortcuts(
        // Only off the first step: there Esc belongs to the currency and
        // language pickers, which close on it, and back leaves the screen.
        bindings: _vm.isFirstStep
            ? const {}
            : {const SingleActivator(LogicalKeyboardKey.escape): _back},
        child: Scaffold(
          backgroundColor: tokens.bg,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Width *and* height: a landscape phone is wide enough but
                // far too short for a side pane — with the keyboard up the
                // form would get a single field's height
                // (docs/touch-targets.md "A landscape phone is not a small
                // desktop").
                final split =
                    constraints.maxWidth >= _kSplitWidth &&
                    constraints.maxHeight >= 560;
                return FormSaveScope(
                  onSubmit: _onPrimary,
                  enabled: !_busy,
                  child: Column(
                    children: [
                      SetupWizardTopBar(
                        step: _vm.stepNumber,
                        stepCount: _vm.stepCount,
                        complete: _finishing || _vm.committing,
                        showWordmark: split,
                        enabled: !_busy,
                        onSignOut: _onSignOut,
                        onSwitchCompany: canSwitch
                            ? () => showCompanyPicker(context)
                            : null,
                      ),
                      Expanded(
                        child: split
                            ? _buildSplit(context, currencies, languages)
                            : _buildNarrow(context, currencies, languages),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplit(
    BuildContext context,
    List<Currency> currencies,
    List<Language> languages,
  ) {
    final tokens = context.inTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: InSpacing.xxl,
                      vertical: InSpacing.xl,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: _stepBody(context, currencies, languages, false),
                    ),
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440 + 64),
                  child: _footer(context, phone: false),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: tokens.surfaceAlt,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(InSpacing.xl),
                child: _preview(currencies, width: 360),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow(
    BuildContext context,
    List<Currency> currencies,
    List<Language> languages,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              InSpacing.xl,
              InSpacing.sm,
              InSpacing.xl,
              InSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: _stepBody(context, currencies, languages, true),
              ),
            ),
          ),
        ),
        // Capped with the form column: a landscape phone's full width made a
        // Continue the width of the screen.
        _footer(context, phone: true, maxWidth: 560),
      ],
    );
  }

  Widget _preview(List<Currency> currencies, {required double width}) =>
      SetupInvoicePreview(
        businessName: _vm.businessName,
        total: _previewTotal(currencies),
        logo: _vm.logo,
        width: width,
      );

  /// The current step, entering with a fade and a short rise on the first
  /// frame, and sliding in from the side it was reached from afterwards.
  Widget _stepBody(
    BuildContext context,
    List<Currency> currencies,
    List<Language> languages,
    bool narrow,
  ) {
    final motion = InMotion.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Gated on the device, not the window: an iPad or a landscape phone is
    // still touch, and still needs Photos (the iOS file picker cannot reach
    // it) — CLAUDE.md "A landscape phone is not a small desktop".
    final touchLogo = Env.isTouchPrimary;
    final Widget body = switch (_vm.step) {
      SetupWizardStep.business => SetupStepBusiness(
        key: const ValueKey(SetupWizardStep.business),
        vm: _vm,
        nameController: _nameController,
        firstController: _firstController,
        lastController: _lastController,
        nameFocus: _nameFocus,
        firstFocus: _firstFocus,
        headingFocus: _headingFocus,
        regionExpanded: _regionExpanded,
        onToggleRegion: _toggleRegion,
        regionPickersKey: _regionPickersKey,
        currencies: currencies,
        languages: languages,
      ),
      SetupWizardStep.logo => SetupStepLogo(
        key: const ValueKey(SetupWizardStep.logo),
        vm: _vm,
        headingFocus: _headingFocus,
        touchLayout: touchLogo,
        busy: _busy,
        error: _logoError,
        onFiles: _takeLogo,
        onPickPhoto: _pickPhoto,
        onPickFile: _pickFile,
        // On a phone the preview is this step's hero, and its logo slot the
        // way to add one; on a wide screen it already has its own pane.
        preview: narrow
            ? SetupInvoicePreview(
                businessName: _vm.businessName,
                total: _previewTotal(currencies),
                logo: _vm.logo,
                width: 300,
                onTapLogo: _busy ? null : (touchLogo ? _pickPhoto : null),
              )
            : null,
      ),
    };

    final entering = CurvedAnimation(parent: _entrance, curve: InMotion.out);
    return AnimatedOpacity(
      opacity: _finishing || _vm.committing ? 0.0 : 1.0,
      duration: motion(const Duration(milliseconds: 160)),
      curve: InMotion.in_,
      child: FadeTransition(
        opacity: entering,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(entering),
          child: AnimatedSwitcher(
            duration: motion(InMotion.base),
            reverseDuration: motion(const Duration(milliseconds: 120)),
            switchInCurve: InMotion.out,
            switchOutCurve: InMotion.in_,
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.topStart,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == ValueKey(_vm.step);
              // Forward: the new step comes from the end edge, the old one
              // leaves toward the start; Back mirrors it, and so does RTL.
              var dx = incoming ? 24.0 : -16.0;
              if (!_forward) dx = -dx;
              if (rtl) dx = -dx;
              return FadeTransition(
                opacity: animation,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(dx * (1 - animation.value), 0),
                    child: child,
                  ),
                  child: child,
                ),
              );
            },
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _footer(
    BuildContext context, {
    required bool phone,
    double? maxWidth,
  }) {
    final tokens = context.inTheme;
    final motion = InMotion.of(context);
    final onLogo = _vm.step == SetupWizardStep.logo;
    final done = _finishing || _vm.committing;
    final hasLogo = _vm.logo != null;
    // The heaviest button never says skip: an outlined "Skip for Now" until
    // a logo lands, then a filled "Finish Setup".
    final filled = !onLogo || hasLogo || done;
    final label = !onLogo
        ? context.tr('continue')
        : (hasLogo || done
              ? context.tr('setup_finish')
              : context.tr('setup_skip_for_now'));
    final content = AnimatedSwitcher(
      duration: motion(const Duration(milliseconds: 180)),
      child: done
          ? const Icon(Icons.check, key: ValueKey('done'), size: 20)
          : Text(label, key: ValueKey(label)),
    );
    final onPressed = _busy && !done ? null : (done ? () {} : _onPrimary);
    final primary = filled
        ? FilledButton(
            key: const ValueKey('setup_submit'),
            focusNode: _primaryFocus,
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: onPressed,
            child: content,
          )
        : OutlinedButton(
            key: const ValueKey('setup_submit'),
            focusNode: _primaryFocus,
            style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: onPressed,
            child: content,
          );

    return Container(
      padding: EdgeInsets.fromLTRB(
        InSpacing.xl,
        InSpacing.md(context),
        InSpacing.xl,
        InSpacing.md(context),
      ),
      decoration: phone
          ? BoxDecoration(
              color: tokens.bg,
              border: Border(top: BorderSide(color: tokens.border)),
            )
          : null,
      // Step 1 on a phone has no Back, so Continue takes the whole width —
      // where the thumb is — up to the form column's.
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: phone && _vm.isFirstStep
            ? SizedBox(width: double.infinity, child: primary)
            : Row(
                children: [
                  if (!_vm.isFirstStep)
                    TextButton(
                      key: const ValueKey('setup_back'),
                      onPressed: _busy ? null : _back,
                      child: Text(context.tr('setup_back')),
                    ),
                  // The primary takes what Back leaves and sits at the end; its
                  // label wraps before the row can overflow — a long locale or
                  // a large text size on a narrow phone.
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/setup_defaults.dart' show isPlaceholderCompanyName;
import 'package:admin/domain/welcome.dart';
import 'package:admin/ui/features/auth/widgets/name_required_dialog.dart';

final _log = Logger('SetupWizardViewModel');

/// The two steps of `/setup` (docs/first-run-welcome.md).
enum SetupWizardStep { business, logo }

/// The setup wizard's draft, and the one commit that ends it.
///
/// **Nothing is written until [commit].** Saving the company's name opens the
/// router's `/setup` gate at once (the companies table notifies the session,
/// and the redirect leaves `/setup` the moment a name exists), so a step that
/// saved as it went would be thrown out of the wizard before the next one.
/// The draft lives here; [commit] writes it in one pass, in a fixed order.
class SetupWizardViewModel extends ChangeNotifier {
  SetupWizardViewModel({
    required this.companyId,
    required this.session,
    required CompanyRepository company,
    required UserRepository user,
    required SyncRepository sync,
    required PasswordCache passwordCache,
    this.welcome,
    this.warmFormatter,
    this.onNameQueued,
  }) : _company = company,
       _user = user,
       _sync = sync,
       _passwordCache = passwordCache,
       // Decided once: typing a name must not hide the fields being typed
       // into. Asked whenever the hosted account lacks one — the wizard is
       // the one calm place to collect it. Saving it is password-protected:
       // a fresh email sign-up primed the cache and an OAuth user is exempt;
       // otherwise Finish asks for the password first (`nameNeedsPassword`).
       askUserName = needsUserName(session),
       isAdditionalCompany = (session?.companies.length ?? 0) > 1;

  final String companyId;
  final AuthSession? session;
  final CompanyRepository _company;
  final UserRepository _user;
  final SyncRepository _sync;
  final PasswordCache _passwordCache;
  final WelcomeController? welcome;

  /// Shows the queued name in the session at once
  /// (`AuthRepository.noteQueuedUserName`), so the shell's missing-name
  /// prompt does not ask for it again before the server has answered.
  final void Function(String first, String last)? onNameQueued;

  /// The user declined the password sheet the name save needed: the company
  /// is still saved, and the shell's missing-name prompt asks later.
  bool skipUserName = false;

  /// Whether saving the typed name needs a password the cache no longer
  /// holds — it lasts five minutes, and backgrounding the app (an Android
  /// file picker, a switch to look the business name up) clears it. The
  /// screen asks for it before the finish, while the wizard is still up.
  bool get nameNeedsPassword =>
      askUserName &&
      !skipUserName &&
      (firstName.trim().isNotEmpty || lastName.trim().isNotEmpty) &&
      !_passwordCache.isPrimed;

  /// Re-builds the company's `Formatter` after the save drops it, so the
  /// dashboard the router lands on does not open on its loading spinner.
  final Future<void> Function(String companyId)? warmFormatter;

  final bool askUserName;

  /// The user already has a company: "Set up your new business".
  final bool isAdditionalCompany;

  SetupWizardStep get step => _step;
  SetupWizardStep _step = SetupWizardStep.business;

  bool get isFirstStep => _step == SetupWizardStep.business;
  int get stepNumber => _step.index + 1;
  int get stepCount => SetupWizardStep.values.length;

  String businessName = '';
  String firstName = '';
  String lastName = '';

  String get currencyId => _currencyId;
  String _currencyId = '';
  String get languageId => _languageId;
  String _languageId = '';

  /// The cropped logo, PNG bytes, until [commit] queues it.
  Uint8List? get logo => _logo;
  Uint8List? _logo;

  /// Continue was pressed with no business name.
  bool get showNameError => _showNameError;
  bool _showNameError = false;

  /// [commit] has started: every control is inert.
  bool get committing => _committing;
  bool _committing = false;

  bool _disposed = false;

  /// The name the "Use :name" suggestion offers: the user's own, typed or
  /// on the account.
  String get suggestedBusinessName {
    final typed = '${firstName.trim()} ${lastName.trim()}'.trim();
    if (typed.isNotEmpty) return typed;
    final s = session;
    if (s == null) return '';
    return '${s.userFirstName.trim()} ${s.userLastName.trim()}'.trim();
  }

  void setBusinessName(String value) {
    businessName = value;
    if (_showNameError && value.trim().isNotEmpty) {
      _showNameError = false;
    }
    _notify();
  }

  void setUserName({String? first, String? last}) {
    if (first != null) firstName = first;
    if (last != null) lastName = last;
    _notify();
  }

  /// Seeds the region once statics are warm; a choice the user made wins.
  void seedRegion({required String currencyId, required String languageId}) {
    var changed = false;
    if (_currencyId.isEmpty && currencyId.isNotEmpty) {
      _currencyId = currencyId;
      changed = true;
    }
    if (_languageId.isEmpty && languageId.isNotEmpty) {
      _languageId = languageId;
      changed = true;
    }
    if (changed) _notify();
  }

  void setCurrency(String id) {
    _currencyId = id;
    _notify();
  }

  void setLanguage(String id) {
    _languageId = id;
    _notify();
  }

  void setLogo(Uint8List? bytes) {
    _logo = bytes;
    _notify();
  }

  /// A name the `/setup` gate reads as "not named yet" (`isCompanySetupRequired`)
  /// — saving it would leave the gate shut and the wizard stuck.
  bool get _nameIsUsable {
    final n = businessName.trim();
    return n.isNotEmpty && !isPlaceholderCompanyName(n);
  }

  /// Continue on step 1. False — with the inline error up — when there is no
  /// business name yet.
  bool advance() {
    if (_committing) return false;
    if (_step == SetupWizardStep.business) {
      if (!_nameIsUsable) {
        _showNameError = true;
        _notify();
        return false;
      }
      _step = SetupWizardStep.logo;
      _notify();
      return true;
    }
    return false;
  }

  /// Back a step. False on the first step, where back leaves the screen.
  bool back() {
    if (_committing || _step == SetupWizardStep.business) return false;
    _step = SetupWizardStep.values[_step.index - 1];
    _notify();
    return true;
  }

  /// Write the draft, in an order that matters:
  ///
  /// 1. the Welcome record (the checklist is armed, and a new account's
  ///    pending Welcome settled) — first, because the company save below
  ///    unmounts this screen;
  /// 2. the user's name — the wizard asked for it, so it lands before the
  ///    company that the next screen greets by name;
  /// 3. **one** company PUT with name, currency and language;
  /// 4. the logo upload, *after* the PUT: the PUT carries the company's
  ///    current `settings.company_logo`, so an upload sent first would be
  ///    cleared by it.
  ///
  /// Every dependency was captured at construction, and nothing here notifies
  /// after the first write: the router leaves `/setup` the moment the name
  /// lands and disposes this. True when the company was saved.
  Future<bool> commit() async {
    if (_committing) return false;
    final name = businessName.trim();
    if (!_nameIsUsable) {
      _showNameError = true;
      _step = SetupWizardStep.business;
      _notify();
      return false;
    }
    _committing = true;
    _notify();
    final s = session;
    final userKey = s == null || s.userId.isEmpty
        ? null
        : welcomeUserKey(s.baseUrl, s.userId);
    try {
      await welcome?.noteSetupCompleted(userKey: userKey, companyId: companyId);
      await _saveUserName();
      final current = await _company.get(companyId);
      if (current == null) throw StateError('No company row for $companyId');
      await _company.updateCompany(
        draft: current.copyWith(
          settings: current.settings.copyWith(
            name: name,
            currencyId: _currencyId.isEmpty
                ? current.settings.currencyId
                : _currencyId,
            languageId: _languageId.isEmpty
                ? current.settings.languageId
                : _languageId,
          ),
        ),
      );
      final logo = _logo;
      if (logo != null) {
        await _company.uploadLogo(
          companyId: companyId,
          source: BytesUploadSource(logo, 'logo.png'),
        );
      }
      unawaited(warmFormatter?.call(companyId));
      // Through now, so the next `/refresh` brings the name back from the
      // server rather than "Untitled Company" (which would reopen the gate).
      unawaited(_sync.drainOnce(companyId: companyId));
      return true;
    } catch (e, st) {
      _log.warning('Setup could not be saved', e, st);
      _committing = false;
      _notify();
      rethrow;
    }
  }

  /// Queued through the same path User Details saves with: the whole record,
  /// marked password-protected (`PUT /users/{id}` is).
  Future<void> _saveUserName() async {
    final s = session;
    if (!askUserName || skipUserName || s == null || s.userId.isEmpty) {
      return;
    }
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty && last.isEmpty) return;
    final user = await _user.get(companyId: companyId, userId: s.userId);
    if (user == null) return;
    final draft = user.copyWith(firstName: first, lastName: last);
    // Minus a blank `language_id`: Laravel rejects "" for the foreign key.
    final body = Map<String, dynamic>.from(draft.toApi().toJson());
    if (draft.languageId.isEmpty) body.remove('language_id');
    await _user.enqueueUpdate(
      companyId: companyId,
      draft: draft,
      body: body,
      requiresPassword: true,
    );
    onNameQueued?.call(first, last);
  }

  /// The commit saved, yet the screen is still up — the gate did not open
  /// (it never should, now that a placeholder name is refused). Lets the
  /// user try again instead of leaving the wizard frozen.
  void resetCommitting() {
    _committing = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

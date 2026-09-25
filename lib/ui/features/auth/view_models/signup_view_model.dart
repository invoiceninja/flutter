import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/apple_sign_in.dart';
import 'package:admin/data/services/google_oauth.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;
import 'package:admin/ui/features/auth/view_models/social_sign_in.dart';

/// State machine for the in-app signup screen.
///
/// Hosted-only by construction: the base URL is always [Env.hostedApiUrl]
/// (self-hosted in-app signup is not a validated path — the login screen
/// keeps the external link there). Mirrors [LoginViewModel]'s busy / error /
/// fieldErrors machinery so the screen surfaces server validation inline.
class SignupViewModel extends ChangeNotifier {
  SignupViewModel({required this.auth});

  final AuthRepository auth;

  /// Offer "Sign up with Apple" / "Sign up with Google" — the login screen's
  /// gates, so the two screens show the same providers.
  bool get appleEnabled => AppleSignIn.isSupported;
  bool get googleEnabled => GoogleOAuth.isEnabled;

  String email = '';
  String password = '';
  String confirmPassword = '';
  bool acceptedTerms = false;

  bool _busy = false;
  bool get busy => _busy;

  String? _errorKey;
  String? get errorKey => _errorKey;
  Map<String, String> _errorParams = const {};
  Map<String, String> get errorParams => _errorParams;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setError({String? key, Map<String, String>? params, String? message}) {
    _errorKey = key;
    _errorParams = params ?? const {};
    _errorMessage = message;
  }

  void _clearError() {
    _errorKey = null;
    _errorParams = const {};
    _errorMessage = null;
  }

  Map<String, List<String>> _fieldErrors = const {};
  Map<String, List<String>> get fieldErrors => _fieldErrors;

  void setEmail(String value) {
    email = value.trim();
  }

  void setPassword(String value) {
    password = value;
  }

  void setConfirmPassword(String value) {
    confirmPassword = value;
  }

  void setAcceptedTerms(bool value) {
    if (acceptedTerms == value) return;
    acceptedTerms = value;
    notifyListeners();
  }

  /// Create the account. Local validation gates the network call (so we
  /// never POST an obviously-bad signup); server-side validation comes back
  /// as 422 [ValidationException] → [fieldErrors] surfaced inline, exactly
  /// like the login form.
  Future<bool> submit() async {
    if (_busy) return false;
    _clearError();
    _fieldErrors = const {};
    if (email.isEmpty || password.isEmpty) {
      _setError(key: 'please_fill_out_all_fields');
      notifyListeners();
      return false;
    }
    if (password != confirmPassword) {
      _setError(key: 'passwords_do_not_match');
      notifyListeners();
      return false;
    }
    if (!acceptedTerms) {
      _setError(key: 'accept_terms_to_continue');
      notifyListeners();
      return false;
    }
    _busy = true;
    notifyListeners();
    try {
      await auth.signup(
        baseUrl: Env.hostedApiUrl,
        isHosted: true,
        email: email,
        password: password,
      );
      return true;
    } on ValidationException catch (e) {
      _fieldErrors = e.fieldErrors;
      _setError(message: e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _setError(message: e.message);
      return false;
    } on NetworkException catch (e) {
      _setError(
        key: 'network_error_with_message',
        params: {'message': e.message},
      );
      return false;
    } on ApiException catch (e) {
      _setError(message: e.message);
      return false;
    } on Object catch (e) {
      // See `LoginViewModel.submit` — without this, anything that isn't an
      // `ApiException` subtype leaves the button un-spun and silent.
      _setError(message: formatNotifyError(e));
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Create the account with Apple (`/oauth_login?create=true`). Needs the
  /// terms accepted first, like [submit]; `false` with no error means the
  /// Apple sheet was dismissed.
  Future<bool> submitApple() => _submitSocial(
    () => signInWithApple(
      auth: auth,
      baseUrl: Env.hostedApiUrl,
      isHosted: true,
      create: true,
    ),
  );

  /// Create the account with Google. The server creates a Google account only
  /// through this `create=true` path — the login screen's Google button signs
  /// in an existing one.
  Future<bool> submitGoogle() => _submitSocial(
    () => signInWithGoogle(
      auth: auth,
      baseUrl: Env.hostedApiUrl,
      isHosted: true,
      create: true,
    ),
  );

  Future<bool> _submitSocial(Future<bool> Function() signUp) async {
    if (_busy) return false;
    _clearError();
    _fieldErrors = const {};
    if (!acceptedTerms) {
      _setError(key: 'accept_terms_to_continue');
      notifyListeners();
      return false;
    }
    _busy = true;
    notifyListeners();
    try {
      return await signUp();
    } on SocialSignInFailure catch (f) {
      _setError(key: f.key, params: f.params, message: f.message);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

/// FOSS stub: Google Sign-In needs Play Services, which F-Droid forbids.
///
/// [isSupported] is always false, so the login, signup and Connect screens
/// hide their Google buttons and none of the other members is ever reached.
class GoogleSignInClient {
  GoogleSignInClient._();

  static bool isSupported({
    required String androidServerClientId,
    required String iosClientId,
  }) => false;

  static Future<String> signIn({
    required String androidServerClientId,
    required String iosClientId,
  }) async => '';

  static Future<void> signOut({
    required String androidServerClientId,
    required String iosClientId,
  }) async {}

  static Future<void> disconnect({
    required String androidServerClientId,
    required String iosClientId,
  }) async {}
}

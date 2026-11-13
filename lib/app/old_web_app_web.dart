import 'package:web/web.dart' as web;

/// admin-portal kept its API token in `shared_preferences` under `checksum`,
/// which the web plugin stores as `flutter.checksum`. This app never writes a
/// `flutter.`-prefixed key, so its presence means the old app once signed
/// someone in on this origin. Read only: the key is the old app's, and a
/// server that falls back to it (docs/web-deploy.md) still uses it.
const _oldToken = 'flutter.checksum';

/// Set once the card has done its job: this app has signed in here.
const _done = 'invoiceninja.v2.old_app_notice_done';

bool oldWebAppNoticeDue() {
  try {
    final storage = web.window.localStorage;
    return storage.getItem(_oldToken) != null && storage.getItem(_done) == null;
  } catch (_) {
    return false;
  }
}

void oldWebAppNoticeDone() {
  try {
    web.window.localStorage.setItem(_done, '1');
  } catch (_) {}
}

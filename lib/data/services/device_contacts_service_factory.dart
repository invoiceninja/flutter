/// Picks the production [DeviceContactsService] for the current platform.
///
/// - Native (`device_contacts_service_io.dart`): [NativeDeviceContactsService]
///   over `flutter_contacts` — the OS contact picker on iOS.
/// - Web (`device_contacts_service_web.dart`): a stub that reports unavailable.
///   `flutter_contacts` has no web implementation and would break
///   `flutter build web`, so the web file never imports it.
///
/// Tests inject a fake `DeviceContactsService` directly and never hit this
/// factory. Default target is the web stub; `dart.library.io` swaps in native.
library;

export 'package:admin/data/services/device_contacts_service_web.dart'
    if (dart.library.io) 'package:admin/data/services/device_contacts_service_io.dart';

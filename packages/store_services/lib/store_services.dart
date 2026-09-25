/// The store builds' non-free SDKs behind a narrow, SDK-free API.
///
/// Two packages share this name and this exact public surface:
/// `packages/store_services` (the real SDKs) and
/// `packages/store_services_foss` (inert stubs for F-Droid). The app imports
/// only this library — see docs/fdroid.md.
library;

export 'package:store_services/src/crash_reporting.dart';
export 'package:store_services/src/google_sign_in_client.dart';
export 'package:store_services/src/store_billing.dart';

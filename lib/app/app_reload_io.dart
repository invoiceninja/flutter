/// Native half of the [app_reload] seam: there is no in-place reload for a
/// desktop or mobile binary, so this is a deliberate no-op and callers gate
/// the affordance on `kIsWeb`.
void reloadApp() {}

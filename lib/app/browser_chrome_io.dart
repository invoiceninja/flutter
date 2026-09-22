/// Native half of the [browser_chrome] seam: there is no browser wrapped
/// around a desktop or mobile binary, so the app's own history arrows are
/// always the only ones.
bool browserProvidesHistoryControls() => false;

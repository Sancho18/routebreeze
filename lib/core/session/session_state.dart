/// Process-wide flags shared across features.
class SessionState {
  /// True while a navigation is running; blocks re-lock on foreground.
  bool isNavigationActive = false;

  /// Set by the live navigation while its position stream exists: the
  /// lifecycle gate calls [onPause] when the app goes to background and
  /// [onResume] when it returns.
  void Function()? onPause;
  void Function()? onResume;
}

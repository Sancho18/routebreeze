/// Process-wide flags shared across features.
class SessionState {
  /// True from "Iniciar" until the navigation screen closes, also after the
  /// route completes, so the summary stays; blocks re-lock on foreground.
  bool isNavigationActive = false;

  /// Set by the live navigation while its position stream exists: the
  /// lifecycle gate calls [onPause] when the app goes to background and
  /// [onResume] when it returns.
  void Function()? onPause;
  void Function()? onResume;
}

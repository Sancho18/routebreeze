/// Process-wide flags shared across features.
class SessionState {
  /// True from "Iniciar" until the navigation screen closes, including the
  /// finished route's summary; while true, the app does not re-lock.
  bool isNavigationActive = false;

  /// Set by the live navigation: the lifecycle gate calls [onPause] when the
  /// app goes to background and [onResume] when it returns.
  void Function()? onPause;
  void Function()? onResume;
}

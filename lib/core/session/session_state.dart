/// Process-wide flags shared across features.
class SessionState {
  /// True while a navigation is running; blocks re-lock on foreground
  /// (LOCK-08).
  bool isNavigationActive = false;
}

/// Re-lock rule for foreground returns.
class RelockPolicy {
  const RelockPolicy({this.threshold = const Duration(seconds: 30)});

  final Duration threshold;

  /// True when the app was in background for [threshold] or more and no
  /// navigation is active.
  bool shouldRelock({
    required Duration inBackground,
    required bool navigationActive,
  }) => !navigationActive && inBackground >= threshold;
}

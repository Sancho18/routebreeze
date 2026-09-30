/// Re-lock rule for foreground returns.
class RelockPolicy {
  const RelockPolicy({this.threshold = const Duration(seconds: 30)});

  final Duration threshold;

  bool shouldRelock({
    required Duration inBackground,
    required bool navigationActive,
  }) => !navigationActive && inBackground >= threshold;
}

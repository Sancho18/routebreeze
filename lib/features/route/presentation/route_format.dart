/// `12345` → `"12,3 km"`; below 1000 m → `"850 m"`.
String formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = (meters / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '$km km';
}

/// `605` → `"10 min"` (rounded); under 30 s → `"< 1 min"`; from 60 minutes
/// on → `"1 h 05 min"`.
String formatDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes == 0) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '$hours h $rest min';
}

/// Clock time as given, 24 h: `"14:32"`, `"09:05"`.
String formatClock(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

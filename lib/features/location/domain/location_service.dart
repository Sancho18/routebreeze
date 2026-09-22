import 'fix.dart';

/// Outcome of the permission and service check (MAP-01, MAP-03..MAP-05).
enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

/// Device location: permission flow, one-shot fix and position stream.
abstract class LocationService {
  Future<LocationAccess> checkAccess();

  Future<LocationAccess> requestPermission();

  /// Best-accuracy fix; throws `TimeoutException` when none arrives within
  /// [timeout] (MAP-02, MAP-06).
  Future<Fix> currentFix({Duration timeout = const Duration(seconds: 15)});

  /// Best-accuracy stream with one event per [distanceFilterMeters] moved
  /// (NAV-02).
  Stream<Fix> watch({int distanceFilterMeters = 5});

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}

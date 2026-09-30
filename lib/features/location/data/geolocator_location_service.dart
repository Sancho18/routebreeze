import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/geo/geo_point.dart';
import '../domain/fix.dart';
import '../domain/location_service.dart';

/// [LocationService] over [GeolocatorPlatform], which tests can replace.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  @override
  Future<LocationAccess> checkAccess() async {
    if (!await _platform.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    return _map(await _platform.checkPermission());
  }

  @override
  Future<LocationAccess> requestPermission() async =>
      _map(await _platform.requestPermission());

  @override
  Future<Fix> currentFix({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final position = await _platform.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: timeout,
      ),
    );
    return _toFix(position);
  }

  @override
  Stream<Fix> watch({int distanceFilterMeters = 5, bool background = false}) =>
      _platform
          .getPositionStream(
            locationSettings: settingsFor(
              platform: defaultTargetPlatform,
              distanceFilterMeters: distanceFilterMeters,
              background: background,
            ),
          )
          .map(_toFix);

  /// Stream settings for [platform]. Android needs no geolocator notification:
  /// the navigation's foreground service keeps updates coming in background.
  static LocationSettings settingsFor({
    required TargetPlatform platform,
    required int distanceFilterMeters,
    required bool background,
  }) => switch (platform) {
    TargetPlatform.iOS when background => AppleSettings(
      accuracy: LocationAccuracy.best,
      activityType: ActivityType.automotiveNavigation,
      distanceFilter: distanceFilterMeters,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    ),
    TargetPlatform.android => AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: distanceFilterMeters,
    ),
    _ => LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: distanceFilterMeters,
    ),
  };

  @override
  Future<void> openAppSettings() => _platform.openAppSettings();

  @override
  Future<void> openLocationSettings() => _platform.openLocationSettings();

  static LocationAccess _map(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.whileInUse ||
        LocationPermission.always => LocationAccess.granted,
        LocationPermission.deniedForever => LocationAccess.deniedForever,
        LocationPermission.denied ||
        LocationPermission.unableToDetermine => LocationAccess.denied,
      };

  static Fix _toFix(Position position) => Fix(
    GeoPoint(position.latitude, position.longitude),
    position.accuracy,
    position.timestamp,
  );
}

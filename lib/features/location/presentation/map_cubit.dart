import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/fix.dart';
import '../domain/location_service.dart';

enum MapStatus {
  checking,
  ready,
  denied,
  deniedForever,
  serviceDisabled,
  timeout,
  imprecise,
}

class MapState extends Equatable {
  const MapState({this.status = MapStatus.checking, this.start});

  final MapStatus status;

  /// The start fix; set only when [status] is `ready` (MAP-07).
  final Fix? start;

  @override
  List<Object?> get props => [status, start];
}

/// Permission flow and start fix for the Map screen (MAP-01..MAP-07).
class MapCubit extends Cubit<MapState> {
  MapCubit(this._location) : super(const MapState());

  final LocationService _location;

  /// Accepted horizontal accuracy for the start fix (MAP-02).
  static const double maxAccuracyMeters = 50;

  /// Time allowed for the first fix (MAP-02, MAP-06).
  static const Duration fixTimeout = Duration(seconds: 15);

  Future<void> init() async {
    if (state.status != MapStatus.checking) emit(const MapState());
    var access = await _location.checkAccess();
    if (access == LocationAccess.denied) {
      access = await _location.requestPermission();
    }
    if (isClosed) return;
    switch (access) {
      case LocationAccess.denied:
        return emit(const MapState(status: MapStatus.denied));
      case LocationAccess.deniedForever:
        return emit(const MapState(status: MapStatus.deniedForever));
      case LocationAccess.serviceDisabled:
        return emit(const MapState(status: MapStatus.serviceDisabled));
      case LocationAccess.granted:
        break;
    }
    final Fix fix;
    try {
      fix = await _location.currentFix(timeout: fixTimeout);
    } on TimeoutException {
      if (isClosed) return;
      return emit(const MapState(status: MapStatus.timeout));
    }
    if (isClosed) return;
    emit(
      fix.accuracyMeters <= maxAccuracyMeters
          ? MapState(status: MapStatus.ready, start: fix)
          : const MapState(status: MapStatus.imprecise),
    );
  }

  Future<void> retry() => init();

  Future<void> openSettings() => switch (state.status) {
    MapStatus.deniedForever => _location.openAppSettings(),
    MapStatus.serviceDisabled => _location.openLocationSettings(),
    _ => Future<void>.value(),
  };
}

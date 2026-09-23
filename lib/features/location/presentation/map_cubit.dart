import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../route/domain/route_plan.dart';
import '../../route/domain/route_repository.dart';
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
  const MapState({
    this.status = MapStatus.checking,
    this.start,
    this.resumable,
  });

  final MapStatus status;

  /// The start fix; set only when [status] is `ready`.
  final Fix? start;

  /// A persisted, unfinished route to offer with "Continuar rota?"; set only
  /// with `ready`.
  final RoutePlan? resumable;

  @override
  List<Object?> get props => [status, start, resumable];
}

/// Permission flow and start fix for the Map screen, plus the offer to
/// resume a persisted route.
class MapCubit extends Cubit<MapState> {
  MapCubit(this._location, {this._routes}) : super(const MapState());

  final LocationService _location;
  final RouteRepository? _routes;

  /// Accepted horizontal accuracy for the start fix.
  static const double maxAccuracyMeters = 50;

  /// Time allowed for the first fix.
  static const Duration fixTimeout = Duration(seconds: 15);

  /// Any failure to check access or get the fix (timeout, platform error)
  /// ends in [MapStatus.timeout], whose card offers "Tentar novamente".
  Future<void> init() async {
    if (state.status != MapStatus.checking) emit(const MapState());
    final Fix fix;
    try {
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
      fix = await _location.currentFix(timeout: fixTimeout);
    } on Object {
      if (isClosed) return;
      return emit(const MapState(status: MapStatus.timeout));
    }
    if (isClosed) return;
    if (fix.accuracyMeters > maxAccuracyMeters) {
      return emit(const MapState(status: MapStatus.imprecise));
    }
    final resumable = await _loadResumable();
    if (isClosed) return;
    emit(MapState(status: MapStatus.ready, start: fix, resumable: resumable));
  }

  Future<void> retry() => init();

  /// "Nova rota" on the resume offer: the persisted route is deleted.
  Future<void> dismissResume() async {
    emit(MapState(status: state.status, start: state.start));
    await _routes?.clear();
  }

  /// The persisted route when it is not finished; storage errors are
  /// ignored.
  Future<RoutePlan?> _loadResumable() async {
    final routes = _routes;
    if (routes == null) return null;
    try {
      final plan = await routes.loadActive();
      return plan != null && !plan.isComplete ? plan : null;
    } on Object {
      return null;
    }
  }

  Future<void> openSettings() => switch (state.status) {
    MapStatus.deniedForever => _location.openAppSettings(),
    MapStatus.serviceDisabled => _location.openLocationSettings(),
    _ => Future<void>.value(),
  };
}

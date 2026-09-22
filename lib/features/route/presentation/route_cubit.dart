import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/failure.dart';
import '../../../core/geo/geo_point.dart';
import '../../addresses/domain/stop.dart';
import '../domain/route_plan.dart';
import '../domain/route_repository.dart';

enum RouteStatus { idle, loading, ready, failure }

class RouteState extends Equatable {
  const RouteState({this.status = RouteStatus.idle, this.plan, this.failure});

  final RouteStatus status;

  /// Set only when [status] is `ready`.
  final RoutePlan? plan;

  /// Set only when [status] is `failure`.
  final Failure? failure;

  @override
  List<Object?> get props => [status, plan, failure];
}

/// Computes the optimized route for the Route screen (ROUTE-05, ROUTE-06).
/// The repository persists the plan on success (OFFL-03).
class RouteCubit extends Cubit<RouteState> {
  RouteCubit(this._repository) : super(const RouteState());

  final RouteRepository _repository;

  (GeoPoint, List<Stop>)? _last;

  Future<void> compute(GeoPoint origin, List<Stop> stops) async {
    _last = (origin, stops);
    emit(const RouteState(status: RouteStatus.loading));
    try {
      final plan = await _repository.plan(origin, stops);
      if (isClosed) return;
      emit(RouteState(status: RouteStatus.ready, plan: plan));
    } on Failure catch (failure) {
      if (isClosed) return;
      emit(RouteState(status: RouteStatus.failure, failure: failure));
    } on Object catch (error) {
      if (isClosed) return;
      emit(RouteState(status: RouteStatus.failure, failure: Unknown.of(error)));
    }
  }

  /// Re-runs the last [compute] once. No-op before the first request.
  Future<void> retry() {
    final last = _last;
    if (last == null) return Future.value();
    return compute(last.$1, last.$2);
  }
}

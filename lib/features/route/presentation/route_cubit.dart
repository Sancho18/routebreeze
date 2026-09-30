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

/// Computes the optimized route; the repository persists the plan on success.
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

  /// Takes the saved route when it holds the current plan's stops, in any
  /// order (a recalculation may reorder them), with the results, start and
  /// distance the navigation saved. Otherwise, and before a plan exists,
  /// the state stays as it is.
  Future<void> refreshFromSaved() async {
    final plan = state.plan;
    if (plan == null) return;
    final saved = await _repository.loadActive();
    if (isClosed || saved == null) return;
    final ids = _placeIds(plan);
    final savedIds = _placeIds(saved);
    if (savedIds.length != ids.length || !savedIds.containsAll(ids)) return;
    emit(RouteState(status: RouteStatus.ready, plan: saved));
  }

  static Set<String> _placeIds(RoutePlan plan) => {
    for (final stop in plan.stops) stop.stop.placeId,
  };

  /// Re-runs the last [compute] once. No-op before the first request.
  Future<void> retry() {
    final last = _last;
    if (last == null) return Future.value();
    return compute(last.$1, last.$2);
  }
}

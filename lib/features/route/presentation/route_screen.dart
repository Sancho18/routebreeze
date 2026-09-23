import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../../addresses/domain/stop.dart';
import '../../location/domain/fix.dart';
import '../domain/route_plan.dart';
import 'map_markers.dart';
import 'route_cubit.dart';
import 'route_map_objects.dart';
import 'route_sheet.dart';

/// Builds the map for a ready route; tests inject a placeholder because the
/// real `GoogleMap` cannot render in widget tests.
typedef RouteMapBuilder = Widget Function(
  BuildContext context,
  RouteMapObjects objects,
);

/// Route screen: computes the optimized route on open and, once ready, draws
/// it on the map under the [RouteSheet]; "Iniciar" hands the plan to [onStart].
class RouteScreen extends StatefulWidget {
  const RouteScreen({
    super.key,
    required this.start,
    required this.stops,
    required this.onStart,
    this.cubit,
    this.connectivity,
    this.mapBuilder,
    this.markers,
  });

  final Fix start;
  final List<Stop> stops;
  final void Function(RoutePlan plan) onStart;

  /// Overrides the cubit from `getIt` (tests).
  final RouteCubit? cubit;

  /// Overrides the service from `getIt` (tests).
  final ConnectivityService? connectivity;

  /// Overrides the `GoogleMap` builder (tests).
  final RouteMapBuilder? mapBuilder;

  /// Overrides the marker icon source (tests).
  final MapMarkers? markers;

  static const String title = 'Rota';
  static const String loadingMessage = 'Calculando a melhor rota...';
  static const String failureMessage = 'Não foi possível calcular a rota.';
  static const String retryLabel = 'Tentar novamente';
  static const String offlineBanner = 'Sem conexão';

  /// Padding around the fitted route (logical px).
  static const double cameraPadding = 48;

  /// Wait after `onMapCreated` before fitting the route: on Android the
  /// platform view may not be laid out yet ("Map size can't be 0").
  static const Duration cameraFitDelay = Duration(milliseconds: 300);

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  late final RouteCubit _cubit = widget.cubit ?? getIt<RouteCubit>();
  late final ConnectivityService _connectivity =
      widget.connectivity ?? getIt<ConnectivityService>();
  late final MapMarkers _markers = widget.markers ?? MapMarkers();
  StreamSubscription<bool>? _online;
  bool _isOnline = true;

  RoutePlan? _objectsPlan;
  Future<RouteMapObjects>? _objects;

  @override
  void initState() {
    super.initState();
    _cubit.compute(widget.start.point, widget.stops);
    _connectivity.check().then(_setOnline);
    _online = _connectivity.isOnline.listen(_setOnline);
  }

  @override
  void dispose() {
    _online?.cancel();
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  void _setOnline(bool online) {
    if (!mounted || online == _isOnline) return;
    setState(() => _isOnline = online);
  }

  /// Marker icons are drawn once per plan.
  Future<RouteMapObjects> _objectsFor(RoutePlan plan) {
    if (_objectsPlan == plan && _objects != null) return _objects!;
    _objectsPlan = plan;
    return _objects = () async {
      final icons = <int, BitmapDescriptor>{
        for (final stop in plan.stops)
          stop.order: await _markers.numbered(stop.order),
      };
      return buildMapObjects(
        plan,
        numberedIcons: icons,
        startIcon: _markers.start(),
      );
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(RouteScreen.title)),
      body: Column(
        children: [
          if (!_isOnline)
            const RbBanner(
              text: RouteScreen.offlineBanner,
              tone: RbTone.danger,
            ),
          Expanded(
            child: BlocBuilder<RouteCubit, RouteState>(
              bloc: _cubit,
              builder: (context, state) => switch (state.status) {
                RouteStatus.idle || RouteStatus.loading => const _Loading(),
                RouteStatus.failure => _Failure(onRetry: _cubit.retry),
                RouteStatus.ready => _Ready(
                  plan: state.plan!,
                  objects: _objectsFor(state.plan!),
                  mapBuilder: widget.mapBuilder ?? _googleMap,
                  onStart: () => widget.onStart(state.plan!),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _googleMap(BuildContext context, RouteMapObjects objects) =>
    _RouteMap(objects: objects);

/// `GoogleMap` fitted to the route once the platform view has laid out.
class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.objects});

  final RouteMapObjects objects;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  Future<void> _fit(GoogleMapController controller) async {
    await Future<void>.delayed(RouteScreen.cameraFitDelay);
    if (!mounted) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          widget.objects.bounds,
          RouteScreen.cameraPadding,
        ),
      );
    } on PlatformException {
      // Not laid out yet; the map stays on the origin at zoom 14.
    }
  }

  @override
  Widget build(BuildContext context) {
    final objects = widget.objects;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: objects.origin, zoom: 14),
      markers: objects.markers,
      polylines: objects.polylines,
      onMapCreated: _fit,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: RbSpace.s3),
          Text(
            RouteScreen.loadingMessage,
            style: RbText.caption.copyWith(color: RbColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(RbSpace.s3),
      child: RbInlineError(
        text: RouteScreen.failureMessage,
        actionLabel: RouteScreen.retryLabel,
        onAction: onRetry,
      ),
    );
  }
}

/// Map (once the marker icons exist) under the route sheet.
class _Ready extends StatelessWidget {
  const _Ready({
    required this.plan,
    required this.objects,
    required this.mapBuilder,
    required this.onStart,
  });

  final RoutePlan plan;
  final Future<RouteMapObjects> objects;
  final RouteMapBuilder mapBuilder;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FutureBuilder<RouteMapObjects>(
            future: objects,
            builder: (context, snapshot) {
              final objects = snapshot.data;
              return objects == null
                  ? const ColoredBox(color: RbColors.surface100)
                  : mapBuilder(context, objects);
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RouteSheet(plan: plan, startEnabled: true, onStart: onStart),
        ),
      ],
    );
  }
}

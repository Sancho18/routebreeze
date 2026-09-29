import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/measure_size.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../../addresses/domain/stop.dart';
import '../../location/domain/fix.dart';
import '../domain/route_plan.dart';
import 'map_markers.dart';
import 'route_cubit.dart';
import 'route_map_objects.dart';
import 'route_sheet.dart';

/// Builds the map for a ready route; [padding] is the map edge covered by the
/// sheet. Tests inject a placeholder because the real `GoogleMap` cannot
/// render in widget tests.
typedef RouteMapBuilder = Widget Function(
  BuildContext context,
  RouteMapObjects objects,
  EdgeInsets padding,
);

/// Route screen: computes the optimized route on open and, once ready, draws
/// it on the map under the [RouteSheet]; "Iniciar" hands the plan to [onStart]
/// and, when the navigation closes, the screen shows the route it saved.
class RouteScreen extends StatefulWidget {
  const RouteScreen({
    super.key,
    required this.start,
    required this.stops,
    required this.onStart,
    this.roundTrip = false,
    this.cubit,
    this.connectivity,
    this.mapBuilder,
    this.markers,
  });

  final Fix start;
  final List<Stop> stops;

  /// The route ends back at [start].
  final bool roundTrip;

  /// Opens the navigation with the plan; completes when it closes.
  final Future<void> Function(RoutePlan plan) onStart;

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

  (RoutePlan, Color)? _objectsKey;
  Future<RouteMapObjects>? _objects;

  @override
  void initState() {
    super.initState();
    _cubit.compute(
      widget.start.point,
      widget.stops,
      roundTrip: widget.roundTrip,
    );
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

  /// Once the navigation closes ("Encerrar" or the system back), the saved
  /// route of the same stops replaces [plan], so the sheet shows its results
  /// and "Iniciar" continues it.
  Future<void> _start(RoutePlan plan) async {
    await widget.onStart(plan);
    if (mounted) await _cubit.refreshFromSaved();
  }

  /// Cached per plan and route color: a theme change repaints the route line
  /// with the icons already drawn.
  Future<RouteMapObjects> _objectsFor(RoutePlan plan, Color routeColor) {
    final key = (plan, routeColor);
    if (_objectsKey == key && _objects != null) return _objects!;
    _objectsKey = key;
    return _objects = () async {
      final icons = <int, BitmapDescriptor>{
        for (final stop in plan.stops)
          stop.order: await _markers.numbered(stop.order),
      };
      return buildMapObjects(
        plan,
        numberedIcons: icons,
        startIcon: _markers.start(),
        routeColor: routeColor,
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
                  objects: _objectsFor(state.plan!, context.rb.brand),
                  mapBuilder: widget.mapBuilder ?? _googleMap,
                  onStart: () => _start(state.plan!),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _googleMap(
  BuildContext context,
  RouteMapObjects objects,
  EdgeInsets padding,
) => _RouteMap(objects: objects, padding: padding);

/// `GoogleMap` fitted to the route, inside the area the sheet leaves
/// visible, once the platform view has laid out.
class _RouteMap extends StatefulWidget {
  const _RouteMap({required this.objects, required this.padding});

  final RouteMapObjects objects;
  final EdgeInsets padding;

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
      padding: widget.padding,
      onMapCreated: _fit,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      style: mapStyleFor(Theme.of(context).brightness),
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
            style: RbText.caption.copyWith(color: context.rb.inkMuted),
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

/// Map (once the marker icons exist) under the route sheet, padded by the
/// sheet's height.
class _Ready extends StatefulWidget {
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
  State<_Ready> createState() => _ReadyState();
}

class _ReadyState extends State<_Ready> {
  double _sheetHeight = 0;

  void _onSheetMeasured(Size size) {
    if (mounted && size.height != _sheetHeight) {
      setState(() => _sheetHeight = size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FutureBuilder<RouteMapObjects>(
            future: widget.objects,
            builder: (context, snapshot) {
              final objects = snapshot.data;
              return objects == null
                  ? ColoredBox(color: context.rb.surface100)
                  : widget.mapBuilder(
                      context,
                      objects,
                      EdgeInsets.only(bottom: _sheetHeight),
                    );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MeasureSize(
            onChange: _onSheetMeasured,
            child: RouteSheet(
              plan: widget.plan,
              startEnabled: true,
              onStart: widget.onStart,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../../route/domain/route_plan.dart';
import '../../route/presentation/map_markers.dart';
import '../../route/presentation/route_map_objects.dart';
import '../../route/presentation/route_sheet.dart';
import 'navigation_cubit.dart';

/// What the navigation map draws and where its camera goes.
class NavigationMapModel {
  const NavigationMapModel({
    required this.markers,
    required this.polylines,
    required this.target,
    required this.following,
  });

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng target;
  final bool following;

  static const String meMarkerId = 'me';
}

/// Builds the map; tests inject a placeholder because the real `GoogleMap`
/// cannot render in widget tests.
typedef NavigationMapBuilder = Widget Function(
  BuildContext context,
  NavigationMapModel model,
);

/// Live navigation: map following the position, status overlays and the
/// [RouteSheet] in navigation mode.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.plan,
    required this.onExit,
    required this.onNewRoute,
    this.cubit,
    this.mapBuilder,
    this.markers,
  });

  final RoutePlan plan;

  /// Called on "Encerrar" once the stream is stopped.
  final VoidCallback onExit;

  final VoidCallback onNewRoute;

  /// Overrides the cubit from `getIt` (tests).
  final NavigationCubit? cubit;

  final NavigationMapBuilder? mapBuilder;

  final MapMarkers? markers;

  static const String title = 'Navegação';
  static const String startLabel = 'Iniciar';
  static const String stopLabel = 'Encerrar';
  static const String waitingGpsCaption = 'Aguardando sinal de GPS';
  static const String recenterLabel = 'Recentralizar';
  static const String offlineBanner = 'Sem conexão';
  static const String completedTitle = 'Rota concluída';
  static const String newRouteLabel = 'Nova rota';

  /// Camera zoom while following.
  static const double zoom = 16;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _Icons {
  const _Icons(this.numbered, this.start, this.me);

  final Map<int, BitmapDescriptor> numbered;
  final BitmapDescriptor start;
  final BitmapDescriptor me;
}

class _NavigationScreenState extends State<NavigationScreen> {
  late final NavigationCubit _cubit =
      widget.cubit ?? getIt<NavigationCubit>(param1: widget.plan);
  late final MapMarkers _markers = widget.markers ?? MapMarkers();

  RoutePlan? _iconsPlan;
  Future<_Icons>? _icons;
  Offset? _pointerDown;

  /// Pointer travel that counts as a map drag.
  static const double dragSlop = 12;

  @override
  void initState() {
    super.initState();
    _cubit.prepare();
  }

  @override
  void dispose() {
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  /// Marker icons are drawn once per plan.
  Future<_Icons> _iconsFor(RoutePlan plan) {
    if (_iconsPlan == plan && _icons != null) return _icons!;
    _iconsPlan = plan;
    return _icons = () async {
      final numbered = <int, BitmapDescriptor>{
        for (final stop in plan.unvisited)
          stop.order: await _markers.numbered(stop.order),
      };
      return _Icons(numbered, _markers.start(), await _markers.position());
    }();
  }

  NavigationMapModel _model(NavigationState state, _Icons icons) {
    final plan = state.plan;
    final objects = buildMapObjects(
      RoutePlan(
        origin: plan.origin,
        stops: plan.unvisited,
        polyline: plan.polyline,
        distanceMeters: plan.distanceMeters,
        durationSeconds: plan.durationSeconds,
        legs: plan.legs,
        computedAt: plan.computedAt,
      ),
      numberedIcons: icons.numbered,
      startIcon: icons.start,
    );
    final fix = state.fix;
    final target = fix == null
        ? objects.origin
        : LatLng(fix.point.lat, fix.point.lng);
    return NavigationMapModel(
      markers: {
        ...objects.markers,
        if (fix != null)
          Marker(
            markerId: const MarkerId(NavigationMapModel.meMarkerId),
            position: target,
            icon: icons.me,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            zIndexInt: 10,
          ),
      },
      polylines: objects.polylines,
      target: target,
      following: state.following,
    );
  }

  Widget _googleMap(BuildContext context, NavigationMapModel model) =>
      _NavigationMap(model: model);

  /// A drag is a pointer that travels more than [dragSlop] while the camera
  /// follows; camera callbacks are not used because `animateCamera` fires
  /// them too.
  void _onPointerMove(PointerMoveEvent event) {
    final down = _pointerDown;
    if (down == null || !_cubit.state.following) return;
    if ((event.position - down).distance <= dragSlop) return;
    _pointerDown = null;
    _cubit.onMapDragged();
  }

  void _stop() {
    _cubit.stop();
    widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    final mapBuilder = widget.mapBuilder ?? _googleMap;
    return BlocBuilder<NavigationCubit, NavigationState>(
      bloc: _cubit,
      builder: (context, state) {
        final navigating = state.phase == NavigationPhase.navigating;
        final completed = state.phase == NavigationPhase.completed;
        return Scaffold(
          appBar: AppBar(title: const Text(NavigationScreen.title)),
          body: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) => _pointerDown = event.position,
                  onPointerMove: _onPointerMove,
                  child: FutureBuilder<_Icons>(
                    future: _iconsFor(state.plan),
                    builder: (context, snapshot) {
                      final icons = snapshot.data;
                      return icons == null
                          ? const ColoredBox(color: RbColors.surface100)
                          : mapBuilder(context, _model(state, icons));
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TopOverlay(state: state),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!state.following && !completed)
                      Padding(
                        padding: const EdgeInsets.only(
                          right: RbSpace.s3,
                          bottom: RbSpace.s2,
                        ),
                        child: FloatingActionButton.extended(
                          onPressed: _cubit.recenter,
                          backgroundColor: RbColors.surface200,
                          foregroundColor: RbColors.brand,
                          icon: const Icon(Icons.my_location),
                          label: const Text(NavigationScreen.recenterLabel),
                        ),
                      ),
                    if (completed)
                      _Completed(onNewRoute: widget.onNewRoute)
                    else
                      RouteSheet(
                        plan: state.plan,
                        startEnabled: navigating || state.canStart,
                        startLabel: navigating
                            ? NavigationScreen.stopLabel
                            : NavigationScreen.startLabel,
                        startColor: navigating
                            ? RbColors.danger
                            : RbColors.brand,
                        onStart: navigating ? _stop : _cubit.start,
                        onMarkVisited: navigating
                            ? _cubit.markNextVisited
                            : null,
                        footer: navigating || state.canStart
                            ? null
                            : const _WaitingGps(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// `GoogleMap` that follows the position while the model says so; drags
/// are detected by the screen from pointer events.
class _NavigationMap extends StatefulWidget {
  const _NavigationMap({required this.model});

  final NavigationMapModel model;

  @override
  State<_NavigationMap> createState() => _NavigationMapState();
}

class _NavigationMapState extends State<_NavigationMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant _NavigationMap old) {
    super.didUpdateWidget(old);
    final model = widget.model;
    final moved = model.target != old.model.target;
    final refollowed = model.following && !old.model.following;
    if (model.following && (moved || refollowed)) _follow();
  }

  void _follow() {
    _controller?.animateCamera(CameraUpdate.newLatLng(widget.model.target));
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: model.target,
        zoom: NavigationScreen.zoom,
      ),
      markers: model.markers,
      polylines: model.polylines,
      onMapCreated: (controller) => _controller = controller,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}

/// Offline banner, recalculation badge and GPS error at the top of the map.
class _TopOverlay extends StatelessWidget {
  const _TopOverlay({required this.state});

  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    final badge = state.badge;
    final error = state.error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!state.online)
          const RbBanner(
            text: NavigationScreen.offlineBanner,
            tone: RbTone.danger,
          ),
        if (badge != null || error != null)
          Padding(
            padding: const EdgeInsets.all(RbSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null)
                  _Card(
                    child: RbStatusChip(
                      label: badge.text,
                      tone: badge.kind == BadgeKind.recalcFailed
                          ? RbTone.danger
                          : RbTone.warning,
                    ),
                  ),
                if (badge != null && error != null)
                  const SizedBox(height: RbSpace.s2),
                if (error != null)
                  _Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: RbSpace.s2,
                        vertical: RbSpace.s1,
                      ),
                      child: RbInlineError(text: error),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Backdrop so a chip stays legible over the map.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: RbColors.surface200,
        borderRadius: BorderRadius.circular(RbRadius.sm),
      ),
      child: child,
    );
  }
}

/// Caption under the sheet actions while the fix is worse than 50 m.
class _WaitingGps extends StatelessWidget {
  const _WaitingGps();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: RbSpace.s2),
      child: Text(
        NavigationScreen.waitingGpsCaption,
        textAlign: TextAlign.center,
        style: RbText.caption.copyWith(color: RbColors.inkMuted),
      ),
    );
  }
}

class _Completed extends StatelessWidget {
  const _Completed({required this.onNewRoute});

  final VoidCallback onNewRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RbSpace.s3),
      decoration: const BoxDecoration(
        color: RbColors.surface200,
        borderRadius: BorderRadius.vertical(top: Radius.circular(RbRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              NavigationScreen.completedTitle,
              style: RbText.heading.copyWith(color: RbColors.success),
            ),
            const SizedBox(height: RbSpace.s3),
            RbPrimaryButton(
              label: NavigationScreen.newRouteLabel,
              onPressed: onNewRoute,
            ),
          ],
        ),
      ),
    );
  }
}

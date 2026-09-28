import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/measure_size.dart';
import '../../../core/widgets/rb_button.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../../addresses/domain/stop.dart';
import '../../route/domain/route_plan.dart';
import '../../route/presentation/map_markers.dart';
import '../../route/presentation/route_format.dart';
import '../../route/presentation/route_map_objects.dart';
import '../../route/presentation/route_sheet.dart';
import '../data/navigation_app_launcher.dart';
import '../domain/progress_estimator.dart';
import 'navigation_cubit.dart';
import 'next_stop_card.dart';
import 'open_in_app_sheet.dart';

/// What the navigation map draws and where its camera goes.
class NavigationMapModel {
  const NavigationMapModel({
    required this.markers,
    required this.polylines,
    required this.target,
    required this.following,
    this.padding = EdgeInsets.zero,
  });

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final LatLng target;
  final bool following;

  /// Map edges covered by the next stop card and the sheet: the camera
  /// centers the position in the area left between them.
  final EdgeInsets padding;

  static const String meMarkerId = 'me';
}

/// Builds the map; tests inject a placeholder because the real `GoogleMap`
/// cannot render in widget tests.
typedef NavigationMapBuilder = Widget Function(
  BuildContext context,
  NavigationMapModel model,
);

/// Live navigation: map following the position, the [NextStopCard] and status
/// overlays, and the [RouteSheet] in navigation mode with what is left.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    super.key,
    required this.plan,
    required this.onExit,
    required this.onNewRoute,
    this.cubit,
    this.mapBuilder,
    this.markers,
    this.appLauncher,
  });

  final RoutePlan plan;

  /// Called on "Encerrar" once the stream is stopped.
  final VoidCallback onExit;

  final VoidCallback onNewRoute;

  /// Overrides the cubit from `getIt` (tests).
  final NavigationCubit? cubit;

  final NavigationMapBuilder? mapBuilder;

  final MapMarkers? markers;

  /// Overrides the launcher from `getIt` (tests).
  final NavigationAppLauncher? appLauncher;

  static const String title = 'Navegação';
  static const String startLabel = 'Iniciar';
  static const String stopLabel = 'Encerrar';
  static const String waitingGpsCaption = 'Aguardando sinal de GPS';
  static const String recenterLabel = 'Recentralizar';
  static const String offlineBanner = 'Sem conexão';
  static const String completedTitle = 'Rota concluída';
  static const String newRouteLabel = 'Nova rota';

  /// Sheet totals while navigating:
  /// `"Faltam 8,4 km · 22 min · término às 15:10"`.
  static String remaining(RouteProgress progress) =>
      'Faltam ${formatDistance(progress.remainingMeters)} · '
      '${formatDuration(progress.remainingSeconds)} · '
      'término às ${formatClock(progress.finalArrival)}';

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
  late final NavigationAppLauncher _appLauncher =
      widget.appLauncher ?? getIt<NavigationAppLauncher>();

  RoutePlan? _iconsPlan;
  Future<_Icons>? _icons;
  Offset? _pointerDown;

  /// Heights of the persistent overlays, measured after layout.
  double _topInset = 0;
  double _bottomInset = 0;

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

  NavigationMapModel _model(
    NavigationState state,
    _Icons icons,
    Color routeColor,
  ) {
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
      routeColor: routeColor,
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
      padding: EdgeInsets.only(top: _topInset, bottom: _bottomInset),
    );
  }

  void _onTopMeasured(Size size) {
    if (mounted && size.height != _topInset) {
      setState(() => _topInset = size.height);
    }
  }

  void _onBottomMeasured(Size size) {
    if (mounted && size.height != _bottomInset) {
      setState(() => _bottomInset = size.height);
    }
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

  void _openInApp(Stop stop) =>
      OpenInAppSheet.show(context, stop: stop, launcher: _appLauncher);

  @override
  Widget build(BuildContext context) {
    final mapBuilder = widget.mapBuilder ?? _googleMap;
    return BlocBuilder<NavigationCubit, NavigationState>(
      bloc: _cubit,
      builder: (context, state) {
        final rb = context.rb;
        final navigating = state.phase == NavigationPhase.navigating;
        final completed = state.phase == NavigationPhase.completed;
        final progress = navigating ? state.progress : null;
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
                          ? ColoredBox(color: context.rb.surface100)
                          : mapBuilder(
                              context,
                              _model(state, icons, context.rb.brand),
                            );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TopOverlay(
                  state: state,
                  onMeasured: _onTopMeasured,
                  onOpenInApp: _openInApp,
                ),
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
                          backgroundColor: rb.surface200,
                          foregroundColor: rb.brand,
                          icon: const Icon(Icons.my_location),
                          label: const Text(NavigationScreen.recenterLabel),
                        ),
                      ),
                    MeasureSize(
                      onChange: _onBottomMeasured,
                      child: completed
                          ? _Completed(onNewRoute: widget.onNewRoute)
                          : RouteSheet(
                              plan: state.plan,
                              startEnabled: navigating || state.canStart,
                              startLabel: navigating
                                  ? NavigationScreen.stopLabel
                                  : NavigationScreen.startLabel,
                              startColor: navigating ? rb.danger : null,
                              onStart: navigating ? _stop : _cubit.start,
                              onMarkVisited: navigating
                                  ? _cubit.markNextVisited
                                  : null,
                              totals: progress == null
                                  ? null
                                  : NavigationScreen.remaining(progress),
                              footer: navigating || state.canStart
                                  ? null
                                  : const _WaitingGps(),
                            ),
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
      padding: model.padding,
      onMapCreated: (controller) => _controller = controller,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      style: mapStyleFor(Theme.of(context).brightness),
    );
  }
}

/// Offline banner and the next stop (while navigating) at the top of the map,
/// with the recalculation badge and the GPS error under them.
class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.state,
    required this.onMeasured,
    required this.onOpenInApp,
  });

  final NavigationState state;
  final ValueChanged<Stop> onOpenInApp;

  /// Size of the banner and the card, which stay while navigating; the
  /// transient chips are left out so they never shift the map.
  final ValueChanged<Size> onMeasured;

  @override
  Widget build(BuildContext context) {
    final next = state.phase == NavigationPhase.navigating
        ? state.plan.nextStop
        : null;
    final badge = state.badge;
    final error = state.error;
    final chips = [
      if (badge != null)
        _Card(
          child: RbStatusChip(
            label: badge.text,
            tone: badge.kind == BadgeKind.recalcFailed
                ? RbTone.danger
                : RbTone.warning,
          ),
        ),
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
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MeasureSize(
          onChange: onMeasured,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!state.online)
                const RbBanner(
                  text: NavigationScreen.offlineBanner,
                  tone: RbTone.danger,
                ),
              if (next != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RbSpace.s3,
                    RbSpace.s3,
                    RbSpace.s3,
                    0,
                  ),
                  child: NextStopCard(
                    stop: next,
                    progress: state.progress,
                    onOpenInApp: () => onOpenInApp(next.stop),
                  ),
                ),
            ],
          ),
        ),
        if (chips.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              RbSpace.s3,
              next == null ? RbSpace.s3 : RbSpace.s2,
              RbSpace.s3,
              RbSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, chip) in chips.indexed) ...[
                  if (i > 0) const SizedBox(height: RbSpace.s2),
                  chip,
                ],
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
        color: context.rb.surface200,
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
        style: RbText.caption.copyWith(color: context.rb.inkMuted),
      ),
    );
  }
}

class _Completed extends StatelessWidget {
  const _Completed({required this.onNewRoute});

  final VoidCallback onNewRoute;

  @override
  Widget build(BuildContext context) {
    final rb = context.rb;
    return Container(
      padding: const EdgeInsets.all(RbSpace.s3),
      decoration: BoxDecoration(
        color: rb.surface200,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RbRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              NavigationScreen.completedTitle,
              style: RbText.heading.copyWith(color: rb.success),
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

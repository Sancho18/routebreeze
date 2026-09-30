import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/theme/map_style.dart';
import '../../../core/theme/rb_palette.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/measure_size.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../../addresses/domain/stop.dart';
import '../../route/domain/route_plan.dart';
import '../../route/presentation/map_markers.dart';
import '../../route/presentation/route_format.dart';
import '../../route/presentation/route_map_objects.dart';
import '../../route/presentation/route_sheet.dart';
import '../data/background_tracker.dart';
import '../data/customer_notifier.dart';
import '../data/navigation_app_launcher.dart';
import '../data/notification_permission.dart';
import '../data/route_alerts.dart';
import '../domain/progress_estimator.dart';
import 'customer_message.dart';
import 'failure_reason_sheet.dart';
import 'navigation_cubit.dart';
import 'navigation_notifier.dart';
import 'next_stop_card.dart';
import 'open_in_app_sheet.dart';
import 'return_card.dart';
import 'route_summary_sheet.dart';

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
/// overlays, and the [RouteSheet] in navigation mode with what is left and
/// the result buttons. On the way back of a round trip the [ReturnCard]
/// replaces the card and "Finalizar rota" the result buttons, above
/// "Encerrar". The [RouteSummarySheet] replaces the sheet once the route
/// completes.
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
    this.customerNotifier,
    this.notificationPermission,
    this.routeAlerts,
    this.tracker,
  });

  final RoutePlan plan;

  /// Called on "Encerrar" once the stream is stopped and the route saved.
  final VoidCallback onExit;

  /// "Nova rota" on the summary.
  final VoidCallback onNewRoute;

  /// Overrides the cubit from `getIt` (tests).
  final NavigationCubit? cubit;

  final NavigationMapBuilder? mapBuilder;

  final MapMarkers? markers;

  /// Overrides the launcher from `getIt` (tests).
  final NavigationAppLauncher? appLauncher;

  /// Overrides the notifier from `getIt` (tests).
  final CustomerNotifier? customerNotifier;

  /// Overrides the notification permission from `getIt` (tests).
  final NotificationPermission? notificationPermission;

  /// Overrides the route alerts from `getIt` (tests).
  final RouteAlerts? routeAlerts;

  /// Overrides the tracker from `getIt`, the one the cubit starts (tests).
  final BackgroundTracker? tracker;

  static const String title = 'Navegação';
  static const String startLabel = 'Iniciar';
  static const String stopLabel = 'Encerrar';
  static const String finishLabel = 'Finalizar rota';
  static const String waitingGpsCaption = 'Aguardando sinal de GPS';
  static const String recenterLabel = 'Recentralizar';
  static const String offlineBanner = 'Sem conexão';
  static const String notifyFailedMessage =
      'Não foi possível abrir o compartilhamento.';

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
  late final CustomerNotifier _customerNotifier =
      widget.customerNotifier ?? getIt<CustomerNotifier>();
  late final NotificationPermission _permission =
      widget.notificationPermission ?? getIt<NotificationPermission>();
  late final NavigationNotifier _notifier;
  late final AppLifecycleListener _lifecycle;

  /// Hidden or paused: only then does the notifier alert events.
  bool _inBackground = false;

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
    _notifier = NavigationNotifier(
      states: _cubit.stream,
      initial: _cubit.state,
      tracker: widget.tracker ?? getIt<BackgroundTracker>(),
      alerts: widget.routeAlerts ?? getIt<RouteAlerts>(),
      inBackground: () => _inBackground,
    );
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => _inBackground =
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused,
      onResume: _notifier.onForeground,
    );
    _cubit.prepare();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_notifier.dispose());
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
        returnTo: plan.returnTo,
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

  /// Set by the first "Iniciar" until the permission is answered: a second
  /// tap meanwhile would ask again and start before the answer.
  bool _starting = false;

  /// "Iniciar": the first time, the notification permission is asked, and
  /// the navigation starts after the answer, whatever it is.
  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    await _permission.requestOnce();
    _starting = false;
    if (mounted) _cubit.start();
  }

  /// Set by the first exit: a second one while the save runs would pop the
  /// screen below too.
  bool _leaving = false;

  /// Leaves once the route is saved, so the screen below reads that save;
  /// a failed save still leaves.
  Future<void> _stop() async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _cubit.stop();
    } finally {
      if (mounted) widget.onExit();
    }
  }

  /// "Não entregue": the reason picked records the next stop; closing the
  /// sheet records nothing.
  Future<void> _notDelivered() async {
    final reason = await FailureReasonSheet.show(context);
    if (reason != null) await _cubit.recordFailed(reason);
  }

  void _openInApp(Stop stop) =>
      OpenInAppSheet.show(context, stop: stop, launcher: _appLauncher);

  /// "Avisar cliente": the message for the current state through the share
  /// sheet, anchored to the button at [origin]; a sheet that cannot open
  /// shows [NavigationScreen.notifyFailedMessage].
  Future<void> _notifyCustomer(Rect origin) async {
    final state = _cubit.state;
    final opened = await _customerNotifier.notify(
      customerMessage(progress: state.progress, arrived: state.arrived),
      origin: origin,
    );
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(NavigationScreen.notifyFailedMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapBuilder = widget.mapBuilder ?? _googleMap;
    return BlocBuilder<NavigationCubit, NavigationState>(
      bloc: _cubit,
      builder: (context, state) {
        final rb = context.rb;
        final navigating = state.phase == NavigationPhase.navigating;
        final completed = state.phase == NavigationPhase.completed;
        final returning = navigating && state.plan.isReturning;
        final progress = navigating ? state.progress : null;
        // The system back takes the screen's own exits: "Nova rota" on the
        // summary, "Encerrar" otherwise, so the route is saved first.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (completed) {
              widget.onNewRoute();
            } else {
              unawaited(_stop());
            }
          },
          child: Scaffold(
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
                // The bottom overlay takes the space under the top one: with
                // large text it scrolls, from its actions up, instead of
                // covering the next stop. Taps outside both reach the map.
                Positioned.fill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopOverlay(
                        state: state,
                        onMeasured: _onTopMeasured,
                        onOpenInApp: _openInApp,
                        onNotifyCustomer: _notifyCustomer,
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SingleChildScrollView(
                            reverse: true,
                            // Hits beside the button and the sheet reach the
                            // map.
                            hitTestBehavior: HitTestBehavior.deferToChild,
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
                                      foregroundColor: rb.brandStrong,
                                      icon: Icon(
                                        Icons.my_location,
                                        color: rb.brand,
                                      ),
                                      label: const Text(
                                        NavigationScreen.recenterLabel,
                                      ),
                                    ),
                                  ),
                                MeasureSize(
                                  onChange: _onBottomMeasured,
                                  child: completed
                                      ? RouteSummarySheet(
                                          summary: state.summary!,
                                          onNewRoute: widget.onNewRoute,
                                        )
                                      : RouteSheet(
                                          plan: state.plan,
                                          startEnabled:
                                              navigating || state.canStart,
                                          startLabel: navigating
                                              ? NavigationScreen.stopLabel
                                              : NavigationScreen.startLabel,
                                          startColor: navigating
                                              ? rb.dangerStrong
                                              : null,
                                          onStart: navigating ? _stop : _start,
                                          onDelivered: navigating
                                              ? _cubit.recordDelivered
                                              : null,
                                          onNotDelivered: navigating
                                              ? _notDelivered
                                              : null,
                                          // On the way back every stop has
                                          // a result, so no result buttons
                                          // show: "Finalizar rota" takes
                                          // their place, above "Encerrar".
                                          finishLabel: returning
                                              ? NavigationScreen.finishLabel
                                              : null,
                                          onFinish: _cubit.finishRoute,
                                          totals: progress == null
                                              ? null
                                              : NavigationScreen.remaining(
                                                  progress,
                                                ),
                                          footer: navigating || state.canStart
                                              ? null
                                              : const _WaitingGps(),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

/// Offline banner and, while navigating, the next stop or the way back of a
/// round trip at the top of the map, with the recalculation badge and the
/// GPS error under them.
class _TopOverlay extends StatelessWidget {
  const _TopOverlay({
    required this.state,
    required this.onMeasured,
    required this.onOpenInApp,
    required this.onNotifyCustomer,
  });

  final NavigationState state;
  final ValueChanged<Stop> onOpenInApp;
  final ValueChanged<Rect> onNotifyCustomer;

  /// Size of the banner and the card, which stay while navigating; the
  /// transient chips are left out so they never shift the map.
  final ValueChanged<Size> onMeasured;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan;
    final navigating = state.phase == NavigationPhase.navigating;
    final next = navigating ? plan.nextStop : null;
    final returnTo = navigating && plan.isReturning ? plan.returnTo : null;
    final card = next != null
        ? NextStopCard(
            stop: next,
            progress: state.progress,
            arrived: state.arrived,
            onOpenInApp: () => onOpenInApp(next.stop),
            onNotifyCustomer: onNotifyCustomer,
          )
        : returnTo != null
        // The start has no place id: apps get its coordinates.
        ? ReturnCard(
            progress: state.progress,
            onOpenInApp: () =>
                onOpenInApp(Stop('', ReturnCard.title, returnTo)),
          )
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
            child: RbInlineError(text: error, liveRegion: true),
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
              if (card != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RbSpace.s3,
                    RbSpace.s3,
                    RbSpace.s3,
                    0,
                  ),
                  child: card,
                ),
            ],
          ),
        ),
        if (chips.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              RbSpace.s3,
              card == null ? RbSpace.s3 : RbSpace.s2,
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

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/core/widgets/rb_route_loader.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

class MockMapCubit extends MockCubit<MapState> implements MapCubit {}

void main() {
  late MockMapCubit cubit;
  late List<Fix> continued;
  late List<(RoutePlan, Fix)> resumed;
  late List<Fix> mapsBuilt;
  late List<VoidCallback> mapReadyCallbacks;

  const mapKey = Key('map-placeholder');
  final overlay = find.byType(RbRouteLoader);

  /// Lets a reported map pass the tiles grace and the overlay fade out.
  Future<void> settleOverlay(WidgetTester tester) async {
    await tester.pump(MapScreen.tilesDelay);
    await tester.pumpAndSettle();
  }

  final start = Fix(
    const GeoPoint(-23.5614, -46.6559),
    12,
    DateTime.utc(2026, 9, 22, 10),
  );

  const deniedMessage =
      'Precisamos da sua localização para seguir. '
      'Ela define o ponto de partida da sua rota.';
  const impreciseMessage =
      'Não conseguimos uma posição precisa. '
      'Verifique se está em local aberto.';

  setUp(() {
    cubit = MockMapCubit();
    continued = [];
    resumed = [];
    mapsBuilt = [];
    mapReadyCallbacks = [];
    when(() => cubit.init()).thenAnswer((_) async {});
    when(() => cubit.dismissResume()).thenAnswer((_) async {});
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.openSettings()).thenAnswer((_) async {});
  });

  /// Pumps the screen; the map reports itself ready unless [mapReady] is
  /// false, and then the overlay fades so the card is reachable.
  Future<void> pumpMap(
    WidgetTester tester,
    MapState state, {
    Stream<MapState> states = const Stream.empty(),
    bool mapReady = true,
    ThemeMode? mode,
  }) async {
    whenListen(cubit, states, initialState: state);
    final screen = MapScreen(
      cubit: cubit,
      mapBuilder: (_, fix, onMapReady) {
        mapsBuilt.add(fix);
        mapReadyCallbacks.add(onMapReady);
        if (mapReady) onMapReady();
        return const SizedBox.expand(key: mapKey);
      },
      onContinue: continued.add,
      onResume: (plan, start) => resumed.add((plan, start)),
    );
    await tester.pumpWidget(
      mode == null ? MaterialApp(home: screen) : themedApp(screen, mode: mode),
    );
    await tester.pump();
    if (mapReady && state.status == MapStatus.ready) {
      await settleOverlay(tester);
    }
  }

  Future<void> setLifecycle(WidgetTester tester, AppLifecycleState state) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );

  final ctaFinder = find.widgetWithText(RbPrimaryButton, 'Para onde vamos?');

  RbPrimaryButton cta(WidgetTester tester) =>
      tester.widget<RbPrimaryButton>(ctaFinder);

  void expectCtaDisabled(WidgetTester tester) {
    expect(cta(tester).enabled, isFalse);
    final material = tester.widget<Material>(
      find.descendant(of: ctaFinder, matching: find.byType(Material)).first,
    );
    expect(material.color, RbColors.border);
    final label = tester.widget<Text>(
      find.descendant(of: ctaFinder, matching: find.text('Para onde vamos?')),
    );
    expect(label.style!.color, RbColors.inkMuted);
  }

  void expectDangerBody(WidgetTester tester, String message) {
    final text = tester.widget<Text>(find.text(message));
    expect(text.style!.color, const Color(0xFFD01E23));
    expect(text.style!.fontSize, 15);
    expect(text.style!.fontWeight, FontWeight.w400);
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(RbPrimaryButton, label));
    await tester.pump();
  }

  final plan = RoutePlan(
    origin: const GeoPoint(-23.5614, -46.6559),
    stops: const [
      RouteStop(
        stop: Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66)),
        order: 1,
      ),
    ],
    polyline: const [],
    distanceMeters: 600,
    durationSeconds: 60,
    legs: const [],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );
  final ready = MapState(status: MapStatus.ready, start: start);
  final offered = MapState(
    status: MapStatus.ready,
    start: start,
    resumable: plan,
  );

  Future<void> pumpOffer(WidgetTester tester, {ThemeMode? mode}) async {
    await pumpMap(tester, ready, states: Stream.value(offered), mode: mode);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Continuar rota?'), findsOneWidget);
  }

  group('MapScreen', () {
    testWidgets('checking: starts init and covers the screen with the '
        'branded loading (app name in display, route loader, caption) '
        'instead of the card', (tester) async {
      await pumpMap(tester, const MapState());

      verify(() => cubit.init()).called(1);
      expect(find.byKey(mapKey), findsNothing);
      expect(ctaFinder, findsNothing);
      expect(overlay, findsOneWidget);

      final title = tester.widget<Text>(find.text('RouteBreeze'));
      expect(title.style!.fontSize, 34);
      expect(title.style!.fontWeight, FontWeight.w700);
      expect(title.style!.color, RbColors.ink);
      final caption = tester.widget<Text>(
        find.text('Obtendo sua localização...'),
      );
      expect(caption.style!.fontSize, 13);
      expect(caption.style!.color, RbColors.inkMuted);
      final background = tester.widget<ColoredBox>(
        find
            .ancestor(
              of: find.text('RouteBreeze'),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(background.color, RbColors.surface100);
      expect(
        tester.getTopLeft(overlay).dy,
        greaterThan(tester.getBottomLeft(find.text('RouteBreeze')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Obtendo sua localização...')).dy,
        greaterThan(tester.getBottomLeft(overlay).dy),
      );

      // Still loading after a long wait: no fallback while the fix is unknown.
      await tester.pump(MapScreen.maxMapWait + MapScreen.tilesDelay);
      await tester.pump(MapScreen.fadeDuration);
      expect(overlay, findsOneWidget);
    });

    testWidgets('ready: the overlay stays until the map reports itself '
        'created, then waits the tiles grace and fades out', (tester) async {
      await pumpMap(
        tester,
        MapState(status: MapStatus.ready, start: start),
        mapReady: false,
      );

      expect(find.byKey(mapKey), findsOneWidget);
      expect(overlay, findsOneWidget);
      expect(mapReadyCallbacks, hasLength(1));

      mapReadyCallbacks.first();
      await tester.pump();
      expect(overlay, findsOneWidget);
      await tester.pump(MapScreen.tilesDelay);
      await tester.pump();
      // Fading: still in the tree, on its way out.
      expect(overlay, findsOneWidget);
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
      expect(find.text('RouteBreeze'), findsNothing);
      expect(cta(tester).enabled, isTrue);

      // A second report is a no-op.
      mapReadyCallbacks.first();
      await settleOverlay(tester);
      expect(overlay, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ready: the overlay gives up after maxMapWait when the map '
        'never reports itself created', (tester) async {
      await pumpMap(
        tester,
        MapState(status: MapStatus.ready, start: start),
        mapReady: false,
      );

      await tester.pump(MapScreen.maxMapWait - const Duration(seconds: 1));
      expect(overlay, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
    });

    testWidgets('checking → ready: the fallback starts when the fix arrives', (
      tester,
    ) async {
      await pumpMap(
        tester,
        const MapState(),
        states: Stream.value(MapState(status: MapStatus.ready, start: start)),
        mapReady: false,
      );
      await tester.pump();
      expect(find.byKey(mapKey), findsOneWidget);
      expect(overlay, findsOneWidget);

      await tester.pump(MapScreen.maxMapWait);
      await tester.pumpAndSettle();
      expect(overlay, findsNothing);
    });

    testWidgets('errors show the card at once, and a retry brings the '
        'loading back', (tester) async {
      final states = StreamController<MapState>();
      addTearDown(states.close);
      await pumpMap(
        tester,
        const MapState(status: MapStatus.denied),
        states: states.stream,
        mapReady: false,
      );
      expect(overlay, findsNothing);
      expect(find.text(deniedMessage), findsOneWidget);

      states.add(const MapState());
      await tester.pump();
      await tester.pump();
      expect(overlay, findsOneWidget);
      expect(ctaFinder, findsNothing);
      await tester.pump(MapScreen.fadeDuration);
      expect(overlay, findsOneWidget);
    });

    testWidgets('the card keeps the CTA disabled while the fix is unusable', (
      tester,
    ) async {
      await pumpMap(tester, const MapState(status: MapStatus.timeout));

      expect(overlay, findsNothing);
      expectCtaDisabled(tester);
      final card = tester.widget<Container>(
        find.ancestor(of: ctaFinder, matching: find.byType(Container)).first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.surface200);
      expect(decoration.borderRadius, BorderRadius.circular(24));
      expect(card.padding, const EdgeInsets.all(16));
    });

    group('in dark mode', () {
      testWidgets('the loading overlay is #0F1115 with a #F2F4F7 title, a '
          '#A4ACB9 caption and the loader in #2F343D / #7EA6F8', (
        tester,
      ) async {
        await pumpMap(tester, const MapState(), mode: ThemeMode.dark);

        final background = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.text('RouteBreeze'),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(background.color, const Color(0xFF0F1115));
        expect(
          tester.widget<Text>(find.text('RouteBreeze')).style!.color,
          const Color(0xFFF2F4F7),
        );
        expect(
          tester
              .widget<Text>(find.text('Obtendo sua localização...'))
              .style!
              .color,
          const Color(0xFFA4ACB9),
        );
        final loader =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: overlay,
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as RouteLoaderPainter;
        expect(loader.track, const Color(0xFF2F343D));
        expect(loader.stroke, const Color(0xFF7EA6F8));
      });

      testWidgets('the status card is #1A1D23 over the #0F1115 background, '
          'with its caption in #A4ACB9', (tester) async {
        await pumpMap(
          tester,
          const MapState(status: MapStatus.deniedForever),
          mode: ThemeMode.dark,
        );

        final card = tester.widget<Container>(
          find.ancestor(of: ctaFinder, matching: find.byType(Container)).first,
        );
        expect(
          (card.decoration! as BoxDecoration).color,
          const Color(0xFF1A1D23),
        );
        expect(
          tester
              .widget<Text>(
                find.text('Você negou o acesso. Ative em Configurações.'),
              )
              .style!
              .color,
          const Color(0xFFA4ACB9),
        );
        final background = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(MapScreen),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(background.color, const Color(0xFF0F1115));
      });
    });

    testWidgets('ready: builds the map with the start fix and enables the '
        'CTA, which hands the fix to onContinue', (tester) async {
      await pumpMap(tester, MapState(status: MapStatus.ready, start: start));

      expect(find.byKey(mapKey), findsOneWidget);
      expect(mapsBuilt, everyElement(start));
      expect(find.text('Ponto de partida definido'), findsOneWidget);
      expect(cta(tester).enabled, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(ctaFinder);
      await tester.pump();

      expect(continued, [start]);
    });

    testWidgets('denied: message in danger and "Permitir localização" '
        'retries; CTA disabled', (tester) async {
      await pumpMap(tester, const MapState(status: MapStatus.denied));

      expectDangerBody(tester, deniedMessage);
      expect(
        find.text('Você negou o acesso. Ative em Configurações.'),
        findsNothing,
      );
      expect(find.byKey(mapKey), findsNothing);
      expectCtaDisabled(tester);

      await tapAction(tester, 'Permitir localização');

      verify(() => cubit.retry()).called(1);
      verifyNever(() => cubit.openSettings());
      expect(continued, isEmpty);
    });

    testWidgets('deniedForever: message, caption and "Abrir configurações" '
        'opens the settings; CTA disabled', (tester) async {
      await pumpMap(tester, const MapState(status: MapStatus.deniedForever));

      expectDangerBody(tester, deniedMessage);
      final caption = tester.widget<Text>(
        find.text('Você negou o acesso. Ative em Configurações.'),
      );
      expect(caption.style!.fontSize, 13);
      expect(caption.style!.height, 18 / 13);
      expectCtaDisabled(tester);

      await tapAction(tester, 'Abrir configurações');

      verify(() => cubit.openSettings()).called(1);
      verifyNever(() => cubit.retry());
    });

    testWidgets('serviceDisabled: message and "Ativar localização" opens '
        'the settings; CTA disabled', (tester) async {
      await pumpMap(tester, const MapState(status: MapStatus.serviceDisabled));

      expectDangerBody(
        tester,
        'Ative a localização do dispositivo para continuar.',
      );
      expectCtaDisabled(tester);

      await tapAction(tester, 'Ativar localização');

      verify(() => cubit.openSettings()).called(1);
      verifyNever(() => cubit.retry());
    });

    for (final status in [MapStatus.timeout, MapStatus.imprecise]) {
      testWidgets('${status.name}: imprecise message and "Tentar novamente" '
          'retries; CTA disabled', (tester) async {
        await pumpMap(tester, MapState(status: status));

        expectDangerBody(tester, impreciseMessage);
        expect(find.byKey(mapKey), findsNothing);
        expectCtaDisabled(tester);

        await tapAction(tester, 'Tentar novamente');

        verify(() => cubit.retry()).called(1);
        verifyNever(() => cubit.openSettings());
      });
    }

    group('coming back from Settings', () {
      for (final status in [
        MapStatus.denied,
        MapStatus.deniedForever,
        MapStatus.serviceDisabled,
      ]) {
        testWidgets('${status.name}: resuming the app re-checks once', (
          tester,
        ) async {
          await pumpMap(tester, MapState(status: status));

          await setLifecycle(tester, AppLifecycleState.paused);
          await setLifecycle(tester, AppLifecycleState.resumed);
          await tester.pump();

          verify(() => cubit.retry()).called(1);
        });
      }

      for (final status in [
        MapStatus.checking,
        MapStatus.timeout,
        MapStatus.imprecise,
      ]) {
        testWidgets('${status.name}: resuming the app does not re-check', (
          tester,
        ) async {
          await pumpMap(tester, MapState(status: status));

          await setLifecycle(tester, AppLifecycleState.paused);
          await setLifecycle(tester, AppLifecycleState.resumed);
          await tester.pump();

          verifyNever(() => cubit.retry());
        });
      }

      testWidgets('ready: resuming the app keeps the start fix', (
        tester,
      ) async {
        await pumpMap(tester, MapState(status: MapStatus.ready, start: start));

        await setLifecycle(tester, AppLifecycleState.paused);
        await setLifecycle(tester, AppLifecycleState.resumed);
        await tester.pump();

        verifyNever(() => cubit.retry());
        expect(find.byKey(mapKey), findsOneWidget);
      });
    });

    group('resume offer', () {
      testWidgets('a resumable plan opens "Continuar rota?"; "Continuar" '
          'hands the plan and the start fix over', (tester) async {
        await pumpOffer(tester);

        await tester.tap(find.widgetWithText(TextButton, 'Continuar'));
        await tester.pumpAndSettle();

        expect(resumed, [(plan, start)]);
        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => cubit.dismissResume());
      });

      testWidgets('"Nova rota" dismisses the offer and clears the persisted '
          'route', (tester) async {
        await pumpOffer(tester);

        await tester.tap(find.widgetWithText(TextButton, 'Nova rota'));
        await tester.pumpAndSettle();

        verify(() => cubit.dismissResume()).called(1);
        expect(resumed, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('ready without a persisted route shows no dialog', (
        tester,
      ) async {
        await pumpMap(tester, ready);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('light mode: "Nova rota" and "Continuar" in #1B63F3', (
        tester,
      ) async {
        await pumpOffer(tester, mode: ThemeMode.light);

        for (final action in ['Nova rota', 'Continuar']) {
          final label = tester.widget<RichText>(
            find.descendant(
              of: find.widgetWithText(TextButton, action),
              matching: find.byType(RichText),
            ),
          );
          expect(label.text.style!.color, const Color(0xFF1B63F3));
        }
      });

      testWidgets('dark mode: #1A1D23 dialog with a #F2F4F7 title, #A4ACB9 '
          'body and #7EA6F8 actions', (tester) async {
        await pumpOffer(tester, mode: ThemeMode.dark);

        final surface = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(surface.color, const Color(0xFF1A1D23));
        expect(
          tester.widget<Text>(find.text('Continuar rota?')).style!.color,
          const Color(0xFFF2F4F7),
        );
        expect(
          tester.widget<Text>(find.text(MapScreen.resumeBody)).style!.color,
          const Color(0xFFA4ACB9),
        );
        for (final action in ['Nova rota', 'Continuar']) {
          final label = tester.widget<RichText>(
            find.descendant(
              of: find.widgetWithText(TextButton, action),
              matching: find.byType(RichText),
            ),
          );
          expect(label.text.style!.color, const Color(0xFF7EA6F8));
        }
      });
    });
  });

  group('MapScreen accessibility', () {
    /// The top text of [status]: the overlay title or the card's first line.
    String shown(MapStatus status) => switch (status) {
      MapStatus.checking => MapScreen.loadingTitle,
      MapStatus.ready => 'Ponto de partida definido',
      MapStatus.denied || MapStatus.deniedForever => deniedMessage,
      MapStatus.serviceDisabled =>
        'Ative a localização do dispositivo para continuar.',
      MapStatus.timeout || MapStatus.imprecise => impreciseMessage,
    };

    MapState stateOf(MapStatus status) => MapState(
      status: status,
      start: status == MapStatus.ready ? start : null,
    );

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final status in MapStatus.values) {
        testWidgets('${status.name} meets the contrast, tap target and label '
            'guidelines in ${mode.name} mode', (tester) async {
          await pumpMap(tester, stateOf(status), mode: mode);
          expect(find.text(shown(status)), findsOneWidget);

          await expectAccessibleGuidelines(tester);
        });
      }

      testWidgets('"Continuar rota?" meets the contrast, tap target and label '
          'guidelines in ${mode.name} mode', (tester) async {
        await pumpOffer(tester, mode: mode);

        await expectAccessibleGuidelines(tester);
      });
    }

    for (final status in MapStatus.values) {
      testWidgets('${status.name} lays out at 200% text on a 360×800 phone', (
        tester,
      ) async {
        await setLargeTextPhone(tester);
        await pumpMap(tester, stateOf(status), mode: ThemeMode.light);

        expect(tester.takeException(), isNull);
        expectNoClippedText(tester);
        // The status card is anchored at the bottom: too much content would
        // push its first line above the screen without an overflow error.
        expect(
          tester.getTopLeft(find.text(shown(status))).dy,
          greaterThanOrEqualTo(0),
        );
      });
    }

    testWidgets('"Continuar rota?" lays out at 200% text on a 360×800 phone', (
      tester,
    ) async {
      await setLargeTextPhone(tester);
      await pumpOffer(tester, mode: ThemeMode.light);

      expect(find.text(MapScreen.resumeBody), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectNoClippedText(tester);
    });
  });
}

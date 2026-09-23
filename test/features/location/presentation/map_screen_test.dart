import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';

class MockMapCubit extends MockCubit<MapState> implements MapCubit {}

void main() {
  late MockMapCubit cubit;
  late List<Fix> continued;
  late List<(RoutePlan, Fix)> resumed;
  late List<Fix> mapsBuilt;

  const mapKey = Key('map-placeholder');
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
    when(() => cubit.init()).thenAnswer((_) async {});
    when(() => cubit.dismissResume()).thenAnswer((_) async {});
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.openSettings()).thenAnswer((_) async {});
  });

  Future<void> pumpMap(
    WidgetTester tester,
    MapState state, {
    Stream<MapState> states = const Stream.empty(),
  }) async {
    whenListen(cubit, states, initialState: state);
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          cubit: cubit,
          mapBuilder: (_, fix) {
            mapsBuilt.add(fix);
            return const SizedBox.expand(key: mapKey);
          },
          onContinue: continued.add,
          onResume: (plan, start) => resumed.add((plan, start)),
        ),
      ),
    );
    await tester.pump();
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
    expect(text.style!.color, RbColors.danger);
    expect(text.style!.fontSize, 15);
    expect(text.style!.fontWeight, FontWeight.w400);
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(RbPrimaryButton, label));
    await tester.pump();
  }

  group('MapScreen', () {
    testWidgets('checking: starts init, shows the progress copy on a '
        'surface-200 card and keeps the CTA disabled', (tester) async {
      await pumpMap(tester, const MapState());

      verify(() => cubit.init()).called(1);
      expect(find.text('Obtendo sua localização...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(mapKey), findsNothing);
      expectCtaDisabled(tester);

      final card = tester.widget<Container>(
        find.ancestor(of: ctaFinder, matching: find.byType(Container)).first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, RbColors.surface200);
      expect(decoration.borderRadius, BorderRadius.circular(24));
      expect(card.padding, const EdgeInsets.all(16));
    });

    testWidgets('ready: builds the map with the start fix and enables the '
        'CTA, which hands the fix to onContinue', (tester) async {
      await pumpMap(tester, MapState(status: MapStatus.ready, start: start));

      expect(find.byKey(mapKey), findsOneWidget);
      expect(mapsBuilt, [start]);
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
      final plan = RoutePlan(
        origin: const GeoPoint(-23.5614, -46.6559),
        stops: const [
          RouteStop(
            stop: Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66)),
            order: 1,
            visited: false,
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

      Future<void> pumpOffer(WidgetTester tester) async {
        await pumpMap(tester, ready, states: Stream.value(offered));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Continuar rota?'), findsOneWidget);
      }

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
    });
  });
}

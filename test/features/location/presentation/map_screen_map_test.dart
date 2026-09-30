import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/map_style.dart';
import 'package:routebreeze/core/widgets/rb_route_loader.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';

import '../../../helpers/fake_google_map.dart';
import '../../../helpers/themed_app.dart';

class MockMapCubit extends MockCubit<MapState> implements MapCubit {}

void main() {
  final start = Fix(
    const GeoPoint(-23.5614, -46.6559),
    12,
    DateTime.utc(2026, 9, 22, 10),
  );

  testWidgets('ready mounts a GoogleMap centered on the start at zoom 16 '
      'with the "Partida" marker', (tester) async {
    final platform = FakeGoogleMapPlatform.install(tester);
    final cubit = MockMapCubit();
    when(() => cubit.init()).thenAnswer((_) async {});
    whenListen(
      cubit,
      const Stream<MapState>.empty(),
      initialState: MapState(status: MapStatus.ready, start: start),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(cubit: cubit, onContinue: (_) {}, onResume: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMap), findsOneWidget);
    // onMapCreated fired through the fake channel: the loading is gone.
    expect(find.byType(RbRouteLoader), findsNothing);
    expect(find.text(MapScreen.loadingTitle), findsNothing);
    final map = platform.maps.single;
    expect(map.initialCameraPosition['zoom'], 16.0);
    expect(map.initialCameraPosition['target'], [-23.5614, -46.6559]);
    final marker = map.markersToAdd.single as Map<Object?, Object?>;
    expect(marker['markerId'], 'start');
    expect(marker['position'], [-23.5614, -46.6559]);
    expect((marker['infoWindow'] as Map<Object?, Object?>)['title'], 'Partida');
    expect(map.callsOf('map#waitForMap'), hasLength(1));
  });

  group('map style', () {
    /// The screen with a ready start fix, so the default map builder runs.
    MapScreen readyScreen() {
      final cubit = MockMapCubit();
      when(() => cubit.init()).thenAnswer((_) async {});
      whenListen(
        cubit,
        const Stream<MapState>.empty(),
        initialState: MapState(status: MapStatus.ready, start: start),
      );
      return MapScreen(cubit: cubit, onContinue: (_) {}, onResume: (_, _) {});
    }

    testWidgets('dark mode creates the map with the dark style', (
      tester,
    ) async {
      final platform = FakeGoogleMapPlatform.install(tester);

      await tester.pumpWidget(themedApp(readyScreen(), mode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(platform.maps.single.style, rbDarkMapStyle);
    });

    testWidgets('light mode creates the map with Google\'s default style', (
      tester,
    ) async {
      final platform = FakeGoogleMapPlatform.install(tester);

      await tester.pumpWidget(themedApp(readyScreen()));
      await tester.pumpAndSettle();

      expect(platform.maps.single.style, '');
    });

    testWidgets('a device theme switch restyles the same map', (tester) async {
      final platform = FakeGoogleMapPlatform.install(tester);
      final dispatcher = tester.binding.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(themedApp(readyScreen(), mode: ThemeMode.system));
      await tester.pumpAndSettle();
      final map = platform.maps.single;
      expect(map.style, '');

      dispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(map.styleUpdates, [rbDarkMapStyle]);

      dispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(map.styleUpdates, [rbDarkMapStyle, '']);

      expect(platform.maps, hasLength(1));
      expect(find.byType(GoogleMap), findsOneWidget);
    });
  });
}

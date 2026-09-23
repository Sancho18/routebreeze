import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/location/domain/fix.dart';
import 'package:routebreeze/features/location/presentation/map_cubit.dart';
import 'package:routebreeze/features/location/presentation/map_screen.dart';

import '../../../helpers/fake_google_map.dart';

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
    final map = platform.maps.single;
    expect(map.initialCameraPosition['zoom'], 16.0);
    expect(map.initialCameraPosition['target'], [-23.5614, -46.6559]);
    final marker = map.markersToAdd.single as Map<Object?, Object?>;
    expect(marker['markerId'], 'start');
    expect(marker['position'], [-23.5614, -46.6559]);
    expect((marker['infoWindow'] as Map<Object?, Object?>)['title'], 'Partida');
    expect(map.callsOf('map#waitForMap'), hasLength(1));
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/route/data/route_storage.dart';
import 'package:routebreeze/features/route/domain/route_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const origin = GeoPoint(-23.5614, -46.6559);
  final plan = RoutePlan(
    origin: origin,
    stops: const [
      RouteStop(
        stop: Stop('pa', 'Rua A, 1', GeoPoint(-23.565, -46.66)),
        order: 1,
        visited: true,
      ),
      RouteStop(
        stop: Stop('pb', 'Rua B, 2', GeoPoint(-23.60, -46.70)),
        order: 2,
        visited: false,
      ),
    ],
    polyline: const [origin, GeoPoint(-23.60, -46.70)],
    distanceMeters: 6000,
    durationSeconds: 480,
    legs: const [
      RouteLeg(distanceMeters: 600, durationSeconds: 60),
      RouteLeg(distanceMeters: 5400, durationSeconds: 420),
    ],
    computedAt: DateTime.utc(2026, 9, 22, 10, 30),
  );

  late RouteStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = RouteStorageImpl();
  });

  group('RouteStorage', () {
    test('save persists the plan as JSON under active_route and load '
        'restores it', () async {
      await storage.save(plan);

      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('active_route')!), plan.toJson());
      expect(await storage.load(), plan);
    });

    test('load is null without a persisted route', () async {
      expect(await storage.load(), isNull);
    });

    test('clear removes the persisted route', () async {
      await storage.save(plan);

      await storage.clear();

      expect(await storage.load(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('active_route'), isFalse);
    });

    test('corrupt JSON is treated as no route and removed', () async {
      SharedPreferences.setMockInitialValues({'active_route': '{not json'});

      expect(await storage.load(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('active_route'), isFalse);
    });
  });
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/network/connectivity_service.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late MockConnectivity connectivity;
  late ConnectivityService service;

  setUp(() {
    connectivity = MockConnectivity();
    service = ConnectivityServiceImpl(connectivity);
  });

  group('check', () {
    test('[none] is offline', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);
      expect(await service.check(), isFalse);
    });

    test('empty result list is offline', () async {
      when(() => connectivity.checkConnectivity()).thenAnswer((_) async => []);
      expect(await service.check(), isFalse);
    });

    test('[wifi] is online', () async {
      when(() => connectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      expect(await service.check(), isTrue);
    });
  });

  group('isOnline', () {
    test('maps each result list and skips repeated values', () async {
      when(() => connectivity.onConnectivityChanged).thenAnswer(
        (_) => Stream.fromIterable([
          [ConnectivityResult.wifi],
          [ConnectivityResult.mobile],
          [ConnectivityResult.none],
          [ConnectivityResult.none],
          [ConnectivityResult.wifi],
        ]),
      );

      expect(await service.isOnline.toList(), [true, false, true]);
    });
  });
}

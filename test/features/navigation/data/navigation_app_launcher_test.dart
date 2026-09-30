import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/data/navigation_app_launcher.dart';
import 'package:routebreeze/features/navigation/domain/navigation_app.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class FakeUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  bool result = true;
  PlatformException? error;
  final launched = <(String, PreferredLaunchMode)>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options.mode));
    if (error case final error?) throw error;
    return result;
  }
}

void main() {
  const stop = Stop(
    'ChIJ_pl-paulista',
    'Av. Paulista, 1000 - Bela Vista, São Paulo',
    GeoPoint(-23.5658, -46.65),
  );

  late FakeUrlLauncher platform;
  late UrlLauncherPlatform original;

  setUp(() {
    original = UrlLauncherPlatform.instance;
    platform = FakeUrlLauncher();
    UrlLauncherPlatform.instance = platform;
  });

  tearDown(() => UrlLauncherPlatform.instance = original);

  group('UrlNavigationAppLauncher', () {
    test('opens the app link as an external application', () async {
      final opened = await UrlNavigationAppLauncher().open(
        NavigationApp.waze,
        stop,
      );

      expect(opened, isTrue);
      expect(platform.launched, [
        (
          NavigationApp.waze.linkTo(stop).toString(),
          PreferredLaunchMode.externalApplication,
        ),
      ]);
    });

    test('false when nothing takes the link', () async {
      platform.result = false;

      expect(
        await UrlNavigationAppLauncher().open(NavigationApp.googleMaps, stop),
        isFalse,
      );
    });

    test('false when the platform fails', () async {
      platform.error = PlatformException(code: 'ACTIVITY_NOT_FOUND');

      expect(
        await UrlNavigationAppLauncher().open(NavigationApp.googleMaps, stop),
        isFalse,
      );
    });
  });
}

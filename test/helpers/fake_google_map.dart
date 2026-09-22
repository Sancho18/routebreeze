// Test double for the platform side of `GoogleMap`: lets the default map
// builders run in widget tests so camera and marker behavior can be asserted
// (MAP-02, ROUTE-03, NAV-02, NAV-03).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// One map created by the widget under test: its decoded creation params
/// and every call the plugin made on that map's method channel.
class FakeMapInstance {
  FakeMapInstance(this.id, this.creationParams);

  final int id;
  final Map<Object?, Object?> creationParams;
  final List<MethodCall> calls = [];

  Map<Object?, Object?> get initialCameraPosition =>
      creationParams['initialCameraPosition'] as Map<Object?, Object?>;

  List<Object?> get markersToAdd =>
      creationParams['markersToAdd'] as List<Object?>;

  List<Object?> get polylinesToAdd =>
      creationParams['polylinesToAdd'] as List<Object?>;

  List<MethodCall> callsOf(String method) =>
      calls.where((call) => call.method == method).toList();

  /// `cameraUpdate` payloads of every `camera#animate` call.
  List<Object?> get cameraAnimations => [
    for (final call in callsOf('camera#animate'))
      (call.arguments as Map<Object?, Object?>)['cameraUpdate'],
  ];
}

/// The method-channel platform (the default under `flutter test`) has no
/// `updateGroundOverlays`; the app draws none, so widget updates skip it.
class _TestGoogleMapsPlatform extends MethodChannelGoogleMapsFlutter {
  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}
}

/// Stubs `flutter/platform_views` (the Android platform view that hosts the
/// map under `flutter test`) and `plugins.flutter.io/google_maps_<id>` (the
/// per-map channel) for one test.
class FakeGoogleMapPlatform {
  FakeGoogleMapPlatform._(this._messenger);

  final TestDefaultBinaryMessenger _messenger;

  /// Maps in creation order.
  final List<FakeMapInstance> maps = [];

  /// When set, the map channel answers [method] with this error
  /// (e.g. `camera#animate` before the view has laid out).
  final Map<String, PlatformException> failures = {};

  /// Installs the stubs and removes them when the test ends.
  static FakeGoogleMapPlatform install(WidgetTester tester) {
    final fake = FakeGoogleMapPlatform._(tester.binding.defaultBinaryMessenger);
    if (GoogleMapsFlutterPlatform.instance is! _TestGoogleMapsPlatform) {
      GoogleMapsFlutterPlatform.instance = _TestGoogleMapsPlatform();
    }
    fake._messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      fake._onPlatformViews,
    );
    addTearDown(() {
      fake._messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      );
      for (final map in fake.maps) {
        fake._messenger.setMockMethodCallHandler(_mapChannel(map.id), null);
      }
    });
    return fake;
  }

  static MethodChannel _mapChannel(int id) =>
      MethodChannel('plugins.flutter.io/google_maps_$id');

  Future<Object?> _onPlatformViews(MethodCall call) async {
    switch (call.method) {
      case 'create':
        final args = call.arguments as Map<Object?, Object?>;
        final id = args['id'] as int;
        final encoded = args['params'] as Uint8List?;
        final params = encoded == null
            ? const <Object?, Object?>{}
            : const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(encoded),
              ) as Map<Object?, Object?>;
        final map = FakeMapInstance(id, params);
        maps.add(map);
        _messenger.setMockMethodCallHandler(
          _mapChannel(id),
          (call) => _onMapCall(map, call),
        );
        return id;
      case 'resize':
        final args = call.arguments as Map<Object?, Object?>;
        return {'width': args['width'], 'height': args['height']};
      default:
        return null;
    }
  }

  Future<Object?> _onMapCall(FakeMapInstance map, MethodCall call) async {
    map.calls.add(call);
    final failure = failures[call.method];
    if (failure != null) throw failure;
    return null;
  }
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routebreeze/features/navigation/data/customer_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The channel `share_plus` talks to the platform through.
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('SharePlusCustomerNotifier', () {
    test('opens the system share sheet with the text, anchored to the '
        'origin, and reports it open', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return 'dev.fluttercommunity.plus/share/unavailable';
      });

      final opened = await SharePlusCustomerNotifier().notify(
        'Olá! Sua entrega chega por volta das 14:32.',
        origin: const Rect.fromLTWH(10, 20, 48, 48),
      );

      expect(opened, isTrue);
      expect(calls.single.method, 'share');
      expect(calls.single.arguments, {
        'text': 'Olá! Sua entrega chega por volta das 14:32.',
        'originX': 10.0,
        'originY': 20.0,
        'originWidth': 48.0,
        'originHeight': 48.0,
      });
    });

    test('reports false when the platform fails to open the sheet', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => throw PlatformException(code: 'error'),
      );

      expect(await SharePlusCustomerNotifier().notify('Olá!'), isFalse);
    });

    test('reports false when no share plugin answers', () async {
      expect(await SharePlusCustomerNotifier().notify('Olá!'), isFalse);
    });
  });
}

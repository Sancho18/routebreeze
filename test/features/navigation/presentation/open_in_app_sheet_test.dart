import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/geo/geo_point.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/features/addresses/domain/stop.dart';
import 'package:routebreeze/features/navigation/data/navigation_app_launcher.dart';
import 'package:routebreeze/features/navigation/domain/navigation_app.dart';
import 'package:routebreeze/features/navigation/presentation/open_in_app_sheet.dart';

import '../../../helpers/themed_app.dart';

class MockNavigationAppLauncher extends Mock implements NavigationAppLauncher {}

void main() {
  const stop = Stop(
    'ChIJ_pl-augusta',
    'Rua Augusta, 500 - Consolação, São Paulo',
    GeoPoint(-23.553, -46.653),
  );

  late MockNavigationAppLauncher launcher;

  setUpAll(() {
    registerFallbackValue(NavigationApp.waze);
    registerFallbackValue(stop);
  });

  setUp(() => launcher = MockNavigationAppLauncher());

  /// Opens the sheet from a button, as the navigation screen does.
  Future<void> pumpAndOpen(WidgetTester tester, {ThemeMode? mode}) async {
    final home = Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () =>
                OpenInAppSheet.show(context, stop: stop, launcher: launcher),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      mode == null ? MaterialApp(home: home) : themedApp(home, mode: mode),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('OpenInAppSheet', () {
    testWidgets('DS bottom sheet: surface-200 with top radius-lg, the heading, '
        'the caption and one row per app in body-strong', (tester) async {
      await pumpAndOpen(tester);

      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, RbColors.surface200);
      expect(
        sheet.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RbRadius.lg),
          ),
        ),
      );
      final heading = tester.widget<Text>(find.text('Abrir em outro app'));
      expect(heading.style!.fontSize, 17);
      expect(heading.style!.color, RbColors.ink);
      final caption = tester.widget<Text>(
        find.text(
          'O RouteBreeze continua acompanhando a rota em segundo plano.',
        ),
      );
      expect(caption.style!.fontSize, 13);
      expect(caption.style!.color, RbColors.inkMuted);
      for (final label in ['Google Maps', 'Waze']) {
        final row = tester.widget<Text>(find.text(label));
        expect(row.style!.fontWeight, FontWeight.w600);
        expect(row.style!.color, RbColors.ink);
      }
      expect(
        tester.getTopLeft(find.text('Google Maps')).dy,
        lessThan(tester.getTopLeft(find.text('Waze')).dy),
      );
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('choosing an app hands the stop to it and closes the sheet', (
      tester,
    ) async {
      when(() => launcher.open(any(), any())).thenAnswer((_) async => true);
      await pumpAndOpen(tester);

      await tester.tap(find.text('Waze'));
      await tester.pumpAndSettle();

      verify(() => launcher.open(NavigationApp.waze, stop)).called(1);
      expect(find.byType(OpenInAppSheet), findsNothing);
    });

    testWidgets('an app that does not open keeps the sheet with "Não foi '
        'possível abrir o Waze." in danger; the other app can be tried', (
      tester,
    ) async {
      when(() => launcher.open(NavigationApp.waze, any()))
          .thenAnswer((_) async => false);
      when(() => launcher.open(NavigationApp.googleMaps, any()))
          .thenAnswer((_) async => true);
      await pumpAndOpen(tester);

      await tester.tap(find.text('Waze'));
      await tester.pumpAndSettle();

      expect(find.byType(OpenInAppSheet), findsOneWidget);
      final error = tester.widget<Text>(
        find.text('Não foi possível abrir o Waze.'),
      );
      expect(error.style!.color, const Color(0xFFD01E23));

      await tester.tap(find.text('Google Maps'));
      await tester.pumpAndSettle();

      verify(() => launcher.open(NavigationApp.googleMaps, stop)).called(1);
      expect(find.byType(OpenInAppSheet), findsNothing);
    });

    testWidgets('taps while an app is opening are ignored', (tester) async {
      final pending = Completer<bool>();
      when(() => launcher.open(any(), any())).thenAnswer((_) => pending.future);
      await pumpAndOpen(tester);

      await tester.tap(find.text('Waze'));
      await tester.pump();
      await tester.tap(find.text('Google Maps'));
      await tester.pump();

      verify(() => launcher.open(NavigationApp.waze, stop)).called(1);
      verifyNever(() => launcher.open(NavigationApp.googleMaps, any()));

      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(OpenInAppSheet), findsNothing);
    });

    testWidgets('an answer after the sheet was dismissed is ignored', (
      tester,
    ) async {
      final pending = Completer<bool>();
      when(() => launcher.open(any(), any())).thenAnswer((_) => pending.future);
      await pumpAndOpen(tester);
      await tester.tap(find.text('Waze'));
      await tester.pump();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(OpenInAppSheet), findsNothing);

      pending.complete(false);
      await tester.pumpAndSettle();

      expect(find.text('open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('OpenInAppSheet in dark mode', () {
    testWidgets('#1A1D23 sheet with the title and apps in #F2F4F7, the '
        'caption and chevrons in #A4ACB9 and a #2F343D divider', (
      tester,
    ) async {
      await pumpAndOpen(tester, mode: ThemeMode.dark);

      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        const Color(0xFF1A1D23),
      );
      expect(
        tester.widget<Text>(find.text('Abrir em outro app')).style!.color,
        const Color(0xFFF2F4F7),
      );
      expect(
        tester
            .widget<Text>(
              find.text(
                'O RouteBreeze continua acompanhando a rota em segundo plano.',
              ),
            )
            .style!
            .color,
        const Color(0xFFA4ACB9),
      );
      for (final label in ['Google Maps', 'Waze']) {
        expect(
          tester.widget<Text>(find.text(label)).style!.color,
          const Color(0xFFF2F4F7),
        );
      }
      final chevrons = tester.widgetList<Icon>(
        find.byIcon(Icons.chevron_right),
      );
      expect(chevrons.map((icon) => icon.color), [
        const Color(0xFFA4ACB9),
        const Color(0xFFA4ACB9),
      ]);
      expect(
        tester.widget<Divider>(find.byType(Divider)).color,
        const Color(0xFF2F343D),
      );
    });
  });
}

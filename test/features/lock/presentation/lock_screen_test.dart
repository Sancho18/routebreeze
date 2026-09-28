import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/lock/presentation/lock_cubit.dart';
import 'package:routebreeze/features/lock/presentation/lock_screen.dart';

import '../../../helpers/accessibility.dart';
import '../../../helpers/themed_app.dart';

class MockLockCubit extends MockCubit<LockState> implements LockCubit {}

void main() {
  late MockLockCubit cubit;
  late int unlockedCalls;

  setUp(() {
    cubit = MockLockCubit();
    unlockedCalls = 0;
    when(() => cubit.unlock()).thenAnswer((_) async {});
  });

  /// Pumps the screen in a bare `MaterialApp`, or in the app themes when
  /// [mode] is given.
  Future<void> pumpLock(
    WidgetTester tester, {
    required LockState initial,
    Stream<LockState>? stream,
    ThemeMode? mode,
  }) async {
    whenListen(
      cubit,
      stream ?? const Stream<LockState>.empty(),
      initialState: initial,
    );
    final screen = LockScreen(cubit: cubit, onUnlocked: () => unlockedCalls++);
    await tester.pumpWidget(
      mode == null ? MaterialApp(home: screen) : themedApp(screen, mode: mode),
    );
    await tester.pump();
  }

  RbPrimaryButton button(WidgetTester tester) =>
      tester.widget<RbPrimaryButton>(find.byType(RbPrimaryButton));

  group('LockScreen', () {
    testWidgets('starts the prompt on the first frame and shows the title on '
        'surface-200 with the Desbloquear button', (tester) async {
      await pumpLock(tester, initial: const LockState());

      verify(() => cubit.unlock()).called(1);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        RbColors.surface200,
      );
      final title = tester.widget<Text>(find.text('RouteBreeze'));
      expect(title.style!.fontSize, 34);
      expect(title.style!.height, 40 / 34);
      expect(title.style!.fontWeight, FontWeight.w700);
      expect(button(tester).label, 'Desbloquear');
      expect(find.byType(RbPrimaryButton), findsOneWidget);
    });

    testWidgets('unlocked triggers onUnlocked once', (tester) async {
      await pumpLock(
        tester,
        initial: const LockState(status: LockStatus.authenticating),
        stream: Stream.fromIterable(const [
          LockState(status: LockStatus.unlocked),
        ]),
      );

      expect(unlockedCalls, 1);
    });

    const copies = <AuthResult, String>{
      AuthResult.canceled: 'Autenticação cancelada',
      AuthResult.lockedOut: 'Muitas tentativas. Aguarde e tente novamente',
      AuthResult.noCredentials:
          'Configure um bloqueio de tela no aparelho para usar o app',
      AuthResult.unavailable: 'Autenticação indisponível neste aparelho',
      AuthResult.error: 'Não foi possível autenticar. Tente novamente',
    };

    for (final entry in copies.entries) {
      testWidgets('failed(${entry.key.name}) shows "${entry.value}" in danger '
          'body and the button re-prompts', (tester) async {
        await pumpLock(
          tester,
          initial: LockState(status: LockStatus.failed, reason: entry.key),
        );

        final text = tester.widget<Text>(find.text(entry.value));
        expect(text.style!.color, const Color(0xFFD01E23));
        expect(text.style!.fontSize, 15);
        expect(text.style!.fontWeight, FontWeight.w400);

        final label = entry.key == AuthResult.noCredentials
            ? 'Tentar novamente'
            : 'Desbloquear';
        expect(button(tester).label, label);
        expect(button(tester).enabled, isTrue);
        expect(button(tester).loading, isFalse);

        await tester.tap(find.byType(RbPrimaryButton));
        await tester.pump();
        verify(() => cubit.unlock()).called(2);
        expect(unlockedCalls, 0);
      });
    }

    testWidgets('dark mode: #1A1D23 background, #F2F4F7 title and #EB7074 '
        'error', (tester) async {
      await pumpLock(
        tester,
        initial: const LockState(
          status: LockStatus.failed,
          reason: AuthResult.canceled,
        ),
        mode: ThemeMode.dark,
      );

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        const Color(0xFF1A1D23),
      );
      expect(
        tester.widget<Text>(find.text('RouteBreeze')).style!.color,
        const Color(0xFFF2F4F7),
      );
      expect(
        tester.widget<Text>(find.text('Autenticação cancelada')).style!.color,
        const Color(0xFFEB7074),
      );
    });
  });

  group('LockScreen accessibility', () {
    // noCredentials: the longest failure copy; it also swaps the button label.
    const states = <String, (LockState, String)>{
      'without an error': (LockState(), 'Desbloquear'),
      'with an error': (
        LockState(status: LockStatus.failed, reason: AuthResult.noCredentials),
        'Configure um bloqueio de tela no aparelho para usar o app',
      ),
    };

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final MapEntry(key: name, value: (state, text)) in states.entries) {
        testWidgets('$name meets the contrast, tap target and label '
            'guidelines in ${mode.name} mode', (tester) async {
          await pumpLock(tester, initial: state, mode: mode);
          expect(find.text(text), findsOneWidget);

          await expectAccessibleGuidelines(tester);
        });
      }
    }

    for (final MapEntry(key: name, value: (state, text)) in states.entries) {
      testWidgets('$name lays out at 200% text on a 360×800 phone', (
        tester,
      ) async {
        await setLargeTextPhone(tester);
        await pumpLock(tester, initial: state, mode: ThemeMode.light);

        final context = tester.element(find.byType(Scaffold));
        expect(MediaQuery.sizeOf(context), const Size(360, 800));
        expect(MediaQuery.textScalerOf(context).scale(15), 30);
        expect(find.text(text), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

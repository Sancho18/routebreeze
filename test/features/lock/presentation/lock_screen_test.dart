import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:routebreeze/core/theme/rb_tokens.dart';
import 'package:routebreeze/core/widgets/rb_button.dart';
import 'package:routebreeze/features/lock/domain/auth_result.dart';
import 'package:routebreeze/features/lock/presentation/lock_cubit.dart';
import 'package:routebreeze/features/lock/presentation/lock_screen.dart';

class MockLockCubit extends MockCubit<LockState> implements LockCubit {}

void main() {
  late MockLockCubit cubit;
  late int unlockedCalls;

  setUp(() {
    cubit = MockLockCubit();
    unlockedCalls = 0;
    when(() => cubit.unlock()).thenAnswer((_) async {});
  });

  Future<void> pumpLock(
    WidgetTester tester, {
    required LockState initial,
    Stream<LockState>? stream,
  }) async {
    whenListen(
      cubit,
      stream ?? const Stream<LockState>.empty(),
      initialState: initial,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LockScreen(cubit: cubit, onUnlocked: () => unlockedCalls++),
      ),
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
        expect(text.style!.color, RbColors.danger);
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
  });
}

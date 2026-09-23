import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../domain/auth_result.dart';
import 'lock_cubit.dart';

/// Lock screen: prompts on the first frame, shows the failure copy per
/// reason and lets the user retry.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked, this.cubit});

  final VoidCallback onUnlocked;

  /// Overrides the app-level cubit from `getIt` (tests).
  final LockCubit? cubit;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final LockCubit _cubit = widget.cubit ?? getIt<LockCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cubit.unlock());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LockCubit, LockState>(
      bloc: _cubit,
      listenWhen: (previous, current) =>
          current.status == LockStatus.unlocked &&
          previous.status != LockStatus.unlocked,
      listener: (_, _) => widget.onUnlocked(),
      builder: (context, state) {
        final message = _messageFor(state.reason);
        return Scaffold(
          backgroundColor: RbColors.surface200,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(RbSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Text(
                    'RouteBreeze',
                    textAlign: TextAlign.center,
                    style: RbText.display.copyWith(color: RbColors.ink),
                  ),
                  const Spacer(),
                  if (message != null) ...[
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: RbText.body.copyWith(color: RbColors.danger),
                    ),
                    const SizedBox(height: RbSpace.s3),
                  ],
                  RbPrimaryButton(
                    label: state.reason == AuthResult.noCredentials
                        ? 'Tentar novamente'
                        : 'Desbloquear',
                    loading: state.status == LockStatus.authenticating,
                    onPressed: _cubit.unlock,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String? _messageFor(AuthResult? reason) => switch (reason) {
  AuthResult.canceled => 'Autenticação cancelada',
  AuthResult.lockedOut => 'Muitas tentativas. Aguarde e tente novamente',
  AuthResult.noCredentials =>
    'Configure um bloqueio de tela no aparelho para usar o app',
  AuthResult.unavailable => 'Autenticação indisponível neste aparelho',
  AuthResult.error => 'Não foi possível autenticar. Tente novamente',
  AuthResult.success || null => null,
};

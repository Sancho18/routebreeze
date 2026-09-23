import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/geo/geo_point.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../domain/stop.dart';
import 'address_field_widget.dart';
import 'address_form_cubit.dart';

/// Address entry screen: "Ponto A/B/C…" fields with the offline banner on top.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({
    super.key,
    required this.start,
    required this.onConfirmed,
    this.cubit,
    this.connectivity,
  });

  /// Start position: autocomplete bias.
  final GeoPoint start;

  final void Function(List<Stop> stops) onConfirmed;

  /// Overrides the cubit from `getIt` (tests).
  final AddressFormCubit? cubit;

  /// Overrides the service from `getIt` (tests).
  final ConnectivityService? connectivity;

  static const String title = 'Para onde vamos?';
  static const String addLabel = 'Adicionar ponto';
  static const String confirmLabel = 'Confirmar rota';
  static const String helper = 'Preencha os 3 endereços para continuar';

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late final AddressFormCubit _cubit =
      widget.cubit ?? getIt<AddressFormCubit>(param1: widget.start);
  late final ConnectivityService _connectivity =
      widget.connectivity ?? getIt<ConnectivityService>();
  StreamSubscription<bool>? _online;

  @override
  void initState() {
    super.initState();
    _connectivity.check().then((online) {
      if (mounted) _cubit.setOnline(online);
    });
    _online = _connectivity.isOnline.listen(_cubit.setOnline);
  }

  @override
  void dispose() {
    _online?.cancel();
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddressFormCubit, AddressFormState>(
      bloc: _cubit,
      listenWhen: (previous, current) =>
          current.submitted != null && previous.submitted != current.submitted,
      listener: (_, state) {
        widget.onConfirmed(state.submitted!);
        _cubit.reset();
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (!state.online)
                  const RbBanner(text: 'Sem conexão', tone: RbTone.danger),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(RbSpace.s3),
                    children: [
                      Text(
                        AddressesScreen.title,
                        style: RbText.title.copyWith(color: RbColors.ink),
                      ),
                      const SizedBox(height: RbSpace.s4),
                      for (final (index, field) in state.fields.indexed) ...[
                        AddressFieldWidget(
                          key: ValueKey(field.id),
                          field: field,
                          placeholder: _placeholder(index),
                          onChanged: (text) =>
                              _cubit.onTextChanged(field.id, text),
                          onSuggestionSelected: (suggestion) =>
                              _cubit.selectSuggestion(field.id, suggestion),
                          onRemove: index < 3
                              ? null
                              : () => _cubit.removeField(field.id),
                        ),
                        const SizedBox(height: RbSpace.s2),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _cubit.addField,
                          style: TextButton.styleFrom(
                            foregroundColor: RbColors.brand,
                            textStyle: RbText.bodyStrong,
                          ),
                          child: const Text(AddressesScreen.addLabel),
                        ),
                      ),
                      const SizedBox(height: RbSpace.s4),
                      RbPrimaryButton(
                        label: AddressesScreen.confirmLabel,
                        enabled: state.canConfirm,
                        onPressed: _cubit.confirm,
                      ),
                      if (!state.canConfirm) ...[
                        const SizedBox(height: RbSpace.s2),
                        Text(
                          AddressesScreen.helper,
                          textAlign: TextAlign.center,
                          style: RbText.caption.copyWith(
                            color: RbColors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Ponto A", "Ponto B", … "Ponto Z", "Ponto AA", …
String _placeholder(int index) {
  var letters = '';
  var i = index;
  do {
    letters = String.fromCharCode(65 + i % 26) + letters;
    i = i ~/ 26 - 1;
  } while (i >= 0);
  return 'Ponto $letters';
}

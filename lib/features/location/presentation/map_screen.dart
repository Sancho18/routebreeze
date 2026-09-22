import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/theme/rb_tokens.dart';
import '../../../core/widgets/rb_button.dart';
import '../../../core/widgets/rb_feedback.dart';
import '../domain/fix.dart';
import 'map_cubit.dart';

/// Builds the map for a known start; tests inject a placeholder because the
/// real `GoogleMap` cannot render in widget tests.
typedef MapBuilder = Widget Function(BuildContext context, Fix start);

/// Map screen: start fix on a map at zoom 16 with the "Partida" marker,
/// permission/service cards with the spec copy and the "Para onde vamos?"
/// action enabled only when the start is known (MAP-02..MAP-07).
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.onContinue,
    this.cubit,
    this.mapBuilder,
  });

  final void Function(Fix start) onContinue;

  /// Overrides the cubit from `getIt` (tests).
  final MapCubit? cubit;

  /// Overrides the `GoogleMap` builder (tests).
  final MapBuilder? mapBuilder;

  static const String continueLabel = 'Para onde vamos?';

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapCubit _cubit = widget.cubit ?? getIt<MapCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.init();
  }

  @override
  void dispose() {
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapBuilder = widget.mapBuilder ?? _googleMap;
    return BlocBuilder<MapCubit, MapState>(
      bloc: _cubit,
      builder: (context, state) {
        final start = state.start;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: start == null
                    ? const ColoredBox(color: RbColors.surface100)
                    : mapBuilder(context, start),
              ),
              Positioned(
                left: RbSpace.s3,
                right: RbSpace.s3,
                bottom: RbSpace.s3,
                child: SafeArea(
                  child: _StatusCard(
                    state: state,
                    onRetry: _cubit.retry,
                    onOpenSettings: _cubit.openSettings,
                    onContinue: widget.onContinue,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _googleMap(BuildContext context, Fix start) {
  final target = LatLng(start.point.lat, start.point.lng);
  return GoogleMap(
    initialCameraPosition: CameraPosition(target: target, zoom: 16),
    markers: {
      Marker(
        markerId: const MarkerId('start'),
        position: target,
        infoWindow: const InfoWindow(title: 'Partida'),
      ),
    },
    myLocationButtonEnabled: false,
    zoomControlsEnabled: false,
  );
}

/// `surface-200` card with the copy and action for each [MapStatus], plus
/// the "Para onde vamos?" button, enabled only when `ready` (MAP-07).
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onContinue,
  });

  final MapState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final void Function(Fix start) onContinue;

  static const String deniedMessage =
      'Precisamos da sua localização para seguir. '
      'Ela define o ponto de partida da sua rota.';
  static const String deniedForeverCaption =
      'Você negou o acesso. Ative em Configurações.';
  static const String serviceDisabledMessage =
      'Ative a localização do dispositivo para continuar.';
  static const String impreciseMessage =
      'Não conseguimos uma posição precisa. '
      'Verifique se está em local aberto.';

  @override
  Widget build(BuildContext context) {
    final start = state.start;
    return Container(
      padding: const EdgeInsets.all(RbSpace.s3),
      decoration: BoxDecoration(
        color: RbColors.surface200,
        borderRadius: BorderRadius.circular(RbRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._content(),
          const SizedBox(height: RbSpace.s3),
          RbPrimaryButton(
            label: MapScreen.continueLabel,
            enabled: start != null,
            onPressed: start == null ? null : () => onContinue(start),
          ),
        ],
      ),
    );
  }

  List<Widget> _content() => switch (state.status) {
    MapStatus.checking => [
      Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: RbSpace.s2),
          Text(
            'Obtendo sua localização...',
            style: RbText.body.copyWith(color: RbColors.ink),
          ),
        ],
      ),
    ],
    MapStatus.ready => [_caption('Ponto de partida definido')],
    MapStatus.denied => [
      const RbInlineError(text: deniedMessage),
      const SizedBox(height: RbSpace.s3),
      RbPrimaryButton(label: 'Permitir localização', onPressed: onRetry),
    ],
    MapStatus.deniedForever => [
      const RbInlineError(text: deniedMessage),
      const SizedBox(height: RbSpace.s2),
      _caption(deniedForeverCaption),
      const SizedBox(height: RbSpace.s3),
      RbPrimaryButton(label: 'Abrir configurações', onPressed: onOpenSettings),
    ],
    MapStatus.serviceDisabled => [
      const RbInlineError(text: serviceDisabledMessage),
      const SizedBox(height: RbSpace.s3),
      RbPrimaryButton(label: 'Ativar localização', onPressed: onOpenSettings),
    ],
    MapStatus.timeout || MapStatus.imprecise => [
      const RbInlineError(text: impreciseMessage),
      const SizedBox(height: RbSpace.s3),
      RbPrimaryButton(label: 'Tentar novamente', onPressed: onRetry),
    ],
  };

  Widget _caption(String text) =>
      Text(text, style: RbText.caption.copyWith(color: RbColors.inkMuted));
}

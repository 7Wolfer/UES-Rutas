import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/ajustes/settings_controller.dart';

/// Momentos de la app que llevan vibración. Un solo lugar decide la
/// intensidad, para que la sensación sea consistente.
enum EventoHaptico {
  seleccion,
  pin,
  iniciar,
  maniobra,
  recalculo,
  llegada,
}

/// Vibraciones respetando el ajuste del usuario. No hace nada en web y nunca
/// encadena dos en menos de 300 ms.
class Hapticos {
  Hapticos(this._activo);

  final bool Function() _activo;
  DateTime _ultimo = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> sentir(EventoHaptico e) async {
    if (kIsWeb || !_activo()) return;
    final ahora = DateTime.now();
    if (ahora.difference(_ultimo) < const Duration(milliseconds: 300)) return;
    _ultimo = ahora;
    switch (e) {
      case EventoHaptico.seleccion:
        await HapticFeedback.selectionClick();
      case EventoHaptico.pin:
        await HapticFeedback.lightImpact();
      case EventoHaptico.iniciar:
        await HapticFeedback.mediumImpact();
      case EventoHaptico.maniobra:
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await HapticFeedback.lightImpact();
      case EventoHaptico.recalculo:
        await HapticFeedback.warningNotification();
      case EventoHaptico.llegada:
        await HapticFeedback.successNotification();
    }
  }
}

final hapticosProvider = Provider<Hapticos>(
  (ref) => Hapticos(() => ref.read(settingsProvider).vibracion),
);

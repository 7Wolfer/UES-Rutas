import 'package:flutter/material.dart';

/// Tokens de movimiento de la app: duraciones y curvas con nombre (Material 3),
/// para que todas las animaciones se sientan de la misma familia.
///
/// Todo respeta "reducir movimiento" del sistema: con él activo las
/// animaciones de una vez duran cero y las que se repiten no corren.
abstract final class Movimiento {
  /// Respuesta al presionar (escala de botones).
  static const presion = Durations.short2; // 100 ms

  /// Chips, íconos, etiquetas que aparecen.
  static const rapida = Durations.short4; // 200 ms

  /// Cambios de contenido, hoja inferior, paneos cortos.
  static const media = Durations.medium2; // 300 ms

  /// Encuadres de cámara y entrada al modo de seguimiento.
  static const lenta = Durations.long2; // 500 ms

  /// Revelado de la ruta sobre el mapa.
  static const revelado = Durations.extralong1; // 700 ms

  static const Curve enfatizada = Curves.easeInOutCubicEmphasized;
  static const Curve entrada = Easing.emphasizedDecelerate;
  static const Curve salida = Easing.emphasizedAccelerate;
  static const Curve estandar = Easing.standard;

  /// Solo para pines y marcadores que "caen" en su lugar.
  static const Curve rebote = Curves.easeOutBack;

  /// ¿El sistema pidió reducir el movimiento?
  static bool reducido(BuildContext c) => MediaQuery.disableAnimationsOf(c);

  /// La duración `d`, o cero si hay que reducir el movimiento.
  static Duration de(BuildContext c, Duration d) =>
      reducido(c) ? Duration.zero : d;

  /// ¿Pueden correr animaciones en bucle (pulso, brillo de carga)?
  static bool buclesPermitidos(BuildContext c) =>
      !reducido(c) && TickerMode.valuesOf(c).enabled;
}

/// Transiciones compartidas para `AnimatedSwitcher` y similares.
abstract final class TransicionesUes {
  /// Desvanecer + escalar levemente (fade through de Material).
  static Widget fadeThrough(Widget child, Animation<double> a) {
    final entrada = CurvedAnimation(parent: a, curve: Movimiento.entrada);
    return FadeTransition(
      opacity: entrada,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(entrada),
        child: child,
      ),
    );
  }

  /// Texto que entra desde abajo (cambios de indicación, cifras).
  static Widget deslizarArriba(Widget child, Animation<double> a) {
    final entrada = CurvedAnimation(parent: a, curve: Movimiento.entrada);
    return FadeTransition(
      opacity: entrada,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
            .animate(entrada),
        child: child,
      ),
    );
  }
}

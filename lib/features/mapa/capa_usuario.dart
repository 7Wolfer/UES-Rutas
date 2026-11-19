import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../core/brand.dart';
import '../../core/movimiento.dart';

/// Lo que el mapa necesita saber de la ubicación del usuario.
@immutable
class UbicacionEnMapa {
  const UbicacionEnMapa({
    required this.posicion,
    this.precisionM,
    this.rumbo,
    this.reciente = true,
    this.aproximada = false,
  });

  final LatLng posicion;

  /// Radio de incertidumbre en metros (halo alrededor del punto).
  final double? precisionM;

  /// Hacia dónde mira o camina el usuario (grados desde el norte).
  final double? rumbo;

  /// `false` si la última lectura es vieja: se apaga el pulso.
  final bool reciente;

  /// Ubicación aproximada (el sistema no dio la precisa).
  final bool aproximada;

  @override
  bool operator ==(Object other) =>
      other is UbicacionEnMapa &&
      other.posicion == posicion &&
      other.precisionM == precisionM &&
      other.rumbo == rumbo &&
      other.reciente == reciente &&
      other.aproximada == aproximada;

  @override
  int get hashCode =>
      Object.hash(posicion, precisionM, rumbo, reciente, aproximada);
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + (end!.latitude - begin!.latitude) * t,
        begin!.longitude + (end!.longitude - begin!.longitude) * t,
      );
}

/// Halo de precisión + punto del usuario (con pulso y cono de rumbo). El punto
/// se desliza a cada lectura nueva en lugar de saltar.
class CapaUsuario extends StatelessWidget {
  const CapaUsuario({super.key, required this.ubicacion});

  final UbicacionEnMapa ubicacion;

  @override
  Widget build(BuildContext context) {
    final color = UesBrand.ubicacionUsuario;
    return TweenAnimationBuilder<LatLng>(
      tween: _LatLngTween(begin: ubicacion.posicion, end: ubicacion.posicion),
      duration: Movimiento.de(context, Movimiento.media),
      curve: Curves.linear,
      builder: (context, pos, _) {
        final precision = ubicacion.precisionM;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (precision != null && precision >= 4)
              CircleLayer(circles: [
                CircleMarker(
                  point: pos,
                  radius: precision.clamp(3, 200).toDouble(),
                  useRadiusInMeter: true,
                  color: color.withValues(alpha: 0.10),
                  borderColor: color.withValues(alpha: 0.35),
                  borderStrokeWidth: 1,
                ),
              ]),
            MarkerLayer(markers: [
              Marker(
                point: pos,
                width: 96,
                height: 96,
                child: _PuntoUsuario(
                  rumbo: ubicacion.rumbo,
                  pulso: ubicacion.reciente,
                  aproximada: ubicacion.aproximada,
                ),
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _PuntoUsuario extends StatefulWidget {
  const _PuntoUsuario({
    required this.rumbo,
    required this.pulso,
    required this.aproximada,
  });

  final double? rumbo;
  final bool pulso;
  final bool aproximada;

  @override
  State<_PuntoUsuario> createState() => _PuntoUsuarioState();
}

class _PuntoUsuarioState extends State<_PuntoUsuario>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizarPulso();
  }

  @override
  void didUpdateWidget(covariant _PuntoUsuario old) {
    super.didUpdateWidget(old);
    _actualizarPulso();
  }

  void _actualizarPulso() {
    final debe = widget.pulso && Movimiento.buclesPermitidos(context);
    if (debe && !_pulso.isAnimating) {
      _pulso.repeat();
    } else if (!debe && _pulso.isAnimating) {
      _pulso
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.aproximada
        ? UesBrand.ubicacionUsuario.withValues(alpha: 0.6)
        : UesBrand.ubicacionUsuario;
    return Semantics(
      label: widget.aproximada ? 'Tu ubicación aproximada' : 'Tu ubicación',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _pulso,
        builder: (context, _) => CustomPaint(
          painter: _PintorUsuario(
            color: color,
            rumbo: widget.rumbo,
            fasePulso: _pulso.isAnimating ? _pulso.value : null,
          ),
        ),
      ),
    );
  }
}

class _PintorUsuario extends CustomPainter {
  _PintorUsuario({required this.color, this.rumbo, this.fasePulso});

  final Color color;
  final double? rumbo;
  final double? fasePulso;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Cono de rumbo: 70° de abertura, se desvanece hacia afuera.
    final r = rumbo;
    if (r != null) {
      final ang = (r - 90) * math.pi / 180;
      const abertura = 35 * math.pi / 180;
      const largo = 46.0;
      final cono = Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(Rect.fromCircle(center: c, radius: largo), ang - abertura,
            abertura * 2, false)
        ..close();
      canvas.drawPath(
        cono,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: largo)),
      );
    }

    // Pulso: un anillo que crece y se desvanece.
    final f = fasePulso;
    if (f != null) {
      final radio = 8 + 18 * Curves.easeOut.transform(f);
      canvas.drawCircle(
        c,
        radio,
        Paint()..color = color.withValues(alpha: 0.35 * (1 - f)),
      );
    }

    // Punto con aro blanco (se lee bien incluso sobre la ruta naranja).
    canvas.drawCircle(
        c,
        11,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(c, 10, Paint()..color = Colors.white);
    canvas.drawCircle(c, 7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PintorUsuario o) =>
      o.color != color || o.rumbo != rumbo || o.fasePulso != fasePulso;
}

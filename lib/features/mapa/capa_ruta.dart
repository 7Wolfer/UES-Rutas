import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/brand.dart';
import '../../core/movimiento.dart';
import '../../data/routing.dart';

/// La ruta sobre el mapa. Cuando cambia, se "dibuja" desde el origen hasta el
/// destino; al navegar, lo ya caminado se pinta en gris.
class CapaRuta extends StatefulWidget {
  const CapaRuta({
    super.key,
    required this.ruta,
    required this.oscuro,
    this.avanceM,
    this.revelar = true,
  });

  final RutaCalculada ruta;
  final bool oscuro;

  /// Metros recorridos (modo navegación). `null` = vista previa normal.
  final double? avanceM;

  /// Animar el trazo al aparecer.
  final bool revelar;

  @override
  State<CapaRuta> createState() => _CapaRutaState();
}

class _CapaRutaState extends State<CapaRuta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  List<LatLng> _pts = const [];
  List<double> _acum = const [];
  bool _primera = true;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_primera) {
      _primera = false;
      _revelar();
    }
  }

  @override
  void didUpdateWidget(covariant CapaRuta old) {
    super.didUpdateWidget(old);
    if (!identical(old.ruta, widget.ruta)) {
      _preparar();
      _revelar();
    }
  }

  void _preparar() {
    _pts = [for (final p in widget.ruta.puntos) p.toLatLng()];
    final a = widget.ruta.acumulado;
    _acum = a.length == _pts.length ? a : _acumular(_pts);
  }

  static List<double> _acumular(List<LatLng> pts) {
    const d = Distance();
    final out = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      out.add(out.last + d.as(LengthUnit.Meter, pts[i - 1], pts[i]));
    }
    return out;
  }

  void _revelar() {
    if (!widget.revelar || Movimiento.reducido(context) || _pts.length < 2) {
      _c.value = 1;
      return;
    }
    final ms = (widget.ruta.distancia / 400 * 1000).clamp(500, 700).round();
    _c
      ..duration = Duration(milliseconds: ms)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Puntos de la polilínea entre las distancias `desde` y `hasta`, con los
  /// extremos interpolados (para que el corte sea exacto).
  List<LatLng> _tramo(double desde, double hasta) {
    if (_pts.length < 2 || hasta <= desde) return const [];
    final total = _acum.last;
    desde = desde.clamp(0, total);
    hasta = hasta.clamp(0, total);
    final out = <LatLng>[_en(desde)];
    for (var i = 1; i < _pts.length - 1; i++) {
      if (_acum[i] > desde && _acum[i] < hasta) out.add(_pts[i]);
    }
    out.add(_en(hasta));
    return out;
  }

  LatLng _en(double s) {
    var i = 1;
    while (i < _acum.length - 1 && _acum[i] < s) {
      i++;
    }
    final a = _pts[i - 1], b = _pts[i];
    final largo = _acum[i] - _acum[i - 1];
    final t = largo <= 0 ? 0.0 : ((s - _acum[i - 1]) / largo).clamp(0.0, 1.0);
    return LatLng(a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t);
  }

  @override
  Widget build(BuildContext context) {
    if (_pts.length < 2) return const SizedBox.shrink();
    final borde = widget.oscuro
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.95);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final total = _acum.last;
        final visible = Movimiento.entrada.transform(_c.value) * total;
        final avance = widget.avanceM;
        final lineas = <Polyline>[];
        if (avance == null) {
          lineas.add(Polyline(
            points: _tramo(0, visible),
            strokeWidth: 5,
            color: UesBrand.naranja,
            borderStrokeWidth: 2.5,
            borderColor: borde,
          ));
        } else {
          final corte = math.min(avance, visible);
          if (corte > 0.5) {
            lineas.add(Polyline(
              points: _tramo(0, corte),
              strokeWidth: 5,
              color: (widget.oscuro ? Colors.white : Colors.black)
                  .withValues(alpha: 0.28),
              borderStrokeWidth: 2,
              borderColor: borde,
            ));
          }
          lineas.add(Polyline(
            points: _tramo(corte, visible),
            strokeWidth: 6,
            color: UesBrand.naranja,
            borderStrokeWidth: 2.5,
            borderColor: borde,
          ));
        }
        final inicio = _pts.first;
        final escalaInicio = Curves.easeOutBack
            .transform((_c.value * 4).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            PolylineLayer(polylines: lineas),
            if (avance == null)
              MarkerLayer(markers: [
                Marker(
                  point: inicio,
                  width: 26,
                  height: 26,
                  child: Transform.scale(
                    scale: escalaInicio,
                    child: const _PuntoInicio(),
                  ),
                ),
              ]),
          ],
        );
      },
    );
  }
}

class _PuntoInicio extends StatelessWidget {
  const _PuntoInicio();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Inicio de la ruta',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: UesBrand.exito,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: const Icon(Icons.trip_origin, color: Colors.white, size: 12),
      ),
    );
  }
}

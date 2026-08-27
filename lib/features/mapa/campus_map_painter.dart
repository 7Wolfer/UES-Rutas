import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/brand.dart';
import '../../data/models.dart';
import '../../data/routing.dart';

/// Tamaño lógico del lienzo del campus. Todo el seed está en estas coordenadas.
const Size kCampusLienzo = Size(1000, 700);

class CampusMapPainter extends CustomPainter {
  CampusMapPainter({
    required this.data,
    required this.nivel,
    required this.brightness,
    this.ruta,
    this.destacarEspacioId,
  });

  final CampusData data;
  final int nivel;
  final Brightness brightness;
  final RutaCalculada? ruta;
  final String? destacarEspacioId;

  bool get _oscuro => brightness == Brightness.dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / kCampusLienzo.width;
    Offset p(Punto pt) => Offset(pt.x * s, pt.y * s);

    // Fondo.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _oscuro ? UesBrand.oscuroFondo : UesBrand.neutro50,
    );

    // Andadores (aristas exteriores y rampas).
    final nodo = {for (final n in data.nodos) n.id: n};
    final andador = Paint()
      ..color = _oscuro ? UesBrand.oscuroBorde : UesBrand.neutro200
      ..strokeWidth = 11 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final a in data.aristas) {
      if (a.tipo != TipoArista.exterior && a.tipo != TipoArista.rampa) continue;
      final na = nodo[a.a], nb = nodo[a.b];
      if (na == null || nb == null) continue;
      canvas.drawLine(p(na.punto), p(nb.punto), andador);
    }

    // Edificios.
    for (final e in data.edificios) {
      final rect = Rect.fromLTWH(
        e.rect[0] * s,
        e.rect[1] * s,
        e.rect[2] * s,
        e.rect[3] * s,
      );
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(10 * s));
      final destacado = destacarEspacioId == 'esp_${e.id}';
      canvas.drawRRect(
        rr,
        Paint()
          ..color = destacado
              ? UesBrand.vino.withValues(alpha: _oscuro ? 0.35 : 0.16)
              : (_oscuro ? UesBrand.oscuroSuperficieAlta : Colors.white),
      );
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (destacado ? 2.5 : 1.4) * s
          ..color = destacado
              ? UesBrand.vino
              : (_oscuro ? UesBrand.oscuroBorde : UesBrand.neutro300),
      );
      _texto(
        canvas,
        e.clave,
        rect.topLeft + Offset(8 * s, 6 * s),
        color: _oscuro ? UesBrand.oscuroTexto : UesBrand.vino,
        size: 17 * s,
        peso: FontWeight.w800,
      );
    }

    // Ruta.
    final r = ruta;
    if (r != null && r.puntos.length > 1) {
      final path = Path()..moveTo(p(r.puntos.first).dx, p(r.puntos.first).dy);
      for (final pt in r.puntos.skip(1)) {
        path.lineTo(p(pt).dx, p(pt).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: _oscuro ? 0.0 : 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9 * s
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = UesBrand.naranja
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * s
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      _marcador(canvas, p(r.puntos.first), UesBrand.exito, Icons.trip_origin, s);
      _marcador(canvas, p(r.puntos.last), UesBrand.naranja, Icons.place, s);
    }

    // Pines de espacios visibles en el nivel actual.
    for (final e in data.espacios) {
      if (e.tipo == TipoEspacio.edificio) continue;
      final visible = e.edificioId == null || e.nivel == nivel;
      if (!visible) continue;
      final destacado = destacarEspacioId == e.id;
      _pin(canvas, p(e.punto), e.categoria, s, destacado: destacado);
    }

    // Ubicación del usuario (simulada en el acceso principal).
    final user = Offset(500 * s, 660 * s);
    canvas.drawCircle(user, 11 * s,
        Paint()..color = UesBrand.naranja.withValues(alpha: 0.25));
    canvas.drawCircle(user, 6 * s, Paint()..color = UesBrand.naranja);
    canvas.drawCircle(
      user,
      6 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..color = Colors.white,
    );
  }

  void _pin(Canvas canvas, Offset c, CategoriaMapa cat, double s,
      {bool destacado = false}) {
    final radio = (destacado ? 15.0 : 11.0) * s;
    canvas.drawCircle(
        c.translate(0, 1.5 * s), radio, Paint()..color = Colors.black26);
    canvas.drawCircle(c, radio, Paint()..color = cat.color);
    canvas.drawCircle(
      c,
      radio,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..color = Colors.white,
    );
    _icono(canvas, cat.icono, c, Colors.white, radio * 1.15);
  }

  void _marcador(Canvas canvas, Offset c, Color color, IconData icon, double s) {
    canvas.drawCircle(c, 13 * s, Paint()..color = Colors.white);
    canvas.drawCircle(c, 11 * s, Paint()..color = color);
    _icono(canvas, icon, c, Colors.white, 15 * s);
  }

  void _icono(Canvas canvas, IconData icon, Offset center, Color color, double sz) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: sz,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _texto(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    required double size,
    FontWeight peso = FontWeight.w600,
    bool centrar = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.montserrat(
          color: color,
          fontSize: size,
          fontWeight: peso,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      centrar ? at - Offset(tp.width / 2, tp.height / 2) : at,
    );
  }

  @override
  bool shouldRepaint(covariant CampusMapPainter old) =>
      old.nivel != nivel ||
      old.ruta != ruta ||
      old.destacarEspacioId != destacarEspacioId ||
      old.brightness != brightness ||
      !identical(old.data, data);
}

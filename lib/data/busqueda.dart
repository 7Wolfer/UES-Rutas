import 'package:flutter/material.dart';

import '../core/brand.dart';
import 'models.dart';

enum TipoResultado { lugar, docente }

@immutable
class ResultadoBusqueda {
  const ResultadoBusqueda({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
  });

  final TipoResultado tipo;
  final String id;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
}

/// Quita acentos y pasa a minúsculas para comparar sin diacríticos.
String normaliza(String s) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sin = 'aaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString();
}

/// Busca en lugares (edificios, servicios, accesos) y docentes.
List<ResultadoBusqueda> buscar(CampusData data, String consulta) {
  final q = normaliza(consulta.trim());
  if (q.isEmpty) return const [];

  final scored = <(int, ResultadoBusqueda)>[];

  int puntua(List<String?> campos) {
    var best = -1;
    for (final c in campos) {
      if (c == null || c.isEmpty) continue;
      final n = normaliza(c);
      if (n == q) {
        best = 100;
      } else if (n.startsWith(q) && best < 80) {
        best = 80;
      } else if (n.contains(q) && best < 50) {
        best = 50;
      }
    }
    return best;
  }

  for (final l in data.lugares) {
    final s = puntua([
      l.nombre,
      l.nombreCorto,
      l.descripcion,
      l.categoria.etiqueta,
    ]);
    if (s >= 0) {
      scored.add((
        s,
        ResultadoBusqueda(
          tipo: TipoResultado.lugar,
          id: l.id,
          titulo: l.nombre,
          subtitulo: l.categoria.etiqueta,
          icono: l.categoria.icono,
          color: l.categoria.color,
        ),
      ));
    }
  }

  for (final d in data.docentes) {
    final materias = d.asignaciones.map((a) => a.materia).toSet().toList();
    final s = puntua([d.nombre, d.departamento, ...materias]);
    if (s >= 0) {
      scored.add((
        s,
        ResultadoBusqueda(
          tipo: TipoResultado.docente,
          id: d.id,
          titulo: d.nombre,
          subtitulo: d.departamento,
          icono: Icons.person_outline,
          color: UesBrand.naranjaOscuro,
        ),
      ));
    }
  }

  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    return byScore != 0 ? byScore : a.$2.titulo.compareTo(b.$2.titulo);
  });
  return scored.map((e) => e.$2).toList();
}

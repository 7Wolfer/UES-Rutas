import 'package:flutter/material.dart';

import '../core/brand.dart';
import 'models.dart';

enum TipoResultado { espacio, edificio, docente }

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

/// Busca en aulas, edificios, servicios y docentes. Devuelve resultados
/// ordenados por relevancia (coincidencia de prefijo primero).
List<ResultadoBusqueda> buscar(CampusData data, String consulta) {
  final q = normaliza(consulta.trim());
  if (q.isEmpty) return const [];

  final scored = <(int, ResultadoBusqueda)>[];

  int puntua(List<String> campos) {
    var best = -1;
    for (final c in campos) {
      final n = normaliza(c);
      if (n == q) {
        best = best < 100 ? 100 : best;
      } else if (n.startsWith(q)) {
        if (best < 80) best = 80;
      } else if (n.contains(q)) {
        if (best < 50) best = 50;
      }
    }
    return best;
  }

  for (final e in data.edificios) {
    final s = puntua([e.nombre, e.clave, e.etiqueta, e.descripcion]);
    if (s >= 0) {
      scored.add((
        s,
        ResultadoBusqueda(
          tipo: TipoResultado.edificio,
          id: 'esp_${e.id}',
          titulo: e.nombre,
          subtitulo: e.etiqueta,
          icono: Icons.apartment_outlined,
          color: UesBrand.vino,
        ),
      ));
    }
  }

  for (final e in data.espacios) {
    if (e.tipo == TipoEspacio.edificio) continue;
    final cat = e.categoria;
    final s = puntua([
      e.nombre,
      e.titulo,
      if (e.numeroAula != null) e.numeroAula!,
      e.descripcion,
      cat.etiqueta,
    ]);
    if (s >= 0) {
      final edif = data.edificio(e.edificioId);
      scored.add((
        s,
        ResultadoBusqueda(
          tipo: TipoResultado.espacio,
          id: e.id,
          titulo: e.titulo,
          subtitulo: edif != null ? edif.etiqueta : cat.etiqueta,
          icono: cat.icono,
          color: cat.color,
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
    if (byScore != 0) return byScore;
    return a.$2.titulo.compareTo(b.$2.titulo);
  });

  return scored.map((e) => e.$2).toList();
}

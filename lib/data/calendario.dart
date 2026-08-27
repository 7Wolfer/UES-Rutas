import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

enum TipoEventoCal {
  inicioSemestral('Inicio de curso semestral', Color(0xFF1E7A5B)),
  finSemestral('Fin de curso semestral', Color(0xFF8BC34A)),
  reinscripciones('Reinscripciones', Color(0xFFF2C200)),
  noLaboral('Día no laboral', Color(0xFFD64545)),
  descanso('Período de descanso', Color(0xFFF5A623)),
  vacacional('Período vacacional', Color(0xFF9AA0A6)),
  limiteBaja('Límite de baja voluntaria', Color(0xFF3A3530)),
  lunesCivico('Lunes cívico', Color(0xFF2457A6)),
  inicioIntersemestral('Inicio de curso intersemestral', Color(0xFF7B4FB0)),
  finIntersemestral('Fin de curso intersemestral', Color(0xFFC9A6E8));

  const TipoEventoCal(this.etiqueta, this.color);
  final String etiqueta;
  final Color color;

  static TipoEventoCal desde(String s) {
    const map = {
      'inicio_semestral': TipoEventoCal.inicioSemestral,
      'fin_semestral': TipoEventoCal.finSemestral,
      'reinscripciones': TipoEventoCal.reinscripciones,
      'no_laboral': TipoEventoCal.noLaboral,
      'descanso': TipoEventoCal.descanso,
      'vacacional': TipoEventoCal.vacacional,
      'limite_baja': TipoEventoCal.limiteBaja,
      'lunes_civico': TipoEventoCal.lunesCivico,
      'inicio_intersemestral': TipoEventoCal.inicioIntersemestral,
      'fin_intersemestral': TipoEventoCal.finIntersemestral,
    };
    return map[s] ?? TipoEventoCal.noLaboral;
  }
}

@immutable
class EventoCalendario {
  const EventoCalendario({
    required this.desde,
    required this.hasta,
    required this.tipo,
    required this.titulo,
  });

  final DateTime desde;
  final DateTime hasta;
  final TipoEventoCal tipo;
  final String titulo;

  bool cubre(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(desde) && !day.isAfter(hasta);
  }
}

@immutable
class SemestreInfo {
  const SemestreInfo(
      {required this.nombre, required this.inicio, required this.fin});
  final String nombre;
  final DateTime inicio;
  final DateTime fin;
}

@immutable
class CalendarioUes {
  const CalendarioUes({
    required this.titulo,
    required this.fuente,
    required this.nota,
    required this.firmantes,
    required this.semestreActual,
    required this.eventos,
  });

  final String titulo;
  final String fuente;
  final String nota;
  final List<String> firmantes;
  final SemestreInfo semestreActual;
  final List<EventoCalendario> eventos;

  List<EventoCalendario> eventosDe(DateTime day) =>
      eventos.where((e) => e.cubre(day)).toList();

  factory CalendarioUes.fromJson(Map<String, dynamic> j) {
    final meta = j['meta'] as Map<String, dynamic>;
    final sem = meta['semestreActual'] as Map<String, dynamic>;
    return CalendarioUes(
      titulo: meta['titulo'] as String,
      fuente: meta['fuente'] as String,
      nota: meta['nota'] as String,
      firmantes: (meta['firmantes'] as List).cast<String>(),
      semestreActual: SemestreInfo(
        nombre: sem['nombre'] as String,
        inicio: DateTime.parse(sem['inicio'] as String),
        fin: DateTime.parse(sem['fin'] as String),
      ),
      eventos: (j['eventos'] as List).map((e) {
        final m = e as Map<String, dynamic>;
        return EventoCalendario(
          desde: DateTime.parse(m['desde'] as String),
          hasta: DateTime.parse(m['hasta'] as String),
          tipo: TipoEventoCal.desde(m['tipo'] as String),
          titulo: m['titulo'] as String,
        );
      }).toList(),
    );
  }
}

Future<CalendarioUes> cargarCalendario() async {
  final raw = await rootBundle.loadString('assets/seed/calendario_ues.json');
  return CalendarioUes.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

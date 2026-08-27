import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/brand.dart';

enum CategoriaAviso {
  importante('Aviso importante', Icons.warning_amber_rounded, UesBrand.error),
  ruta('Rutas y accesos', Icons.alt_route, Color(0xFF2457A6)),
  evento('Evento del campus', Icons.event, UesBrand.vino),
  general('General', Icons.campaign_outlined, UesBrand.naranjaOscuro);

  const CategoriaAviso(this.etiqueta, this.icono, this.color);
  final String etiqueta;
  final IconData icono;
  final Color color;

  static CategoriaAviso desde(String? s) => CategoriaAviso.values.firstWhere(
        (c) => c.name == s,
        orElse: () => CategoriaAviso.general,
      );
}

@immutable
class Aviso {
  const Aviso({
    required this.id,
    required this.fecha,
    required this.titulo,
    required this.cuerpo,
    required this.categoria,
    this.url,
  });

  final String id;
  final DateTime fecha;
  final String titulo;
  final String cuerpo;
  final CategoriaAviso categoria;
  final String? url;

  factory Aviso.fromJson(Map<String, dynamic> j) => Aviso(
        id: j['id'] as String,
        fecha: DateTime.parse(j['fecha'] as String),
        titulo: j['titulo'] as String,
        cuerpo: j['cuerpo'] as String,
        categoria: CategoriaAviso.desde(j['categoria'] as String?),
        url: j['url'] as String?,
      );
}

Future<List<Aviso>> cargarAvisos() async {
  final raw = await rootBundle.loadString('assets/seed/avisos.json');
  final lista = (jsonDecode(raw) as List)
      .map((e) => Aviso.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
  return lista;
}

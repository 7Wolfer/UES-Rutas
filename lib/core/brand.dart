import 'package:flutter/material.dart';

/// Constantes de identidad gráfica de la Universidad Estatal de Sonora.
///
/// Fuente: Manual de Identidad Gráfica UES 2024 (DDIIUES).
/// Ver `docs/IDENTIDAD-UES.md`. Lo marcado como "extensión digital" no está en
/// el manual (documento de impresión) y debe validarse con DDIIUES.
abstract final class UesBrand {
  // --- Paleta institucional (única permitida en comunicación digital) ---

  /// Naranja institucional — Pantone 1585 C. Color principal de la marca.
  static const Color naranja = Color(0xFFFF6C0E);

  /// Amarillo — Pantone 137 C.
  static const Color amarillo = Color(0xFFFFA400);

  /// Vino — Pantone 1955 C. Siglas, nombre y "lo institucional serio".
  static const Color vino = Color(0xFF8E1537);

  // Variantes de apoyo derivadas (extensión digital).
  static const Color naranjaOscuro = Color(0xFFCC5405);
  static const Color vinoOscuro = Color(0xFF5E0E24);
  static const Color vinoClaro = Color(0xFFB84A67);

  // --- Neutros cálidos (extensión digital) ---
  // Escala templada hacia el naranja para que conviva con la paleta.
  static const Color neutro0 = Color(0xFFFDFCFB); // fondo app (claro)
  static const Color neutro50 = Color(0xFFF6F4F1); // superficies sutiles
  static const Color neutro100 = Color(0xFFECE8E3);
  static const Color neutro200 = Color(0xFFDBD5CC);
  static const Color neutro300 = Color(0xFFBFB7AC);
  static const Color neutro500 = Color(0xFF8A8178);
  static const Color neutro700 = Color(0xFF544E47);
  static const Color neutro800 = Color(0xFF3A3530);
  static const Color neutro900 = Color(0xFF241F1B); // texto principal (claro)

  // Neutros para modo oscuro (extensión digital).
  static const Color oscuroFondo = Color(0xFF17130F);
  static const Color oscuroSuperficie = Color(0xFF211C17);
  static const Color oscuroSuperficieAlta = Color(0xFF2C2621);
  static const Color oscuroBorde = Color(0xFF3D362F);
  static const Color oscuroTexto = Color(0xFFF1ECE6);
  static const Color oscuroTextoTenue = Color(0xFFB7ADA2);

  // --- Semánticos ---
  static const Color exito = Color(0xFF1E7A5B);
  static const Color advertencia = amarillo;
  static const Color error = Color(0xFFB3261E);

  /// Punto de ubicación del usuario en el mapa.
  static const Color ubicacionUsuario = naranja;
}

/// Colores de categoría para el mapa. Extensión digital: dan legibilidad al
/// mapa sin sustituir la paleta institucional. **Validar con DDIIUES.**
enum CategoriaMapa {
  aula('Aula', Color(0xFF8E1537), Icons.meeting_room_outlined),
  edificio('Edificio', Color(0xFF8E1537), Icons.apartment_outlined),
  oficina('Oficina', Color(0xFF6D4B54), Icons.badge_outlined),
  servicios('Servicios', Color(0xFF3F6B7D), Icons.wc_outlined),
  alimentos('Cafetería', Color(0xFFB4531F), Icons.restaurant_outlined),
  biblioteca('Biblioteca', Color(0xFF4A5240), Icons.local_library_outlined),
  estacionamiento(
      'Estacionamiento', Color(0xFF5B5563), Icons.local_parking_outlined),
  salud('Salud', Color(0xFF1E7A5B), Icons.local_hospital_outlined),
  accesibilidad('Accesibilidad', Color(0xFF2457A6), Icons.accessible_outlined),
  deportivo('Deportivo', Color(0xFF7A5B1E), Icons.sports_basketball_outlined);

  const CategoriaMapa(this.etiqueta, this.color, this.icono);

  final String etiqueta;
  final Color color;
  final IconData icono;

  static CategoriaMapa desdeId(String? id) {
    return CategoriaMapa.values.firstWhere(
      (c) => c.name == id,
      orElse: () => CategoriaMapa.aula,
    );
  }
}

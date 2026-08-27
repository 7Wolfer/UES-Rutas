/// Helpers de nomenclatura. Deben coincidir EXACTAMENTE con la señalética
/// física del campus (Manual de Identidad Gráfica UES 2024, sección 7).
library;

String etiquetaEdificio(String clave) => 'EDIFICIO ${clave.toUpperCase()}';

String etiquetaAula(String numero) => 'AULA $numero';

String etiquetaNivel(int numero) {
  if (numero <= 0) return 'PLANTA BAJA';
  return 'NIVEL $numero';
}

/// Nivel en formato corto para chips y selectores ("PB", "N1", "N2"...).
String etiquetaNivelCorta(int numero) {
  if (numero <= 0) return 'PB';
  return 'N$numero';
}

/// Formatea un rango horario de 24h a algo legible: (7, 0, 8, 30) → "7:00–8:30".
String rangoHorario(int hIni, int mIni, int hFin, int mFin) {
  String hhmm(int h, int m) => '$h:${m.toString().padLeft(2, '0')}';
  return '${hhmm(hIni, mIni)}–${hhmm(hFin, mFin)}';
}

const List<String> diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
];

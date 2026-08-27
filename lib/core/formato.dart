/// Helpers de formato de texto.
library;

/// Rango horario de 24h legible: (7, 0, 8, 30) → "7:00–8:30".
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

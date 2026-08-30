import 'package:flutter_test/flutter_test.dart';
import 'package:ues_rutas/core/compartir.dart';

void main() {
  group('construirUrlCompartible', () {
    test('host simple + ruta de ficha', () {
      expect(
        construirUrlCompartible(
            base: 'https://ues-rutas.app', ruta: '/espacio/lug_a'),
        'https://ues-rutas.app/#/espacio/lug_a',
      );
    });

    test('host con subruta y barra final → sin doble barra', () {
      expect(
        construirUrlCompartible(
            base: 'https://x.com/sub/', ruta: '/ruta?destino=y'),
        'https://x.com/sub/#/ruta?destino=y',
      );
    });

    test('conserva los parámetros de consulta', () {
      expect(
        construirUrlCompartible(
            base: 'https://x.com', ruta: '/ruta?destino=lug_b&accesible=1'),
        'https://x.com/#/ruta?destino=lug_b&accesible=1',
      );
    });
  });
}

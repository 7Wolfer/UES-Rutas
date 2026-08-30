import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ues_rutas/features/mapa/teselas_campus_provider.dart';

void main() {
  final layer = TileLayer(urlTemplate: 'https://ejemplo/{z}/{x}/{y}.png');

  group('TeselasCampusProvider', () {
    test('usa el asset para una tesela empaquetada del campus', () {
      final p = TeselasCampusProvider({'18_50271_108888'});
      final img = p.getImage(const TileCoordinates(50271, 108888, 18), layer);

      expect(img, isA<AssetImage>());
      expect((img as AssetImage).assetName, 'assets/tiles/18_50271_108888.png');
    });

    test('cae a la red para una tesela fuera del paquete', () {
      final p = TeselasCampusProvider(const {});
      final img = p.getImage(const TileCoordinates(1, 1, 10), layer);

      expect(img, isA<NetworkImage>());
      expect((img as NetworkImage).url, 'https://ejemplo/10/1/1.png');
    });
  });
}

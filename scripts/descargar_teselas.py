#!/usr/bin/env python3
"""Descarga las teselas de OpenStreetMap que cubren el campus de la UES Hermosillo.

Las teselas quedan en assets/tiles/ como PNG de nombre plano ("z_x_y.png") para
que la app las use offline (ver lib/features/mapa/teselas_campus_provider.dart).
Es una descarga UNICA y de bajo volumen (~50-65 teselas, zoom 15-19); para
produccion conviene un proveedor de teselas con licencia o teselas vectoriales
(pmtiles) con estilo propio.

Uso:
    python3 scripts/descargar_teselas.py

Requiere: solo la biblioteca estandar de Python 3.
"""
from __future__ import annotations

import json
import math
import time
import urllib.error
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DEST = RAIZ / "assets" / "tiles"

# Bounding box del campus (perimetro + campo deportivo de assets/seed/campus.json)
# con un margen de ~120 m para que arrastrar un poco el mapa siga mostrando fondo.
MARGEN_GRADOS = 0.0012  # ~120 m a esta latitud
LAT_MIN, LAT_MAX = 29.1206 - MARGEN_GRADOS, 29.122538 + MARGEN_GRADOS
LNG_MIN, LNG_MAX = -110.9647 - MARGEN_GRADOS, -110.960655 + MARGEN_GRADOS

ZOOM_MIN, ZOOM_MAX = 15, 19

URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
UA = "UES-Rutas/0.2 (+https://github.com/7Wolfer/UES-Rutas)"
PAUSA = 0.4  # segundos entre descargas (cortesia con el servidor de OSM)


def _tile(lat: float, lng: float, z: int) -> tuple[int, int]:
    """Coordenada de tesela (x, y) para una lat/lng en el zoom z (slippy map)."""
    n = 2**z
    x = int((lng + 180.0) / 360.0 * n)
    lat_rad = math.radians(lat)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y


def _descargar(z: int, x: int, y: int, destino: Path) -> None:
    pedido = urllib.request.Request(
        URL.format(z=z, x=x, y=y), headers={"User-Agent": UA}
    )
    try:
        with urllib.request.urlopen(pedido, timeout=20) as respuesta:
            destino.write_bytes(respuesta.read())
    except urllib.error.HTTPError as err:
        raise SystemExit(f"HTTP {err.code} al bajar {destino.name}") from err
    except urllib.error.URLError as err:
        raise SystemExit(f"Sin conexion al bajar {destino.name}: {err.reason}") from err


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    claves: list[str] = []
    nuevas = 0

    for z in range(ZOOM_MIN, ZOOM_MAX + 1):
        x0, y0 = _tile(LAT_MAX, LNG_MIN, z)  # esquina noroeste
        x1, y1 = _tile(LAT_MIN, LNG_MAX, z)  # esquina sureste
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                clave = f"{z}_{x}_{y}"
                destino = DEST / f"{clave}.png"
                if not destino.exists():
                    _descargar(z, x, y, destino)
                    nuevas += 1
                    time.sleep(PAUSA)
                claves.append(clave)

    claves.sort()
    (DEST / "manifest.json").write_text(
        json.dumps(claves, indent=0) + "\n", encoding="utf-8"
    )
    (DEST / "ATRIBUCION.md").write_text(
        "# Teselas del mapa (uso offline)\n\n"
        "Mapa base: © OpenStreetMap contributors. Datos bajo "
        "[ODbL](https://www.openstreetmap.org/copyright); teselas servidas por "
        "tile.openstreetmap.org bajo su política de uso.\n\n"
        "Estas teselas se descargaron **una sola vez** para el área del campus "
        "con `scripts/descargar_teselas.py`. Para producción conviene migrar a un "
        "proveedor de teselas con licencia o a teselas vectoriales (pmtiles) con "
        "un estilo propio de la UES.\n",
        encoding="utf-8",
    )
    print(f"{len(claves)} teselas ({nuevas} nuevas) en {DEST}")


if __name__ == "__main__":
    main()

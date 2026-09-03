#!/usr/bin/env python3
"""Regenera el grafo peatonal del campus (assets/seed/rutas.json).

Objetivo de esta version: que la linea de ruta NO cruce por encima de los
edificios y siga los caminos reales del campus de forma razonable.

Entradas:
  - assets/seed/lugares.json  -> lugares, poligonos de edificios, punto (centro)
  - assets/seed/campus.json    -> perimetro y campo deportivo (obstaculos)
  - scripts/datos/osm_campus_ways.json -> vialidades internas (service) de OSM
    (instantanea; --descargar la refresca desde Overpass)

Salida:
  - assets/seed/rutas.json  (mismo esquema: {nodos:[{id,punto,lugarId?}],
    aristas:[{a,b,tipo}]})

Metodo:
  1. Esqueleto de caminos = nodos de las vialidades OSM + subdivision de tramos
     largos.  Se descartan los tramos que crucen un edificio.
  2. Cada lugar del catalogo recibe un nodo conector `n_lug_<id>` colocado en la
     ENTRADA (borde del poligono que da al camino mas cercano), no en el centro.
  3. Densificado: se agregan aristas cortas entre nodos cercanos SOLO si el
     segmento no cruza ningun edificio (poligono inflado ~2 m).
  4. Validacion: 0 aristas cruzan un edificio; todos los `n_lug_*` quedan
     conectados al acceso principal.

Requiere: solo la biblioteca estandar de Python 3.
"""
from __future__ import annotations

import json
import math
import sys
import urllib.parse
import urllib.request
from collections import Counter, deque
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SEED = RAIZ / "assets" / "seed"
DATOS = Path(__file__).resolve().parent / "datos"
OSM_SNAP = DATOS / "osm_campus_ways.json"

# --- parametros ---
MARGEN_EDIFICIO_M = 1.5     # cuanto se "infla" cada edificio como obstaculo
SALIDA_PUERTA_M = 2.6       # cuanto sale la puerta del borde del edificio
FUSION_NODOS_M = 3.5        # nodos mas cercanos que esto se funden en uno
SUBDIVIDIR_M = 22.0         # tramos mas largos que esto se parten
DENSIFICAR_RADIO_M = 45.0   # radio para agregar aristas de relleno
GRADO_EXTRA_MAX = 3         # aristas de relleno nuevas por nodo, como tope
BBOX = (29.1198, -110.9650, 29.1236, -110.9598)  # s, w, n, e (descarga OSM)
# recorte: solo se usan vialidades OSM dentro de esta caja (campus + ~70 m).
RECORTE = (29.1200, -110.9647, 29.1232, -110.9605)  # s, w, n, e

# Trazado manual de la zona poniente: OSM no tiene caminos ahi. Bordea el campo
# deportivo por el NORTE, que es por donde se llega a Taller y Ciencias de la
# Salud desde el resto del campus. TODO: levantamiento real con los planos.
CAMINOS_PONIENTE = [
    [[29.12244, -110.96300], [29.12244, -110.96330], [29.12240, -110.96360],
     [29.12240, -110.96392], [29.12240, -110.96430]],
]

# Los edificios del nucleo norte (Domo, Aula Magna, Recursos Humanos, Cafeteria,
# K, I) estan muy juntos y con poligonos OSM sobredimensionados: sin estos
# pasillos, ir de uno a otro daba un rodeo enorme. Trazados por los huecos
# reales entre poligonos. TODO: verificar con los planos.
CAMINOS_NUCLEO = [
    # corredor norte-sur entre RH/Cafeteria (oeste) y Domo/K (este)
    [[29.12219, -110.961655], [29.12210, -110.961650], [29.12200, -110.961660],
     [29.12192, -110.961720], [29.12186, -110.961850]],
    # ramal este-oeste por el hueco RH-Aula Magna y Cafeteria-Edificio I
    [[29.12210, -110.961650], [29.12218, -110.961760], [29.12222, -110.961900],
     [29.12226, -110.961960]],
    # bajada del corredor a la plaza central / explanada
    [[29.12186, -110.961850], [29.12183, -110.961950], [29.12180, -110.962040]],
    # pila K / G / F (norte-sur, edificios pegados): pasillos este y oeste
    [[29.12200, -110.961720], [29.12188, -110.961720], [29.12176, -110.961700],
     [29.12164, -110.961690], [29.12152, -110.961700]],
    [[29.12197, -110.961030], [29.12186, -110.961030], [29.12174, -110.961030],
     [29.12162, -110.961040], [29.12152, -110.961060]],
    # une los pasillos este y oeste por el norte (entre Domo y K) y el sur (bajo F)
    [[29.12200, -110.961720], [29.12200, -110.961400], [29.12197, -110.961030]],
    [[29.12152, -110.961700], [29.12150, -110.961380], [29.12152, -110.961060]],
]

# --- proyeccion local a metros (plano tangente, suficiente a escala de campus) ---
LAT0, LNG0 = 29.1214, -110.9625
MX = 111_320.0 * math.cos(math.radians(LAT0))
MY = 110_540.0


def to_xy(lat, lng):
    return ((lng - LNG0) * MX, (lat - LAT0) * MY)


def to_ll(x, y):
    return (round(y / MY + LAT0, 6), round(x / MX + LNG0, 6))


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


# --- geometria (todo en coordenadas xy metros) ---
def _ccw(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def seg_cruza(p1, p2, p3, p4):
    d1 = _ccw(p3, p4, p1)
    d2 = _ccw(p3, p4, p2)
    d3 = _ccw(p1, p2, p3)
    d4 = _ccw(p1, p2, p4)
    if ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0)):
        return True
    return False


def punto_en_poly(p, poly):
    x, y = p
    dentro = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            dentro = not dentro
        j = i
    return dentro


def poly_centroide(poly):
    return (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))


def inflar(poly, m):
    """Empuja cada vertice alejandolo del centroide 'm' metros."""
    c = poly_centroide(poly)
    out = []
    for p in poly:
        v = (p[0] - c[0], p[1] - c[1])
        n = math.hypot(*v) or 1.0
        out.append((p[0] + v[0] / n * m, p[1] + v[1] / n * m))
    return out


def cierra(poly):
    return poly if poly[0] == poly[-1] else poly + [poly[0]]


def seg_libre(a, b, obstaculos, ignorar=None):
    """True si el segmento a-b no entra en ningun obstaculo (poly inflado)."""
    for oid, poly in obstaculos.items():
        if ignorar and oid in ignorar:
            continue
        if punto_en_poly(a, poly) or punto_en_poly(b, poly):
            return False
        for i in range(len(poly) - 1):
            if seg_cruza(a, b, poly[i], poly[i + 1]):
                return False
    return True


def cruza_poly_crudo(a, b, poly):
    """Version sin inflar, para la validacion final."""
    if punto_en_poly(a, poly) or punto_en_poly(b, poly):
        return True
    pc = cierra(poly)
    for i in range(len(pc) - 1):
        if seg_cruza(a, b, pc[i], pc[i + 1]):
            return True
    return False


def punto_mas_cercano_seg(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 == 0:
        return a
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / L2))
    return (ax + t * dx, ay + t * dy)


# --- carga ---
def descargar_osm():
    s, w, n, e = BBOX
    q = (
        "[out:json][timeout:90];("
        f'way["highway"~"^(footway|path|pedestrian|steps|service|living_street)$"]({s},{w},{n},{e});'
        ");out geom;"
    )
    req = urllib.request.Request(
        "https://overpass-api.de/api/interpreter",
        data=urllib.parse.urlencode({"data": q}).encode(),
        headers={"User-Agent": "UES-Rutas-dev/0.3 (github.com/7Wolfer/UES-Rutas)"},
    )
    with urllib.request.urlopen(req, timeout=100) as r:
        d = json.load(r)
    ways = [
        [[p["lat"], p["lon"]] for p in el.get("geometry", [])]
        for el in d.get("elements", [])
        if el.get("type") == "way" and el.get("geometry")
    ]
    DATOS.mkdir(exist_ok=True)
    OSM_SNAP.write_text(json.dumps({"ways": ways}, indent=1))
    return ways


def cargar_osm():
    if "--descargar" in sys.argv:
        return descargar_osm()
    if OSM_SNAP.exists():
        return json.loads(OSM_SNAP.read_text())["ways"]
    return descargar_osm()


# --- construccion del grafo ---
class Grafo:
    def __init__(self):
        self.nodos = {}       # id -> (x, y)
        self.lugar_de = {}    # id -> lugarId
        self.aristas = {}     # frozenset({a,b}) -> tipo
        self._k = 0

    def nuevo_id(self):
        while f"p{self._k}" in self.nodos:
            self._k += 1
        i = f"p{self._k}"
        self._k += 1
        return i

    def agregar_nodo(self, xy, id=None, lugar_id=None, fusion_m=FUSION_NODOS_M):
        if id is None:
            for nid, p in self.nodos.items():
                if not nid.startswith("n_lug_") and dist(p, xy) < fusion_m:
                    return nid
            id = self.nuevo_id()
        self.nodos[id] = xy
        if lugar_id:
            self.lugar_de[id] = lugar_id
        return id

    def agregar_arista(self, a, b, tipo="exterior"):
        if a == b:
            return
        self.aristas[frozenset((a, b))] = tipo

    def vecinos(self, nid):
        for k in self.aristas:
            if nid in k:
                yield next(x for x in k if x != nid)

    def conectados_desde(self, start):
        vis = {start}
        q = deque([start])
        while q:
            u = q.popleft()
            for v in self.vecinos(u):
                if v not in vis:
                    vis.add(v)
                    q.append(v)
        return vis


def main():
    lugares = json.loads((SEED / "lugares.json").read_text())
    campus = json.loads((SEED / "campus.json").read_text())
    # Trazado peatonal base (hecho a mano, previo a este script). Se lee de una
    # copia congelada para que regenerar sea idempotente y no se acumule.
    base_path = DATOS / "rutas_base.json"
    rutas_prev = json.loads(
        (base_path if base_path.exists() else SEED / "rutas.json").read_text()
    )
    osm_ways = cargar_osm()

    lug = {l["id"]: l for l in lugares}

    # obstaculos = edificios inflados. Se usan SIEMPRE (nada cruza un edificio).
    edificios = {}
    for l in lugares:
        if l.get("poligono") and len(l["poligono"]) >= 3:
            poly = [to_xy(p["lat"], p["lng"]) for p in l["poligono"]]
            edificios[l["id"]] = cierra(inflar(poly, MARGEN_EDIFICIO_M))
    # el campo deportivo se evita para la malla de relleno, pero NO bloquea los
    # conectores de la zona poniente (no hay caminos mapeados alli todavia).
    campo = cierra(inflar(
        [to_xy(p["lat"], p["lng"]) for p in campus["campoDeportivo"]], 3.0))
    obst = dict(edificios, __campo=campo)

    # poligonos crudos (validacion final)
    crudos = {}
    for l in lugares:
        if l.get("poligono") and len(l["poligono"]) >= 3:
            crudos[l["id"]] = [to_xy(p["lat"], p["lng"]) for p in l["poligono"]]

    g = Grafo()

    # ---- 1. esqueleto de caminos desde OSM ----
    def add_polilinea(pts_ll, tipo="exterior"):
        prev = None
        for lat, lng in pts_ll:
            xy = to_xy(lat, lng)
            nid = g.agregar_nodo(xy)
            if prev is not None:
                a, b = g.nodos[prev], xy
                d = dist(a, b)
                if d > SUBDIVIDIR_M:
                    pasos = int(d // SUBDIVIDIR_M) + 1
                    ant = prev
                    for k in range(1, pasos):
                        t = k / pasos
                        mid = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                        mnid = g.agregar_nodo(mid)
                        if seg_libre(g.nodos[ant], g.nodos[mnid], obst):
                            g.agregar_arista(ant, mnid, tipo)
                        ant = mnid
                    if seg_libre(g.nodos[ant], xy, obst):
                        g.agregar_arista(ant, nid, tipo)
                elif seg_libre(a, b, obst):
                    g.agregar_arista(prev, nid, tipo)
            prev = nid

    s, w_, n_, e = RECORTE
    def dentro_recorte(pt):
        return s <= pt[0] <= n_ and w_ <= pt[1] <= e

    for w in osm_ways:
        tramo = [p for p in w if dentro_recorte(p)]
        if len(tramo) >= 2:
            add_polilinea(tramo)
    for w in CAMINOS_PONIENTE + CAMINOS_NUCLEO:
        add_polilinea(w)

    # tambien el trazado a mano previo (nodos n0..nN y sus aristas de camino),
    # que aporta conocimiento del terreno; se filtran los tramos que cruzan.
    prev_xy = {}
    for n in rutas_prev["nodos"]:
        if not n["id"].startswith("n_lug_"):
            prev_xy[n["id"]] = to_xy(n["punto"]["lat"], n["punto"]["lng"])
    prev_map = {}
    for nid, xy in prev_xy.items():
        prev_map[nid] = g.agregar_nodo(xy)
    for a in rutas_prev["aristas"]:
        if a["a"] in prev_map and a["b"] in prev_map:
            na, nb = prev_map[a["a"]], prev_map[a["b"]]
            if na != nb and seg_libre(g.nodos[na], g.nodos[nb], obst):
                d = dist(g.nodos[na], g.nodos[nb])
                if d > SUBDIVIDIR_M:
                    add_polilinea([to_ll(*g.nodos[na]), to_ll(*g.nodos[nb])])
                else:
                    g.agregar_arista(na, nb, "exterior")

    # nodos de caminos que quedaron sueltos dentro de un edificio: fuera
    for nid, xy in list(g.nodos.items()):
        for oid, poly in obst.items():
            if punto_en_poly(xy, poly):
                c = poly_centroide(poly)
                v = (xy[0] - c[0], xy[1] - c[1])
                n = math.hypot(*v) or 1.0
                # empujar hasta 6 m fuera
                g.nodos[nid] = (c[0] + v[0] / n * (n + 6), c[1] + v[1] / n * (n + 6))
                break

    caminos = [nid for nid in g.nodos]  # nodos de camino (antes de conectores)

    # ---- 2. nodos conector por lugar (en la entrada) ----
    prev_conectores = {
        n["id"]: n for n in rutas_prev["nodos"] if n["id"].startswith("n_lug_")
    }
    tipo_conector_prev = {}
    for a in rutas_prev["aristas"]:
        for x in (a["a"], a["b"]):
            if x.startswith("n_lug_"):
                tipo_conector_prev[x] = a["tipo"]

    for l in lugares:
        nid = f"n_{l['id']}"
        if nid not in prev_conectores:
            continue
        c = to_xy(l["punto"]["lat"], l["punto"]["lng"])
        poly_crudo = crudos.get(l["id"])
        cercanos = sorted(caminos, key=lambda k: dist(g.nodos[k], c))[:8]

        puerta = None
        destino_camino = None
        if poly_crudo:
            pc = cierra(poly_crudo)
            for k in cercanos:
                pk = g.nodos[k]
                # donde el segmento centro->camino sale del poligono
                salida = None
                for i in range(len(pc) - 1):
                    if seg_cruza(c, pk, pc[i], pc[i + 1]):
                        salida = punto_mas_cercano_seg(
                            _interseccion(c, pk, pc[i], pc[i + 1]), pc[i], pc[i + 1]
                        )
                        break
                base = salida if salida else min(
                    (punto_mas_cercano_seg(pk, pc[i], pc[i + 1]) for i in range(len(pc) - 1)),
                    key=lambda q: dist(q, pk),
                )
                # empujar hacia el camino, fuera del edificio
                v = (pk[0] - base[0], pk[1] - base[1])
                n = math.hypot(*v) or 1.0
                cand = (base[0] + v[0] / n * SALIDA_PUERTA_M,
                        base[1] + v[1] / n * SALIDA_PUERTA_M)
                if punto_en_poly(cand, edificios.get(l["id"], [])):
                    continue
                if seg_libre(cand, pk, edificios, ignorar={l["id"]}):
                    puerta, destino_camino = cand, k
                    break
        if puerta is None:
            # punto suelto (sin poligono) o sin puerta clara: sacar el punto de
            # TODO edificio (poligono inflado) y conectar al camino claro mas
            # cercano, buscando entre todos los nodos, no solo los 8 primeros.
            p = c
            for _ in range(6):
                movido = False
                for oid, poly in obst.items():
                    if punto_en_poly(p, poly):
                        cc = poly_centroide(poly)
                        v = (p[0] - cc[0], p[1] - cc[1])
                        n = math.hypot(*v) or 1.0
                        # radio del poligono en esa direccion + holgura
                        rad = max(dist(cc, q) for q in poly)
                        p = (cc[0] + v[0] / n * (rad + SALIDA_PUERTA_M),
                             cc[1] + v[1] / n * (rad + SALIDA_PUERTA_M))
                        movido = True
                if not movido:
                    break
            todos = sorted(caminos, key=lambda k: dist(g.nodos[k], p))
            for k in todos[:20]:
                if seg_libre(p, g.nodos[k], edificios, ignorar={l["id"]}):
                    puerta, destino_camino = p, k
                    break
            if puerta is None:
                # ultimo recurso: nodo intermedio a mitad de camino, fuera de todo
                k = todos[0]
                mid = ((p[0] + g.nodos[k][0]) / 2, (p[1] + g.nodos[k][1]) / 2)
                for oid, poly in obst.items():
                    if punto_en_poly(mid, poly):
                        cc = poly_centroide(poly)
                        v = (mid[0] - cc[0], mid[1] - cc[1])
                        n = math.hypot(*v) or 1.0
                        rad = max(dist(cc, q) for q in poly)
                        mid = (cc[0] + v[0] / n * (rad + SALIDA_PUERTA_M),
                               cc[1] + v[1] / n * (rad + SALIDA_PUERTA_M))
                mnid = g.agregar_nodo(mid)
                g.agregar_arista(mnid, k, "exterior")
                puerta, destino_camino = p, mnid

        g.nodos[nid] = puerta
        g.lugar_de[nid] = l["id"]
        tipo = tipo_conector_prev.get(nid, "pasillo")
        g.agregar_arista(nid, destino_camino, tipo)
        # hasta 2 conexiones mas a caminos claros cercanos (mejor ruteo, evita
        # que el lugar quede como "callejon sin salida" con una sola entrada)
        extra = 0
        for k in sorted(caminos, key=lambda k: dist(g.nodos[nid], g.nodos[k])):
            if k == destino_camino or extra >= 2:
                continue
            if dist(g.nodos[nid], g.nodos[k]) > 55:
                break
            if seg_libre(g.nodos[nid], g.nodos[k], edificios, ignorar={l["id"]}):
                g.agregar_arista(nid, k, "pasillo")
                extra += 1

    # ---- 3. densificar: aristas cortas y libres entre nodos cercanos ----
    ids = list(g.nodos)
    nuevos_por_nodo = {i: 0 for i in ids}
    for i, a in enumerate(ids):
        for b in ids[i + 1:]:
            fa = frozenset((a, b))
            if fa in g.aristas:
                continue
            d = dist(g.nodos[a], g.nodos[b])
            if d > DENSIFICAR_RADIO_M:
                continue
            if nuevos_por_nodo[a] >= GRADO_EXTRA_MAX or nuevos_por_nodo[b] >= GRADO_EXTRA_MAX:
                continue
            ign = set()
            if a.startswith("n_lug_"):
                ign.add(g.lugar_de.get(a))
            if b.startswith("n_lug_"):
                ign.add(g.lugar_de.get(b))
            if seg_libre(g.nodos[a], g.nodos[b], obst, ignorar=ign):
                tipo = "pasillo" if (a.startswith("n_lug_") or b.startswith("n_lug_")) else "exterior"
                g.agregar_arista(a, b, tipo)
                nuevos_por_nodo[a] += 1
                nuevos_por_nodo[b] += 1

    # ---- 3b. ningun lugar debe quedar como hoja (una sola entrada): se le
    #          suman las 2 conexiones claras mas cercanas, con radio holgado ----
    for nid in [n for n in g.nodos if n.startswith("n_lug_")]:
        grado = sum(1 for k in g.aristas if nid in k)
        if grado > 1:
            continue
        ign = {g.lugar_de.get(nid)}
        sumadas = 0
        for k in sorted(g.nodos, key=lambda k: dist(g.nodos[nid], g.nodos[k])):
            if k == nid or frozenset((nid, k)) in g.aristas:
                continue
            if dist(g.nodos[nid], g.nodos[k]) > 90:
                break
            ik = set(ign)
            if k.startswith("n_lug_"):
                ik.add(g.lugar_de.get(k))
            if seg_libre(g.nodos[nid], g.nodos[k], edificios, ignorar=ik):
                g.agregar_arista(nid, k, "pasillo")
                sumadas += 1
                if sumadas >= 2:
                    break

    # ---- 4. tipo de acceso: SOLO la arista mas corta del conector lleva
    #         rampa/escalera (es la del porton); el resto queda como camino ----
    for nid, tp in (("n_lug_acceso_principal", "rampa"),
                    ("n_lug_acceso_poniente", "escalera")):
        if nid not in g.nodos:
            continue
        incidentes = [k for k in g.aristas if nid in k]
        if not incidentes:
            continue
        corta = min(
            incidentes,
            key=lambda k: dist(g.nodos[nid],
                               g.nodos[next(x for x in k if x != nid)]),
        )
        g.aristas[corta] = tp

    # ---- 5. conectividad: todo n_lug_* alcanzable desde acceso principal ----
    raiz = "n_lug_acceso_principal"
    alcanzables = g.conectados_desde(raiz)
    for nid in list(g.nodos):
        if nid.startswith("n_lug_") and nid not in alcanzables:
            ign = {g.lugar_de.get(nid)}
            cand = sorted(
                (k for k in alcanzables),
                key=lambda k: dist(g.nodos[nid], g.nodos[k]),
            )
            hecho = False
            for k in cand[:15]:
                if seg_libre(g.nodos[nid], g.nodos[k], edificios, ignorar=ign):
                    g.agregar_arista(nid, k, "pasillo")
                    hecho = True
                    break
            if not hecho and cand:
                # nodo puente a mitad de camino, empujado fuera de cualquier obst
                k = cand[0]
                mid = ((g.nodos[nid][0] + g.nodos[k][0]) / 2,
                       (g.nodos[nid][1] + g.nodos[k][1]) / 2)
                for _ in range(6):
                    for poly in obst.values():
                        if punto_en_poly(mid, poly):
                            cc = poly_centroide(poly)
                            v = (mid[0] - cc[0], mid[1] - cc[1])
                            n = math.hypot(*v) or 1.0
                            rad = max(dist(cc, q) for q in poly)
                            mid = (cc[0] + v[0] / n * (rad + SALIDA_PUERTA_M),
                                   cc[1] + v[1] / n * (rad + SALIDA_PUERTA_M))
                mnid = g.agregar_nodo(mid)
                if seg_libre(g.nodos[nid], mid, edificios, ignorar=ign) and seg_libre(
                    mid, g.nodos[k], edificios
                ):
                    g.agregar_arista(nid, mnid, "pasillo")
                    g.agregar_arista(mnid, k, "exterior")
                else:
                    g.agregar_arista(nid, k, "pasillo")
                    print(f"  aviso: {nid} conectado con arista que puede rozar algo")
            alcanzables = g.conectados_desde(raiz)

    # ---- 6. podar nodos de camino sin aristas ----
    usados = set()
    for k in g.aristas:
        usados |= set(k)
    for nid in list(g.nodos):
        if nid not in usados and not nid.startswith("n_lug_"):
            del g.nodos[nid]

    # ---- 7. validacion final ----
    cruces = []
    for k, tipo in g.aristas.items():
        a, b = tuple(k)
        pa, pb = g.nodos[a], g.nodos[b]
        for lid, poly in crudos.items():
            if a == f"n_{lid}" or b == f"n_{lid}":
                continue
            if cruza_poly_crudo(pa, pb, poly):
                cruces.append((a, b, tipo, lid))
    alcanzables = g.conectados_desde(raiz)
    faltan = [n for n in g.nodos if n.startswith("n_lug_") and n not in alcanzables]

    # ---- 8. escribir ----
    nodos_out = []
    for nid, xy in g.nodos.items():
        lat, lng = to_ll(*xy)
        o = {"id": nid, "punto": {"lat": lat, "lng": lng}}
        if nid in g.lugar_de:
            o["lugarId"] = g.lugar_de[nid]
        nodos_out.append(o)
    aristas_out = [
        {"a": sorted(k)[0], "b": sorted(k)[1], "tipo": t} for k, t in g.aristas.items()
    ]
    # conectores primero-estables: ordenar nodos camino, luego conectores
    nodos_out.sort(key=lambda o: (o["id"].startswith("n_lug_"), o["id"]))

    salida = {"nodos": nodos_out, "aristas": aristas_out}
    destino = SEED / "rutas.json"
    if "--dry-run" in sys.argv:
        destino = Path(__file__).resolve().parent.parent / "rutas.preview.json"
    destino.write_text(json.dumps(salida, indent=1, ensure_ascii=False) + "\n")

    # ---- reporte ----
    grados = {}
    for k in g.aristas:
        for x in k:
            grados[x] = grados.get(x, 0) + 1
    print(f"nodos:   {len(nodos_out)}  (antes {len(rutas_prev['nodos'])})")
    print(f"aristas: {len(aristas_out)}  (antes {len(rutas_prev['aristas'])})")
    print(f"grado medio: {2*len(aristas_out)/len(nodos_out):.2f}")
    print("tipos:", dict(Counter(a['tipo'] for a in aristas_out)))
    print(f"aristas que cruzan un edificio: {len(cruces)}")
    for c in cruces:
        print("   ", c)
    print(f"conectores sin conexion al acceso: {len(faltan)} {faltan}")
    print(f"-> {destino}")
    if cruces or faltan:
        sys.exit(1)


def _interseccion(p1, p2, p3, p4):
    """Punto de interseccion de las rectas p1p2 y p3p4 (se asume que cruzan)."""
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3
    x4, y4 = p4
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(den) < 1e-12:
        return p1
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


if __name__ == "__main__":
    main()

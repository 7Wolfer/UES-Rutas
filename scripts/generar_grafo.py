#!/usr/bin/env python3
"""Genera el grafo peatonal del campus (assets/seed/rutas.json) a partir del
plano oficial: por donde de verdad se camina.

Entradas (las produce scripts/importar_plano.py):
  - scripts/datos/plano_caminable.png  máscara 0/255 a media resolución del plano
                                       (andadores, explanada, estacionamientos)
  - scripts/datos/plano_georef.json    afín píxel(plano) -> (lng, lat)
  - assets/seed/lugares.json           lugares, polígonos y bandera `transitable`

Método:
  1. Malla de nodos cada PASO_M metros sobre la máscara; aristas entre vecinos
     cercanos solo si el segmento completo cae dentro de la máscara.
  2. Un nodo conector `n_<lugarId>` por lugar, en su entrada (borde del polígono
     que da al camino más cercano), enganchado a la malla.
  3. Tramos manuales tipados (escalinata F–H, cruce al gimnasio, portón poniente).
  4. Reparaciones: ningún lugar como hoja, conectividad desde el acceso
     principal, rodeos locales (nodos a pocos metros pero lejos por el grafo
     se unen siguiendo la máscara), poda de nodos sueltos, colapso de nodos
     colineales.
  5. Validación: ninguna arista cruza un edificio; todo lugar alcanzable; toda
     arista de camino dentro de la máscara.  Sale con 1 si algo falla.

Salida compacta (sin "tipo" cuando es exterior, que es el valor por defecto).

Uso:
    python3 scripts/generar_grafo.py            # escribe assets/seed/rutas.json
    python3 scripts/generar_grafo.py --dry-run  # escribe rutas.preview.json

Requiere: numpy, Pillow.
"""
from __future__ import annotations

import heapq
import json
import math
import sys
from collections import Counter, defaultdict, deque
from pathlib import Path

import numpy as np
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
SEED = RAIZ / "assets" / "seed"
DATOS = Path(__file__).resolve().parent / "datos"

# ---------------------------------------------------------------- parámetros
PASO_M = 4.0                 # separación de la malla (los andadores miden 3–4 m)
TOLERANCIA_MUESTRAS = 2      # muestras (cada 2 px) que pueden caer fuera de la máscara
SALIDA_PUERTA_M = 2.0        # cuánto sale la puerta del borde del edificio
MARGEN_EDIFICIO_M = 0.5      # inflado de los edificios como obstáculo
RADIO_CONECTOR_M = 60.0      # hasta dónde buscar camino para un conector
COLINEAL_M = 0.8             # desvío máximo para colapsar un nodo de grado 2
# Rodeos: dos nodos a <= RODEO_RADIO_M en recta cuya distancia por el grafo
# supera RODEO_FACTOR * recta + RODEO_EXTRA_M se unen siguiendo la máscara.
RODEO_RADIO_M = 12.0
RODEO_FACTOR = 3.0
RODEO_EXTRA_M = 6.0
# vecinos de la malla (en pasos); las inversas salen solas por ser no dirigido
DESPLAZAMIENTOS = [(1, 0), (0, 1), (1, 1), (1, -1), (2, 1), (2, -1), (1, 2), (1, -2)]

# Tramos que la máscara no puede dar (px del plano original, tipo de arista).
TRAMOS_MANUALES = [
    # escalinata entre F y H (salida oriente)
    ((2178, 905), (2282, 1150), "escalera"),
    # cruce de Av. Ley Federal del Trabajo: plaza de acceso -> lote del gimnasio
    ((2470, 1290), (2440, 1410), "exterior"),
    # portón poniente (con escalones): de la banqueta al lote poniente
    ((1156, 1200), (1100, 1090), "escalera"),
    # acceso principal: de la plaza semicircular, bajo el pórtico de N, a la
    # explanada central (el edificio N se cruza por su pasaje de planta baja)
    ((1790, 1198), (1790, 1052), "pasillo"),
    # banqueta de Av. Ley Federal del Trabajo: del acceso principal a la plaza
    # de acceso (y de ahí al gimnasio), por fuera del campus
    ((1790, 1246), (2470, 1290), "exterior"),
]

LAT0 = 29.1214
M_POR_GRADO_LNG = 111_320.0 * math.cos(math.radians(LAT0))
M_POR_GRADO_LAT = 110_540.0


def log(*a):
    print(*a, flush=True)


# ================================================================ geometría
class Geo:
    """Afín del plano y su inversa. Trabaja en px de MEDIA resolución (la máscara)."""

    def __init__(self, px, py, sub=2):
        self.px, self.py, self.sub = px, py, sub
        a, b, c = px
        d, e, f = py
        det = a * e - b * d
        self._inv = ((e / det, -b / det), (-d / det, a / det))
        self._c, self._f = c, f
        self.px_por_m = 1 / math.hypot(a * M_POR_GRADO_LNG, d * M_POR_GRADO_LAT) / sub

    def a_ll(self, x, y):
        X, Y = x * self.sub, y * self.sub
        return (round(self.py[0] * X + self.py[1] * Y + self.py[2], 6),
                round(self.px[0] * X + self.px[1] * Y + self.px[2], 6))

    def a_px(self, lat, lng):
        u, v = lng - self._c, lat - self._f
        (i00, i01), (i10, i11) = self._inv
        return ((i00 * u + i01 * v) / self.sub, (i10 * u + i11 * v) / self.sub)

    def m(self, a, b):
        return math.hypot(a[0] - b[0], a[1] - b[1]) / self.px_por_m


def _ccw(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def seg_cruza(p1, p2, p3, p4):
    d1, d2 = _ccw(p3, p4, p1), _ccw(p3, p4, p2)
    d3, d4 = _ccw(p1, p2, p3), _ccw(p1, p2, p4)
    return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0))


def punto_en_poly(p, poly):
    x, y = p
    dentro = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi):
            dentro = not dentro
        j = i
    return dentro


def centroide(poly):
    return (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))


def inflar(poly, px):
    c = centroide(poly)
    out = []
    for p in poly:
        v = (p[0] - c[0], p[1] - c[1])
        n = math.hypot(*v) or 1.0
        out.append((p[0] + v[0] / n * px, p[1] + v[1] / n * px))
    return out


def cierra(poly):
    return poly if poly[0] == poly[-1] else poly + [poly[0]]


def seg_libre(a, b, obstaculos, ignorar=()):
    for oid, poly in obstaculos.items():
        if oid in ignorar:
            continue
        if punto_en_poly(a, poly) or punto_en_poly(b, poly):
            return False
        for i in range(len(poly) - 1):
            if seg_cruza(a, b, poly[i], poly[i + 1]):
                return False
    return True


def cruza_crudo(a, b, poly):
    if punto_en_poly(a, poly) or punto_en_poly(b, poly):
        return True
    pc = cierra(poly)
    return any(seg_cruza(a, b, pc[i], pc[i + 1]) for i in range(len(pc) - 1))


def interseccion(p1, p2, p3, p4):
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = p3
    x4, y4 = p4
    den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(den) < 1e-12:
        return p1
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
    return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


def punto_mas_cercano_seg(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dy * dy
    if L2 == 0:
        return a
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L2))
    return (a[0] + t * dx, a[1] + t * dy)


def dist_punto_seg(p, a, b):
    q = punto_mas_cercano_seg(p, a, b)
    return math.hypot(p[0] - q[0], p[1] - q[1])


# ================================================================ máscara
class Mascara:
    def __init__(self, m: np.ndarray):
        self.m = m
        self.h, self.w = m.shape

    def dentro(self, p):
        x, y = int(round(p[0])), int(round(p[1]))
        return 0 <= x < self.w and 0 <= y < self.h and bool(self.m[y, x])

    def seg_dentro(self, a, b, tol=TOLERANCIA_MUESTRAS):
        n = max(2, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 2))
        fuera = 0
        for i in range(n + 1):
            t = i / n
            if not self.dentro((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)):
                fuera += 1
                if fuera > tol:
                    return False
        return True

    def erosionada(self, r):
        m = self.m
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dy or dx:
                    m = m & np.roll(np.roll(self.m, dy, 0), dx, 1)
        return Mascara(m)


# ================================================================ grafo
class Grafo:
    def __init__(self):
        self.nodos: dict[str, tuple[float, float]] = {}
        self.lugar_de: dict[str, str] = {}
        self.aristas: dict[frozenset, str] = {}
        self.ady: dict[str, set[str]] = {}
        self.manuales: set[frozenset] = set()
        self.puentes: set[frozenset] = set()     # puentes rectos (solo para el dibujo)
        self._k = 0

    def nuevo(self, xy, prefijo="p"):
        i = f"{prefijo}{self._k}"
        self._k += 1
        self.nodos[i] = xy
        return i

    def arista(self, a, b, tipo="exterior", manual=False):
        if a == b:
            return
        k = frozenset((a, b))
        self.aristas[k] = tipo
        self.ady.setdefault(a, set()).add(b)
        self.ady.setdefault(b, set()).add(a)
        if manual:
            self.manuales.add(k)

    def quitar_arista(self, k):
        a, b = tuple(k)
        self.aristas.pop(k, None)
        self.manuales.discard(k)
        self.puentes.discard(k)
        self.ady.get(a, set()).discard(b)
        self.ady.get(b, set()).discard(a)

    def quitar_nodo(self, n):
        for v in list(self.ady.get(n, ())):
            self.quitar_arista(frozenset((n, v)))
        self.ady.pop(n, None)
        self.nodos.pop(n, None)

    def vecinos(self, n):
        return list(self.ady.get(n, ()))

    def grado(self, n):
        return len(self.ady.get(n, ()))

    def alcanzables(self, s):
        vis = {s}
        q = deque([s])
        while q:
            u = q.popleft()
            for v in self.vecinos(u):
                if v not in vis:
                    vis.add(v)
                    q.append(v)
        return vis

    def mas_cercanos(self, p, n=10, solo_malla=True):
        cand = [(math.hypot(q[0] - p[0], q[1] - p[1]), i) for i, q in self.nodos.items()
                if not solo_malla or not i.startswith("n_")]
        cand.sort()
        return [i for _, i in cand[:n]]


# ================================================================ principal
def main():
    dry = "--dry-run" in sys.argv
    lugares = json.loads((SEED / "lugares.json").read_text())
    georef = json.loads((DATOS / "plano_georef.json").read_text())
    geo = Geo(georef["px"], georef["py"])
    mask = Mascara(np.asarray(Image.open(DATOS / "plano_caminable.png").convert("L")) > 127)
    log(f"máscara {mask.w}x{mask.h}, {geo.px_por_m:.2f} px/m, paso {PASO_M} m")

    # polígonos en px de la máscara
    polys = {}
    obst = {}
    for l in lugares:
        if l.get("poligono") and len(l["poligono"]) >= 3:
            poly = [geo.a_px(p["lat"], p["lng"]) for p in l["poligono"]]
            polys[l["id"]] = poly
            if not l.get("transitable"):
                obst[l["id"]] = cierra(inflar(poly, MARGEN_EDIFICIO_M * geo.px_por_m))

    g = Grafo()

    # ---- 1. malla sobre la máscara ----
    paso = max(4, int(round(PASO_M * geo.px_por_m)))
    interior = mask.erosionada(1)
    idx = {}
    for gy, y in enumerate(range(paso // 2, mask.h, paso)):
        for gx, x in enumerate(range(paso // 2, mask.w, paso)):
            if interior.dentro((x, y)):
                idx[(gx, gy)] = g.nuevo((float(x), float(y)))
    for (gx, gy), a in idx.items():
        for dx, dy in DESPLAZAMIENTOS:
            b = idx.get((gx + dx, gy + dy))
            if b and mask.seg_dentro(g.nodos[a], g.nodos[b]):
                g.arista(a, b)
    log(f"malla: {len(idx)} nodos, {len(g.aristas)} aristas")

    # ---- 1b. unir componentes de malla siguiendo la máscara ----
    # En corredores angostos la malla se rompe aunque la máscara siga: se
    # recorren los píxeles caminables (BFS) entre componentes y se insertan
    # nodos por el corredor real.
    def pixel_caminable_cercano(s, radio_px):
        r = int(radio_px)
        mejor, dist = None, 1e9
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                d = dx * dx + dy * dy
                if d < dist and mask.dentro((s[0] + dx, s[1] + dy)):
                    mejor, dist = (s[0] + dx, s[1] + dy), d
        return mejor

    def puente_por_mascara(isla: set[str], principal: set[str], etiqueta="corredor",
                           max_m=None) -> bool:
        """BFS por los píxeles caminables desde `isla` hasta tocar `principal`;
        inserta una cadena de nodos por el corredor.  Con `max_m` el recorrido
        se acota a esa longitud (en metros) y se descarta si la supera."""
        tope_px = None if max_m is None else int(max_m * geo.px_por_m * 1.5) + 2
        objetivo = {}
        for k in principal:
            if k.startswith("n_"):
                continue
            x, y = g.nodos[k]
            objetivo[(int(round(x)), int(round(y)))] = k
        prev = {}
        q = deque()
        for k in isla:
            x, y = g.nodos[k]
            s = (int(round(x)), int(round(y)))
            if not mask.dentro(s):
                s = pixel_caminable_cercano(s, 8 * geo.px_por_m)
                if s is None:
                    continue
            if s not in prev:
                prev[s] = None
                q.append((s, k, 0))
        meta = None
        while q:
            (x, y), origen, pasos = q.popleft()
            if (x, y) in objetivo and objetivo[(x, y)] not in isla:
                meta = ((x, y), origen)
                break
            if tope_px is not None and pasos >= tope_px:
                continue
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    n = (x + dx, y + dy)
                    if n not in prev and mask.dentro(n):
                        prev[n] = (x, y)
                        q.append((n, origen, pasos + 1))
        if meta is None:
            return False
        camino = []
        cur = meta[0]
        while cur is not None:
            camino.append(cur)
            cur = prev[cur]
        camino.reverse()
        espaciado = max(3, paso // 2)
        puntos = [(float(camino[i][0]), float(camino[i][1]))
                  for i in range(espaciado, len(camino) - 1, espaciado)]
        poli = [g.nodos[meta[1]], *puntos, g.nodos[objetivo[meta[0]]]]
        largo = sum(geo.m(a, b) for a, b in zip(poli, poli[1:]))
        if max_m is not None and largo > max_m:
            return False
        cadena = [meta[1]]
        for px_ in puntos:
            cerca = g.mas_cercanos(px_, n=1)
            if cerca and math.hypot(g.nodos[cerca[0]][0] - px_[0], g.nodos[cerca[0]][1] - px_[1]) < 3:
                cadena.append(cerca[0])
            else:
                cadena.append(g.nuevo(px_))
        cadena.append(objetivo[meta[0]])
        for a, b in zip(cadena, cadena[1:]):
            if a != b:
                g.arista(a, b, "exterior" if not (a.startswith("n_") or b.startswith("n_")) else "pasillo")
        if etiqueta != "rodeo":
            log(f"  {etiqueta}: {meta[1]} -> {objetivo[meta[0]]} por la máscara, {len(cadena) - 1} tramos")
        return True

    def componentes_malla():
        vistos, comps = set(), []
        for n in list(g.nodos):
            if n in vistos:
                continue
            comp = g.alcanzables(n)
            vistos |= comp
            comps.append(comp)
        comps.sort(key=len, reverse=True)
        return comps

    comps = componentes_malla()
    log(f"componentes de malla: {len(comps)} (mayor: {len(comps[0])} nodos)")
    principal = set(comps[0])
    for comp in comps[1:]:
        if len(comp) < 2:
            continue
        if puente_por_mascara(comp, principal, "unión de malla"):
            principal = g.alcanzables(next(iter(principal)))
    comps = componentes_malla()
    log(f"tras unir: {len(comps)} componentes (mayor: {len(comps[0])} nodos)")

    # ---- 2. conectores por lugar ----
    def conectar(nid, p, ignorar, tipo="pasillo", max_extra=2, radio=RADIO_CONECTOR_M):
        """Engancha `nid` a los nodos de malla cercanos con segmento libre y en máscara."""
        hechas = 0
        for k in g.mas_cercanos(p, n=16):
            q = g.nodos[k]
            if geo.m(p, q) > radio:
                break
            if seg_libre(p, q, obst, ignorar) and mask.seg_dentro(p, q, tol=6):
                g.arista(nid, k, tipo)
                hechas += 1
                if hechas > max_extra:
                    break
        return hechas

    sin_conectar = []
    for l in lugares:
        lid = l["id"]
        nid = f"n_{lid}"
        c = geo.a_px(l["punto"]["lat"], l["punto"]["lng"])
        poly = polys.get(lid)
        transitable = l.get("transitable", False)
        puerta = None
        if poly and not transitable:
            pc = cierra(poly)
            for k in g.mas_cercanos(c, n=12):
                pk = g.nodos[k]
                salida = None
                for i in range(len(pc) - 1):
                    if seg_cruza(c, pk, pc[i], pc[i + 1]):
                        salida = punto_mas_cercano_seg(interseccion(c, pk, pc[i], pc[i + 1]), pc[i], pc[i + 1])
                        break
                base = salida or min((punto_mas_cercano_seg(pk, pc[i], pc[i + 1]) for i in range(len(pc) - 1)),
                                     key=lambda q: math.hypot(q[0] - pk[0], q[1] - pk[1]))
                v = (pk[0] - base[0], pk[1] - base[1])
                n = math.hypot(*v) or 1.0
                d = SALIDA_PUERTA_M * geo.px_por_m
                cand = (base[0] + v[0] / n * d, base[1] + v[1] / n * d)
                if punto_en_poly(cand, obst.get(lid, [])):
                    continue
                if seg_libre(cand, pk, obst, (lid,)) and mask.seg_dentro(cand, pk, tol=6):
                    puerta = cand
                    break
            if puerta is None:
                # sin camino claro: puerta en el borde más cercano a la malla
                k = g.mas_cercanos(c, n=1)[0]
                pk = g.nodos[k]
                base = min((punto_mas_cercano_seg(pk, pc[i], pc[i + 1]) for i in range(len(pc) - 1)),
                           key=lambda q: math.hypot(q[0] - pk[0], q[1] - pk[1]))
                v = (pk[0] - base[0], pk[1] - base[1])
                n = math.hypot(*v) or 1.0
                d = SALIDA_PUERTA_M * geo.px_por_m
                puerta = (base[0] + v[0] / n * d, base[1] + v[1] / n * d)
        else:
            puerta = c
        g.nodos[nid] = puerta
        g.lugar_de[nid] = lid
        if conectar(nid, puerta, (lid,)) == 0:
            sin_conectar.append(nid)

    # ---- 3. tramos manuales ----
    def nodo_en(p_full):
        """Nodo para un extremo de tramo manual: el conector o nodo de malla más
        cercano (≤ 20 m); si no hay, un nodo nuevo enganchado sin verificar al
        de malla más próximo (los tramos manuales existen justo donde la
        máscara no llega)."""
        p = (p_full[0] / geo.sub, p_full[1] / geo.sub)
        mejor, dist = None, 1e9
        for i, q in g.nodos.items():
            d = math.hypot(q[0] - p[0], q[1] - p[1])
            if d < dist:
                mejor, dist = i, d
        if mejor and dist <= 20 * geo.px_por_m:
            return mejor
        nid = g.nuevo(p, "m")
        k = g.mas_cercanos(p, n=1)[0]
        g.arista(nid, k, "exterior", manual=True)
        log(f"  tramo manual: nodo nuevo en {tuple(int(v) for v in p_full)} -> {k} ({geo.m(p, g.nodos[k]):.0f} m)")
        return nid

    for a_full, b_full, tipo in TRAMOS_MANUALES:
        a, b = nodo_en(a_full), nodo_en(b_full)
        g.arista(a, b, tipo, manual=True)

    # ---- 3b. conectores sin enganche: al nodo más cercano, aunque roce ----
    for nid in sin_conectar:
        p = g.nodos[nid]
        if g.grado(nid) > 0:
            continue
        k = g.mas_cercanos(p, n=1)[0]
        g.arista(nid, k, "pasillo")
        log(f"  aviso: {nid} enganchado sin verificar ({geo.m(p, g.nodos[k]):.0f} m)")

    # ---- 4. ningún lugar como hoja ----
    for nid in [n for n in g.nodos if n.startswith("n_")]:
        if g.grado(nid) <= 1:
            conectar(nid, g.nodos[nid], (g.lugar_de[nid],), max_extra=1, radio=90)

    # ---- 5. tipo del acceso principal / poniente en su arista más corta ----
    for nid, tp in (("n_lug_acceso_principal", "rampa"), ("n_lug_acceso_poniente", "escalera")):
        if nid in g.nodos:
            inc = [k for k in g.aristas if nid in k and k not in g.manuales]
            if inc:
                corta = min(inc, key=lambda k: geo.m(g.nodos[nid], g.nodos[next(x for x in k if x != nid)]))
                g.aristas[corta] = tp

    # ---- 6. conectividad desde el acceso principal ----
    raiz = "n_lug_acceso_principal"

    # 6a. primero, todo lo que se pueda unir siguiendo la máscara (con
    # conectores y tramos manuales ya puestos), hasta que no cambie nada
    cambio = True
    while cambio:
        cambio = False
        alc = g.alcanzables(raiz)
        for comp in componentes_malla():
            if comp & alc:
                continue
            if puente_por_mascara(comp, alc, "corredor"):
                cambio = True
                break

    # 6b. lo que siga aislado se puentea en recta, siempre el salto más corto
    # disponible primero; un puente largo no puede cruzar ningún edificio.
    while True:
        alc = g.alcanzables(raiz)
        pendientes = [n for n in g.nodos if n.startswith("n_") and n not in alc]
        if not pendientes:
            break
        mejor = None
        for nid in pendientes:
            p = g.nodos[nid]
            for k in sorted(alc, key=lambda k: math.hypot(g.nodos[k][0] - p[0], g.nodos[k][1] - p[1]))[:30]:
                d = geo.m(p, g.nodos[k])
                if mejor and d >= mejor[0]:
                    break
                ign = (g.lugar_de.get(nid),) if d <= 10 else ()
                if seg_libre(p, g.nodos[k], obst, ign):
                    mejor = (d, nid, k)
                    break
        if mejor is None:
            for nid in pendientes:
                log(f"  SIN PUENTE: {nid} queda desconectado; revisar máscara/tramos")
            break
        d, nid, k = mejor
        g.arista(nid, k, "pasillo")
        g.puentes.add(frozenset((nid, k)))
        log(f"  puente recto: {nid} -> {k} ({d:.0f} m)")

    # ---- 6c. rodeos locales ----
    # Dos nodos de malla a pocos metros en recta pero lejos por el grafo
    # delatan un pasaje angosto donde la malla se rompió sin aislar nada (el
    # camino existe, pero dando la vuelta a media manzana).  Se unen siguiendo
    # la máscara, del par más cercano al más lejano, hasta que no quede ninguno.
    def distancias_acotadas(o, lim_m):
        D = {o: 0.0}
        pq = [(0.0, o)]
        while pq:
            d, u = heapq.heappop(pq)
            if d > lim_m:
                break
            if d > D.get(u, 1e18):
                continue
            for v in g.vecinos(u):
                nd = d + geo.m(g.nodos[u], g.nodos[v])
                if nd < D.get(v, 1e18):
                    D[v] = nd
                    heapq.heappush(pq, (nd, v))
        return D

    def tope_rodeo(recta_m):
        return RODEO_FACTOR * recta_m + RODEO_EXTRA_M

    def pares_con_rodeo():
        malla = sorted(n for n in g.nodos if not n.startswith("n_"))
        celda = RODEO_RADIO_M * geo.px_por_m
        rejilla = defaultdict(list)
        for n in malla:
            x, y = g.nodos[n]
            rejilla[(int(x // celda), int(y // celda))].append(n)
        pares = []
        for u in malla:
            D = distancias_acotadas(u, tope_rodeo(RODEO_RADIO_M))
            x, y = g.nodos[u]
            cx, cy = int(x // celda), int(y // celda)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for v in rejilla.get((cx + dx, cy + dy), ()):
                        if v <= u:
                            continue
                        recta = geo.m(g.nodos[u], g.nodos[v])
                        if recta <= RODEO_RADIO_M and D.get(v, 1e18) > tope_rodeo(recta):
                            pares.append((recta, u, v))
        pares.sort()
        return pares

    rodeos_total = 0
    for ronda in range(1, 5):
        pares = pares_con_rodeo()
        if not pares:
            break
        hechos = 0
        for recta, u, v in pares:
            if u not in g.nodos or v not in g.nodos:
                continue
            if distancias_acotadas(u, tope_rodeo(recta)).get(v, 1e18) <= tope_rodeo(recta):
                continue                    # ya lo resolvió otro puente
            if puente_por_mascara({u}, {v}, "rodeo", max_m=tope_rodeo(recta)):
                hechos += 1
        rodeos_total += hechos
        log(f"rodeos, ronda {ronda}: {len(pares)} pares cercanos con rodeo, {hechos} unidos por la máscara")
        if not hechos:
            if pares:
                log(f"  quedan {len(pares)} pares sin unión posible (obstáculo real en la máscara)")
            break

    # ---- 7. poda de nodos de malla no alcanzables o sin aristas ----
    alc = g.alcanzables(raiz)
    for n in [n for n in g.nodos if not n.startswith("n_") and (n not in alc or g.grado(n) == 0)]:
        g.quitar_nodo(n)

    # ---- 8. colapso de nodos de malla colineales (grado 2) ----
    colapsados = 0
    cambio = True
    while cambio:
        cambio = False
        for n in list(g.nodos):
            if n.startswith("n_") or n.startswith("m") or g.grado(n) != 2:
                continue
            k1, k2 = [k for k in g.aristas if n in k]
            if k1 in g.manuales or k2 in g.manuales or g.aristas[k1] != g.aristas[k2]:
                continue
            a = next(x for x in k1 if x != n)
            b = next(x for x in k2 if x != n)
            if a == b or frozenset((a, b)) in g.aristas:
                continue
            if dist_punto_seg(g.nodos[n], g.nodos[a], g.nodos[b]) < COLINEAL_M * geo.px_por_m \
                    and geo.m(g.nodos[a], g.nodos[b]) <= 2.6 * PASO_M \
                    and mask.seg_dentro(g.nodos[a], g.nodos[b]):
                tipo = g.aristas[k1]
                g.quitar_nodo(n)
                g.arista(a, b, tipo)
                colapsados += 1
                cambio = True

    # ---- 9. validación ----
    cruces, fuera = [], []
    for k, tipo in g.aristas.items():
        if k in g.manuales:
            continue                        # decisiones explícitas (pasajes, escalinatas)
        a, b = tuple(k)
        pa, pb = g.nodos[a], g.nodos[b]
        salto_puerta = geo.m(pa, pb) <= 15  # el conector puede tocar su propio edificio
        for lid, poly in polys.items():
            if lid not in obst:
                continue
            if salto_puerta and f"n_{lid}" in (a, b):
                continue
            if cruza_crudo(pa, pb, poly):
                cruces.append((a, b, lid))
        if k not in g.manuales and not a.startswith("n_") and not b.startswith("n_") \
                and not mask.seg_dentro(pa, pb):
            fuera.append((a, b))
    alc = g.alcanzables(raiz)
    faltan = [n for n in g.nodos if n.startswith("n_") and n not in alc]
    hojas = [n for n in g.nodos if n.startswith("n_") and g.grado(n) <= 1]
    larga_k = max(g.aristas, key=lambda k: geo.m(*(g.nodos[x] for x in k)))
    mas_larga = geo.m(*(g.nodos[x] for x in larga_k))

    # ---- 10. escribir ----
    nodos_out = []
    for nid, xy in sorted(g.nodos.items(), key=lambda t: (t[0].startswith("n_"), t[0])):
        lat, lng = geo.a_ll(*xy)
        o = {"id": nid, "punto": {"lat": lat, "lng": lng}}
        if nid in g.lugar_de:
            o["lugarId"] = g.lugar_de[nid]
        nodos_out.append(o)
    aristas_out = []
    for k, t in g.aristas.items():
        a, b = sorted(k)
        o = {"a": a, "b": b}
        if t != "exterior":
            o["tipo"] = t
        aristas_out.append(o)
    aristas_out.sort(key=lambda o: (o["a"], o["b"]))
    destino = RAIZ / "rutas.preview.json" if dry else SEED / "rutas.json"
    texto = json.dumps({"nodos": nodos_out, "aristas": aristas_out}, separators=(",", ":"), ensure_ascii=False)
    destino.write_text(texto + "\n")

    log(f"nodos: {len(nodos_out)} ({sum(1 for n in nodos_out if 'lugarId' in n)} conectores) | "
        f"aristas: {len(aristas_out)} | colapsados: {colapsados}")
    log("tipos:", dict(Counter(o.get("tipo", "exterior") for o in aristas_out)))
    log(f"arista más larga: {mas_larga:.1f} m {tuple(sorted(larga_k))} | tamaño: {len(texto) // 1024} KB")
    log(f"aristas que cruzan un edificio: {len(cruces)}")
    for a, b, lid in cruces[:12]:
        log(f"  CRUCE {a} - {b} sobre {lid} ({geo.m(g.nodos[a], g.nodos[b]):.0f} m)")
    log(f"aristas de camino fuera de la máscara: {len(fuera)}")
    log(f"lugares sin conexión al acceso principal: {faltan}")
    log(f"lugares con una sola conexión: {hojas}")
    log(f"-> {destino.relative_to(RAIZ)}")
    dibujar_debug(g, mask, geo, lugares)
    if cruces or fuera or faltan:
        sys.exit(1)


def dibujar_debug(g: Grafo, mask: Mascara, geo: Geo, lugares):
    """scripts/datos/grafo_debug.png: máscara, malla, conectores, puentes y
    tramos manuales sobre el plano, para revisar a ojo."""
    from PIL import ImageDraw, ImageFont
    fuente = DATOS / "plano_campus_fuente.jpeg"
    if not fuente.exists():
        return
    im = Image.open(fuente).convert("RGB").resize((mask.w, mask.h))
    a = np.asarray(im).copy()
    a[mask.m] = (a[mask.m] * 0.45 + np.array([0, 200, 255]) * 0.55).astype(np.uint8)
    im = Image.fromarray(a)
    d = ImageDraw.Draw(im)
    # polígonos tal como los ve el grafo (para detectar desalineación)
    for l in lugares:
        if l.get("poligono") and len(l["poligono"]) >= 3:
            pts = [geo.a_px(p["lat"], p["lng"]) for p in l["poligono"]]
            d.polygon(pts, outline=(0, 120, 0) if l.get("transitable") else (200, 0, 0), width=2)
    color = {"exterior": (90, 90, 90), "pasillo": (0, 60, 255), "escalera": (220, 0, 0), "rampa": (0, 160, 0)}
    for k, t in g.aristas.items():
        x, y = tuple(k)
        pa, pb = g.nodos[x], g.nodos[y]
        if k in g.puentes:
            d.line([pa, pb], fill=(255, 0, 200), width=4)
        elif k in g.manuales:
            d.line([pa, pb], fill=(255, 140, 0), width=4)
        else:
            d.line([pa, pb], fill=color.get(t, (90, 90, 90)), width=1 if t == "exterior" else 2)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
    claves = {l["id"]: l.get("clave") or l["id"][4:12] for l in lugares}
    for nid, (x, y) in g.nodos.items():
        if nid.startswith("n_"):
            d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(255, 100, 0), outline=(0, 0, 0))
            d.text((x + 6, y - 8), claves.get(g.lugar_de[nid], "?"), fill=(0, 0, 160), font=font)
    im.save(DATOS / "grafo_debug.png")
    log(f"-> {(DATOS / 'grafo_debug.png').relative_to(RAIZ)} (magenta = puente recto, naranja = tramo manual)")


if __name__ == "__main__":
    main()

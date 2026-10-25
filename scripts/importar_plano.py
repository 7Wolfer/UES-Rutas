#!/usr/bin/env python3
"""Importa el plano arquitectónico oficial del plantel Hermosillo.

Del plano de conjunto (raster, entregado por la UES) obtiene:

  1. assets/seed/lugares.json        contornos y nomenclatura oficial (A–V, S1, 1–13)
  2. assets/seed/campus.json         campo deportivo + esquinas de la vista "Plano"
  3. scripts/datos/plano_caminable.png  máscara de por dónde se camina (andadores,
                                        explanada, estacionamientos) → generar_grafo.py
  4. assets/plano/plano_campus.webp  el plano recortado, para la vista "Plano" del mapa
  5. scripts/datos/plano_debug.png   contornos + claves sobre el raster, para revisar

Georreferenciación: transformación afín píxel → (lng, lat) ajustada por mínimos
cuadrados con pares de control (scripts/datos/plano_georef.json). Los pares se
congelan en la primera corrida; edítalos (p. ej. con esquinas medidas en sitio) y
corre con --recalibrar.

Uso:
    python3 scripts/importar_plano.py                # regenera todo
    python3 scripts/importar_plano.py --verificar    # solo reporta, no escribe
    python3 scripts/importar_plano.py --pdf ruta.pdf # extrae el JPEG de otro PDF
    python3 scripts/importar_plano.py --recalibrar   # reajusta la afín con los pares

Requiere: numpy, Pillow (y pymupdf solo si se usa --pdf).
"""
from __future__ import annotations

import json
import math
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
SEED = RAIZ / "assets" / "seed"
DATOS = Path(__file__).resolve().parent / "datos"
FUENTE = DATOS / "plano_campus_fuente.jpeg"
GEOREF = DATOS / "plano_georef.json"
CAMINABLE = DATOS / "plano_caminable.png"
DEBUG = DATOS / "plano_debug.png"
PLANO_APP = RAIZ / "assets" / "plano" / "plano_campus.webp"
PDF_DEFAULT = (Path.home() / "Documents" / "UES" / "Recursos"
               / "Unidad Académica Hermosillo- colores reorganizada-m.pdf")

# ---------------------------------------------------------------- región útil
# Coordenadas en píxeles del raster original (3232 × 2094).
UTIL = (40, 40, 2690, 2050)          # x0, y0, x1, y1
UPN = (0, 1370, 2020, 2094)          # bloque de la UPN (blanco, no es campus)
LEYENDA_X = 2600                     # a la derecha está la simbología
RECORTE_PLANO = (40, 40, 2690, 2050) # lo que se muestra en la vista "Plano"

# ---------------------------------------------------------------- etiquetas
# Centroide (px) de cada componente del plano → clave oficial. Etiquetado por
# cercanía, así sobrevive a cambios de orden en la segmentación.
ETIQUETAS_PX = {
    "S1": (512, 112), "S": (512, 206), "T": (876, 241), "R": (1414, 226),
    "V": (1675, 247), "I": (1862, 255), "P": (2121, 298), "E": (1666, 440),
    "1": (1794, 444), "D": (1795, 530), "D2": (1757, 711), "Q": (1985, 570),
    "J": (2338, 488), "13": (2453, 595), "K": (2103, 637), "G": (2198, 735),
    "F": (2140, 842), "M": (1295, 719), "L": (1508, 883), "2": (1273, 934),
    "B": (1506, 1022), "H": (2458, 1086), "N": (1790, 1139), "A": (1453, 1171),
    "C": (2056, 1173), "O": (2222, 1170), "3": (2226, 1651), "3b": (2304, 1652),
}
TOLERANCIA_PX = 70
FUSIONES = {"D2": "D", "3b": "3"}     # componentes que forman un solo lugar
VENTANA_E = (1600, 380, 1740, 500)   # E es pequeño; se busca aparte si falta
VENTANA_4 = (1600, 760, 1900, 1000)  # explanada (naranja)
VENTANA_6 = (1900, 380, 2300, 720)   # pétalos del domo
PUNTO_12 = (2520, 482)               # oficina de seguridad (SEGUES), sobre el lote oriente
# Los accesos van justo DENTRO del campus, sobre el andador/vialidad, para que
# el grafo los enganche por la máscara y no por saltos sin verificar.
PUNTO_ACCESO_PRINCIPAL = (1790, 1246)
PUNTO_ACCESO_PONIENTE = (1100, 1090)
PUNTO_ACCESO_ORIENTE = (2526, 890)

# Estacionamientos (componentes grises grandes) → id por centroide.
LOTES_PX = {
    "lug_estacionamiento_1": ((1462, 481), "Estacionamiento Norte"),
    "lug_estacionamiento_2": ((957, 737), "Estacionamiento Poniente"),
    "lug_estacionamiento_3": ((2335, 941), "Estacionamiento Oriente"),
    "lug_estacionamiento_4": ((2283, 1668), "Estacionamiento del Gimnasio"),
}
LOTE_MIN_PX = 20_000

# Parches sobre la máscara caminable (px del raster original), aplicados al
# final (mandan sobre todo lo demás):
#  - el pin rojo "Usted está aquí" tapa parte del estacionamiento junto a M;
#  - la entrada principal: plaza semicircular frente a N + escalinata/rampa
#    hasta la reja (en el plano van en blanco rayado, no como andador).
PARCHES_CAMINABLES_PX = [(1280, 530, 1375, 720), (1690, 1183, 1890, 1296)]
PARCHES_BLOQUEO_PX: list[tuple[int, int, int, int]] = []
# Recortes a polígonos de edificios: la plaza semicircular frente a N es blanca
# y se pega al edificio; se quita para que no cuente como obstáculo.
RECORTES_POLIGONO_PX = {"N": (1690, 1183, 1890, 1220)}

# ---------------------------------------------------------------- catálogo
# clave → (id, nombre, nombreCorto, categoria, descripcion, transitable, accesible)
CATALOGO = {
    "A": ("lug_edificio_a", "Edificio A", "A", "edificio",
          "Aulas, laboratorios, cubículos y sanitarios (baños).", False, True),
    "B": ("lug_edificio_b", "Edificio B", "B", "edificio",
          "Aulas y laboratorio.", False, True),
    "C": ("lug_edificio_c", "Oficinas Divisionales (C)", "C", "oficina",
          "Edificio C: oficinas divisionales.", False, True),
    "D": ("lug_edificio_d", "Edificio D", "D", "edificio",
          "Aulas, laboratorios, cubículos, oficinas administrativas y "
          "sanitarios (baños).", False, True),
    "E": ("lug_edificio_e", "Edificio E", "E", "edificio", "Aulas.", False, True),
    "F": ("lug_edificio_f", "Edificio F", "F", "edificio",
          "Jefaturas de Ing. Biomédica, Lic. en Ecología, Ing. Ambiental, Lic. en "
          "Administración de Empresas y Lic. en Empresas Turísticas; laboratorios y "
          "cubículos.", False, True),
    "G": ("lug_edificio_g", "Edificio G", "G", "edificio",
          "Aulas y sanitarios (baños).", False, True),
    "H": ("lug_edificio_h", "Edificio H", "H", "edificio",
          "Aulas, cubículos y sanitarios (baños).", False, True),
    "I": ("lug_edificio_i", "Edificio I", "I", "edificio",
          "Cubículos, tutorías y sanitarios (baños).", False, True),
    "J": ("lug_edificio_j", "Edificio J · Centro de Idiomas", "J", "edificio",
          "Aulas, Centro de Idiomas, aula magna y aula de autoacceso.", False, True),
    "K": ("lug_edificio_k_laboratorios_turismo", "Edificio K · Laboratorio de Turismo",
          "K", "edificio", "Laboratorio de turismo y aulas.", False, True),
    "L": ("lug_laboratorios_centrales", "Laboratorios Centrales (L)", "L",
          "laboratorio", "Edificio L: laboratorios centrales.", False, True),
    "M": ("lug_control_escolar_ues", "Control Escolar (M)", "M", "oficina",
          "Edificio M: Control Escolar. Trámites escolares e inscripciones.",
          False, True),
    "N": ("lug_edificio_n", "Edificio N", "N", "edificio",
          "Laboratorios, aulas y jefaturas de Enseñanza del Inglés, Ing. "
          "Mecatrónica, Ing. Industrial y de Manufactura, Ing. de Software e Ing. "
          "en Automatización de Procesos; área de vinculación.", False, True),
    "O": ("lug_centro_de_computo", "Centro de Cómputo (O)", "O", "edificio",
          "Edificio O: centro de cómputo.", False, True),
    "P": ("lug_aula_magna_biblioteca", "Biblioteca / Aula Magna (P)", "P",
          "biblioteca", "Edificio P: biblioteca, aula magna, cubículos y aula de "
          "autoacceso.", False, True),
    "Q": ("lug_recursos_humanos", "Recursos Humanos (Q)", "Q", "oficina",
          "Edificio Q: Recursos Humanos.", False, True),
    "R": ("lug_edificio_r", "Edificio R", "R", "edificio",
          "Almacén, sindicato, deportes, música y archivo.", False, True),
    "S": ("lug_taller_de_ecoprocesos", "Taller de Ecoprocesos (S)", "S",
          "laboratorio", "Edificio S: taller de ecoprocesos.", False, True),
    "S1": ("lug_edificio_s1", "Lab. de Electrónica e Instrumentación (S1)", "S1",
           "laboratorio", "Edificio S1: laboratorio de electrónica e "
           "instrumentación; almacén.", False, True),
    "T": ("lug_ciencias_de_la_salud", "Ciencias de la Salud (T)", "T", "edificio",
          "Edificio T: jefaturas de Lic. en Nutrición Humana, Lic. en Fisioterapia, "
          "Ing. en Tecnología de Alimentos y Lic. en Enfermería; aulas, sala de "
          "maestros, laboratorio de alimentos y laboratorio de ciencias.",
          False, True),
    "V": ("lug_edificio_v", "Edificio V", "V", "edificio", "Edificio de aulas.",
          False, True),
    "1": ("lug_cafeteria_ues", "Cafetería", "1", "alimentos",
          "Cafetería del plantel.", False, True),
    "2": ("lug_invernadero", "Invernadero", "2", "servicios", "Invernadero.",
          False, True),
    "3": ("lug_gimnasio_ues", "Gimnasio", "3", "deportivo",
          "Gimnasio de la UES (frente al plantel, cruzando la calle).", False, True),
    "4": ("lug_explanada_estudiantil", "Explanada", "4", "servicios",
          "Explanada y área de esparcimiento estudiantil.", True, True),
    "6": ("lug_domo_ues", "Domo · Plaza-Auditorio", "6", "deportivo",
          "Plaza-auditorio cubierta (el Domo): eventos y actividades.", False, True),
    "12": ("lug_seguridad_segues", "Seguridad (SEGUES)", "12", "oficina",
           "Oficina de seguridad universitaria.", False, True),
    "13": ("lug_archivo_documental", "Archivo Documental", "13", "oficina",
           "Archivo documental.", False, True),
}
ORDEN_CLAVES = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
                "N", "O", "P", "Q", "R", "S", "S1", "T", "V",
                "1", "2", "3", "4", "6", "12", "13"]
SOLO_PUNTO = {"12"}  # claves sin polígono

# Pares de control iniciales: centroide en px del plano ↔ centroide (lat, lng)
# del mismo edificio en OpenStreetMap (catálogo anterior). Se congelan en
# plano_georef.json; ahí se pueden sustituir por mediciones en sitio.
CONTROLES_INICIALES = [
    ("S", (512, 206), 29.122171, -110.964046),
    ("T", (876, 241), 29.122197, -110.963502),
    ("R", (1414, 226), 29.122330, -110.962691),
    ("I", (1862, 255), 29.122403, -110.961960),
    ("P", (2121, 298), 29.122380, -110.961496),
    ("1", (1794, 444), 29.122099, -110.961991),
    ("Q", (1985, 570), 29.122083, -110.961736),
    ("K", (2103, 637), 29.121906, -110.961554),
    ("G", (2198, 735), 29.121804, -110.961309),
    ("F", (2140, 842), 29.121632, -110.961349),
    ("L", (1508, 883), 29.121440, -110.962438),
    ("2", (1273, 934), 29.121347, -110.962767),
    ("B", (1506, 1022), 29.121230, -110.962430),
    ("N", (1790, 1139), 29.121126, -110.961840),
    ("A", (1453, 1171), 29.120999, -110.962374),
    ("O", (2222, 1170), 29.121196, -110.961157),
    ("M", (1295, 719), 29.121627, -110.962785),
    ("3", (2266, 1652), 29.120463, -110.961100),
]

LAT0 = 29.1214
M_POR_GRADO_LNG = 111_320.0 * math.cos(math.radians(LAT0))
M_POR_GRADO_LAT = 110_540.0


# ================================================================ utilidades
def log(*a):
    print(*a, flush=True)


def extraer_jpeg_del_pdf(pdf: Path) -> Path:
    import fitz  # pymupdf
    doc = fitz.open(pdf)
    page = doc[0]
    mejor = None
    for im in page.get_images(full=True):
        info = doc.extract_image(im[0])
        if mejor is None or len(info["image"]) > len(mejor["image"]):
            mejor = info
    if mejor is None:
        raise SystemExit(f"El PDF no tiene imágenes: {pdf}")
    FUENTE.parent.mkdir(parents=True, exist_ok=True)
    FUENTE.write_bytes(mejor["image"])
    log(f"JPEG extraído: {FUENTE.name} ({mejor['width']}x{mejor['height']})")
    return FUENTE


class Georef:
    """Afín px → (lng, lat)."""

    def __init__(self, px, py):
        self.px, self.py = px, py

    @classmethod
    def ajustar(cls, controles):
        A = np.array([[x, y, 1.0] for _, (x, y), _, _ in controles])
        px, *_ = np.linalg.lstsq(A, np.array([c[3] for c in controles]), rcond=None)
        py, *_ = np.linalg.lstsq(A, np.array([c[2] for c in controles]), rcond=None)
        return cls(px.tolist(), py.tolist())

    def a_ll(self, x, y):
        lng = self.px[0] * x + self.px[1] * y + self.px[2]
        lat = self.py[0] * x + self.py[1] * y + self.py[2]
        return round(lat, 6), round(lng, 6)

    def a_px(self, lat, lng):
        a, b, c = self.px
        d, e, f = self.py
        det = a * e - b * d
        u, v = lng - c, lat - f
        return ((e * u - b * v) / det, (-d * u + a * v) / det)

    def residuos_m(self, controles):
        out = []
        for clave, (x, y), lat, lng in controles:
            plat, plng = self.a_ll(x, y)
            out.append((clave, math.hypot((plng - lng) * M_POR_GRADO_LNG,
                                          (plat - lat) * M_POR_GRADO_LAT)))
        return out

    def escala_px_m(self):
        sx = math.hypot(self.px[0] * M_POR_GRADO_LNG, self.py[0] * M_POR_GRADO_LAT)
        return 1 / sx


def cargar_georef(recalibrar: bool) -> tuple[Georef, list]:
    if GEOREF.exists() and not recalibrar:
        d = json.loads(GEOREF.read_text())
        ctrl = [(c["clave"], tuple(c["px"]), c["lat"], c["lng"]) for c in d["controles"]]
        return Georef(d["px"], d["py"]), ctrl
    if GEOREF.exists():
        d = json.loads(GEOREF.read_text())
        ctrl = [(c["clave"], tuple(c["px"]), c["lat"], c["lng"]) for c in d["controles"]]
    else:
        ctrl = list(CONTROLES_INICIALES)
    g = Georef.ajustar(ctrl)
    res = g.residuos_m(ctrl)
    rms = math.sqrt(sum(r * r for _, r in res) / len(res))
    GEOREF.parent.mkdir(parents=True, exist_ok=True)
    GEOREF.write_text(json.dumps({
        "descripcion": "Afín píxel(plano) -> (lng, lat). lng = px·[x,y,1]; lat = py·[x,y,1].",
        "px": g.px, "py": g.py, "rms_m": round(rms, 2),
        "escala_px_por_m": round(g.escala_px_m(), 3),
        "controles": [{"clave": c, "px": list(p), "lat": la, "lng": lo} for c, p, la, lo in ctrl],
    }, indent=1, ensure_ascii=False) + "\n")
    log(f"georef ajustada: RMS {rms:.1f} m, {g.escala_px_m():.2f} px/m -> {GEOREF.name}")
    return g, ctrl


# --- morfología y componentes (numpy puro) ---
def dilatar(m, r):
    o = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dy or dx:
                o |= np.roll(np.roll(m, dy, 0), dx, 1)
    return o


def erosionar(m, r):
    return ~dilatar(~m, r)


def componentes(mask, s=2, min_px=0):
    """Componentes 4-conexos (submuestreo s). Devuelve (etiquetas, lista)."""
    m = mask[::s, ::s]
    h, w = m.shape
    lab = np.zeros((h, w), np.int32)
    out = []
    k = 0
    for y in range(h):
        for x in range(w):
            if m[y, x] and lab[y, x] == 0:
                k += 1                      # etiqueta única aunque se descarte
                lab[y, x] = k
                q = deque([(y, x)])
                n = 0
                sy = sx = 0
                miny = maxy = y
                minx = maxx = x
                while q:
                    cy, cx = q.popleft()
                    n += 1
                    sy += cy
                    sx += cx
                    miny, maxy = min(miny, cy), max(maxy, cy)
                    minx, maxx = min(minx, cx), max(maxx, cx)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = k
                            q.append((ny, nx))
                if n * s * s >= min_px:
                    out.append(dict(k=k, area=n * s * s,
                                    box=(minx * s, miny * s, maxx * s, maxy * s),
                                    c=(sx / n * s, sy / n * s)))
    return lab, out


def contorno(mask, s, eps_px=6.0):
    """Contorno exterior de una máscara (submuestreada s) en px originales.

    Trazado de vecindad de Moore con criterio de paro de Jacob: sigue solo el
    borde exterior, así que los huecos interiores (camellones, cajones) no
    importan. Luego se simplifica con Douglas-Peucker.
    """
    ys, xs = np.where(mask)
    if len(ys) == 0:
        return []
    H, W = mask.shape
    i = int(np.argmin(ys * W + xs))          # primer píxel en orden de barrido
    start = (int(xs[i]), int(ys[i]))
    # vecindad en sentido horario empezando por el oeste
    nb = [(-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1)]

    def dentro(p):
        x, y = p
        return 0 <= x < W and 0 <= y < H and bool(mask[y, x])

    contour = [start]
    b = start
    back = (start[0] - 1, start[1])           # el oeste del inicio es fondo
    first_next = None
    tope = 8 * (W + H) * 4
    for _ in range(tope):
        k = nb.index((back[0] - b[0], back[1] - b[1]))
        nxt = None
        prev = back
        for j in range(1, 9):
            cand_off = nb[(k + j) % 8]
            p = (b[0] + cand_off[0], b[1] + cand_off[1])
            if dentro(p):
                nxt = p
                break
            prev = p
        if nxt is None:
            break                                  # píxel aislado
        if b == start and first_next is None:
            first_next = nxt
        elif b == start and nxt == first_next and len(contour) > 2:
            break                                  # criterio de Jacob
        contour.append(nxt)
        back = prev
        b = nxt
    pts = [(x * s, y * s) for x, y in contour]
    return douglas_peucker(pts, eps_px)


def douglas_peucker(pts, eps):
    if len(pts) < 3:
        return pts

    def d(p, a, b):
        ax, ay = a
        bx, by = b
        x, y = p
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy
        if L2 == 0:
            return math.hypot(x - ax, y - ay)
        t = max(0.0, min(1.0, ((x - ax) * dx + (y - ay) * dy) / L2))
        return math.hypot(x - (ax + t * dx), y - (ay + t * dy))

    a, b = pts[0], pts[-1]
    i, mx = max(((i, d(p, a, b)) for i, p in enumerate(pts[1:-1], 1)), key=lambda t: t[1])
    if mx > eps:
        return douglas_peucker(pts[:i + 1], eps)[:-1] + douglas_peucker(pts[i:], eps)
    return [a, b]


def casco_convexo(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def punto_interior(mask, s):
    """Píxel más interior (erosión iterativa), en px originales."""
    m = mask.copy()
    while True:
        e = erosionar(m, 1)
        if e.sum() < 12:
            break
        m = e
    ys, xs = np.where(m)
    return (float(xs.mean() * s), float(ys.mean() * s))


def caja(mask_full, x0, y0, x1, y1):
    w = np.zeros_like(mask_full)
    w[y0:y1, x0:x1] = True
    return mask_full & w


# ================================================================ principal
def main():
    args = sys.argv[1:]
    verificar = "--verificar" in args
    recalibrar = "--recalibrar" in args
    if "--pdf" in args:
        pdf = Path(args[args.index("--pdf") + 1]).expanduser()
        extraer_jpeg_del_pdf(pdf)
    elif not FUENTE.exists():
        if PDF_DEFAULT.exists():
            extraer_jpeg_del_pdf(PDF_DEFAULT)
        else:
            raise SystemExit(f"Falta {FUENTE} (o pasa --pdf ruta.pdf)")

    geo, controles = cargar_georef(recalibrar)
    res = geo.residuos_m(controles)
    rms = math.sqrt(sum(r * r for _, r in res) / len(res))
    peor = max(res, key=lambda r: r[1])
    log(f"georef: RMS {rms:.1f} m | peor {peor[0]} {peor[1]:.1f} m | {geo.escala_px_m():.2f} px/m")

    im = Image.open(FUENTE).convert("RGB")
    a = np.asarray(im).astype(int)
    H, W, _ = a.shape
    R, G, B = a[..., 0], a[..., 1], a[..., 2]

    # --- máscaras de color ---
    util = np.zeros((H, W), bool)
    util[UTIL[1]:UTIL[3], UTIL[0]:UTIL[2]] = True
    util[UPN[1]:UPN[3], UPN[0]:UPN[2]] = False
    util[:, LEYENDA_X:] = False
    blanco = (R > 225) & (G > 225) & (B > 225) & util
    maroon = (abs(R - 80) < 30) & (abs(G - 48) < 26) & (abs(B - 48) < 26) & (R > G + 12) & util
    gris = (abs(R - G) < 8) & (abs(G - B) < 8) & (R > 105) & (R < 150) & util
    verde = (G > R + 20) & (G > B + 30) & (G > 100) & util
    tan = (R > 170) & (G > 100) & (G < 170) & (B < 110) & (R > G + 40) & util
    petalo = (R > 150) & (G > 90) & (B < 120) & (R > B + 60) & (abs(R - G) < 110) & util
    # vialidades internas (beige): caminables, pero solo dentro del perímetro
    # del campus para no salirse a las calles.
    beige = (abs(R - 160) < 25) & (abs(G - 144) < 25) & (abs(B - 128) < 25) & (R > B + 10) & util
    campus_json = json.loads((SEED / "campus.json").read_text())
    per_px = [geo.a_px(p["lat"], p["lng"]) for p in campus_json["perimetro"]]
    per_img = Image.new("1", (W, H), 0)
    ImageDraw.Draw(per_img).polygon([(x, y) for x, y in per_px], fill=1)
    dentro_perimetro = np.asarray(per_img, dtype=bool)
    beige &= dentro_perimetro
    # sombras de los edificios (gris oscuro): caen sobre el andador contiguo;
    # se cuentan como caminables (los edificios se restan después de todos modos)
    sombra = (abs(R - G) < 10) & (abs(G - B) < 10) & (R >= 55) & (R <= 100) & dentro_perimetro
    S = 2
    # Superficies casi negras y anchas: la plaza semicircular frente a N y los
    # andadores en sombra (ambos ~(25–45, 16–45, 17–45)) también se caminan.
    # Se exige grosor (sobreviven a una erosión de ~1 m) para no tomar por
    # piso los contornos negros ni las letras del plano.
    oscuro = (R < 55) & (G < 55) & (B < 55) & dentro_perimetro
    oscuro = np.kron(dilatar(erosionar(oscuro[::S, ::S], 3), 3), np.ones((S, S), bool))[:H, :W]

    # --- 1. edificios: componentes blancos etiquetados por centroide ---
    labB, comps = componentes(blanco, S)

    def es_edificio(c):
        x0, y0, x1, y1 = c["box"]
        bw, bh = x1 - x0, y1 - y0
        return (1500 <= c["area"] <= 260_000 and bw >= 40 and bh >= 30
                and bw <= 900 and bh <= 700 and c["area"] / (bw * bh) >= 0.35)

    por_clave: dict[str, list[dict]] = {}
    sin_etiqueta = []
    # Blanco sin letra dentro del perímetro = plazas, banquetas y vialidades
    # (caminables). Se excluyen cajas pequeñas macizas (subestaciones) y la
    # escalinata F–H (va como tramo manual con tipo "escalera").
    blanco_caminable = np.zeros((H, W), bool)
    for c in comps:
        if not es_edificio(c):
            continue
        clave, dist = None, 1e9
        for k, (ex, ey) in ETIQUETAS_PX.items():
            d = math.hypot(c["c"][0] - ex, c["c"][1] - ey)
            if d < dist:
                clave, dist = k, d
        if dist > TOLERANCIA_PX:
            sin_etiqueta.append(c)
            x0, y0, x1, y1 = c["box"]
            cx, cy = c["c"]
            es_escalinata = 2150 < cx < 2320 and 860 < cy < 950
            esquina_oxxo = cx < 1080 and cy > 1120
            if c["area"] >= 2500 and not es_escalinata and not esquina_oxxo \
                    and dentro_perimetro[int(cy), int(cx)]:
                blanco_caminable |= np.kron(labB == c["k"], np.ones((S, S), bool))[:H, :W]
            continue
        por_clave.setdefault(FUSIONES.get(clave, clave), []).append(c)

    # E por ventana si no salió
    if "E" not in por_clave:
        _, ce = componentes(caja(blanco, *VENTANA_E), S)
        ce = [c for c in ce if c["area"] > 1200]
        if ce:
            por_clave["E"] = [max(ce, key=lambda c: c["area"])]
            # su etiqueta viene de otra segmentación: guardar la máscara aparte
            por_clave["E"][0]["_mask"] = caja(blanco, *VENTANA_E)[::S, ::S]
    # 4: explanada (tan) por ventana
    lab4, c4 = componentes(caja(tan, *VENTANA_4), S)
    if c4:
        c4m = max(c4, key=lambda c: c["area"])
        c4m["_mask"] = lab4 == c4m["k"]
        por_clave["4"] = [c4m]
    # 6: casco convexo de los pétalos
    lab6, c6 = componentes(caja(petalo, *VENTANA_6), S, min_px=1200)
    if c6:
        m6 = np.zeros_like(lab6, bool)
        for c in c6:
            m6 |= lab6 == c["k"]
        ys, xs = np.where(m6)
        hull = casco_convexo(list(zip((xs * S).tolist(), (ys * S).tolist())))
        hull = douglas_peucker(hull + [hull[0]], 5.0)[:-1]
        por_clave["6"] = [dict(area=int(m6.sum()) * S * S, _hull=hull,
                               _mask=dilatar(m6, 1), c=(xs.mean() * S, ys.mean() * S))]

    faltan = [k for k in ORDEN_CLAVES if k not in por_clave and k not in SOLO_PUNTO]
    log(f"edificios etiquetados: {len(por_clave)} | sin etiqueta (ignorados): "
        f"{len(sin_etiqueta)} | faltan: {faltan or 'ninguno'}")

    # --- 2. estacionamientos y campo ---
    # r=5 separa bien los cuatro lotes; el suavizado fuerte se hace después,
    # lote por lote, para que no se fusionen entre sí por la vialidad.
    gris_c = erosionar(dilatar(gris, 5), 5)
    labG, lotes = componentes(gris_c, S, min_px=LOTE_MIN_PX)
    lotes_por_id = {}
    for c in lotes:
        mejor, dist = None, 1e9
        for lid, ((ex, ey), _) in LOTES_PX.items():
            d = math.hypot(c["c"][0] - ex, c["c"][1] - ey)
            if d < dist:
                mejor, dist = lid, d
        if dist < 250 and mejor not in lotes_por_id:
            c["_mask"] = erosionar(dilatar(labG == c["k"], 4), 4)  # tapa cajones
            lotes_por_id[mejor] = c
    labV, verdes = componentes(erosionar(dilatar(verde, 3), 3), S, min_px=60_000)
    campo = max(verdes, key=lambda c: c["area"]) if verdes else None
    if campo:
        campo["_mask"] = labV == campo["k"]
    log(f"estacionamientos: {len(lotes_por_id)}/{len(LOTES_PX)} | campo deportivo: "
        f"{'ok' if campo else 'NO'}")

    # --- 3. polígonos en lat/lng ---
    def mascara_de(clave):
        cs = por_clave[clave]
        if "_mask" in cs[0]:
            return cs[0]["_mask"]
        m = np.zeros_like(labB, bool)
        for c in cs:
            m |= labB == c["k"]
        if len(cs) > 1:                # D y 3 vienen en piezas separadas por una línea
            m = dilatar(m, 3)
        if clave in RECORTES_POLIGONO_PX:
            x0, y0, x1, y1 = RECORTES_POLIGONO_PX[clave]
            m[y0 // S:y1 // S, x0 // S:x1 // S] = False
        return m

    lugares = []
    poligonos_px = {}
    for clave in ORDEN_CLAVES:
        lid, nombre, corto, cat, desc, transitable, accesible = CATALOGO[clave]
        if clave in SOLO_PUNTO:
            px = PUNTO_12
            lat, lng = geo.a_ll(*px)
            lugares.append(dict(id=lid, nombre=nombre, nombreCorto=corto, clave=clave,
                                categoria=cat, punto=dict(lat=lat, lng=lng),
                                accesible=accesible, descripcion=desc))
            continue
        if clave not in por_clave:
            continue
        m = mascara_de(clave)
        if "_hull" in por_clave[clave][0]:
            pts = por_clave[clave][0]["_hull"]
        else:
            pts = contorno(m, S)
        pi = punto_interior(m, S)
        poligonos_px[clave] = pts
        lat, lng = geo.a_ll(*pi)
        poly = [dict(lat=la, lng=lo) for la, lo in (geo.a_ll(x, y) for x, y in pts)]
        if poly and poly[0] != poly[-1]:
            poly.append(poly[0])
        lugares.append(dict(id=lid, nombre=nombre, nombreCorto=corto, clave=clave,
                            categoria=cat, punto=dict(lat=lat, lng=lng),
                            accesible=accesible, descripcion=desc,
                            transitable=transitable, poligono=poly))

    for lid, ((_, _), nombre) in LOTES_PX.items():
        c = lotes_por_id.get(lid)
        if not c:
            continue
        pts = contorno(c["_mask"], S, eps_px=14.0)   # ≈ 2 m: sin dientes de sierra
        if len(pts) < 3:
            log(f"   aviso: contorno vacío para {lid} ({len(pts)} pts); se omite el lote")
            continue
        poligonos_px[lid] = pts
        lat, lng = geo.a_ll(*punto_interior(c["_mask"], S))
        poly = [dict(lat=la, lng=lo) for la, lo in (geo.a_ll(x, y) for x, y in pts)]
        poly.append(poly[0])
        lugares.append(dict(id=lid, nombre=nombre, categoria="estacionamiento",
                            punto=dict(lat=lat, lng=lng), accesible=True,
                            descripcion="Estacionamiento.", transitable=True,
                            poligono=poly))
    campo_poly = None
    if campo and len(contorno(campo["_mask"], S, eps_px=8.0)) < 3:
        log("   aviso: contorno vacío para el campo deportivo; se omite")
        campo = None
    if campo:
        pts = contorno(campo["_mask"], S, eps_px=8.0)
        poligonos_px["campo"] = pts
        campo_poly = [dict(lat=la, lng=lo) for la, lo in (geo.a_ll(x, y) for x, y in pts)]
        campo_poly.append(campo_poly[0])
        lat, lng = geo.a_ll(*punto_interior(campo["_mask"], S))
        lugares.append(dict(id="lug_campo_deportivo", nombre="Campo Deportivo",
                            categoria="deportivo", punto=dict(lat=lat, lng=lng),
                            accesible=True, descripcion="Canchas de fútbol.",
                            poligono=campo_poly))
    for lid, nombre, px, acc, desc in (
        ("lug_acceso_principal", "Acceso Principal", PUNTO_ACCESO_PRINCIPAL, True,
         "Entrada principal por Av. Ley Federal del Trabajo."),
        ("lug_acceso_poniente", "Acceso Poniente", PUNTO_ACCESO_PONIENTE, False,
         "Entrada poniente, junto al campo deportivo. Con escalones."),
        ("lug_acceso_oriente", "Acceso Oriente", PUNTO_ACCESO_ORIENTE, True,
         "Entrada oriente por Calle Israel González (plaza de acceso)."),
    ):
        lat, lng = geo.a_ll(*px)
        lugares.append(dict(id=lid, nombre=nombre, categoria="servicios",
                            punto=dict(lat=lat, lng=lng), accesible=acc, descripcion=desc))

    # --- 4. máscara caminable (media resolución) ---
    edif_no_trans = np.zeros_like(labB, bool)
    for clave in ORDEN_CLAVES:
        if clave in por_clave and not CATALOGO[clave][5]:
            edif_no_trans |= mascara_de(clave)
    if campo:
        edif_no_trans |= campo["_mask"]
    lotes_m = np.zeros_like(labB, bool)
    for c in lotes_por_id.values():
        lotes_m |= c["_mask"]
    zona6 = dilatar(por_clave["6"][0]["_mask"], 20) if "6" in por_clave else np.zeros_like(labB, bool)
    # caminable = andadores + explanada + vialidades beige + TODO el pavimento
    # gris dentro del perímetro (no solo los lotes grandes) + blanco sin letra
    walk = (maroon | tan | beige | sombra | oscuro | (gris & dentro_perimetro) | blanco_caminable)[::S, ::S] | lotes_m | zona6
    for x0, y0, x1, y1 in PARCHES_CAMINABLES_PX:      # corrigen el raster (pin, entrada)
        walk[y0 // S:y1 // S, x0 // S:x1 // S] = True
    # cierre amplio (10 px ≈ 3 m): el plano dibuja contornos negros y degradados
    # de sombra de 2–8 px entre lote, andador, plaza y franja en sombra que
    # partirían la máscara en islas o dejarían cuellos que la apertura corta
    walk = erosionar(dilatar(walk, 5), 5)
    walk = dilatar(erosionar(walk, 2), 2)     # apertura: quita pelos
    labW, cw = componentes(walk, 1, min_px=400)
    keep = np.zeros_like(walk)
    for c in cw:
        keep |= labW == c["k"]
    # Los edificios siempre ganan (por encima de cualquier parche). Los
    # polígonos son los muros: basta 0.6 m de holgura; más deja sin andador a
    # los pasillos angostos (3–4 m) entre edificios pegados.
    walk = keep & ~dilatar(edif_no_trans, 2)   # 2 px a media res ≈ 0.6 m
    for x0, y0, x1, y1 in PARCHES_BLOQUEO_PX:
        walk[y0 // S:y1 // S, x0 // S:x1 // S] = False
    walk &= util[::S, ::S]
    labW, cw = componentes(walk, 1, min_px=1)
    log(f"máscara caminable: {len(cw)} regiones; la mayor {max(c['area'] for c in cw)} px")
    log(f"máscara caminable: {int(walk.sum())} px ({int(walk.sum()) * S * S / geo.escala_px_m() ** 2:.0f} m²)")

    # --- 5. vista Plano: recorte y esquinas ---
    x0, y0, x1, y1 = RECORTE_PLANO
    rec = im.crop((x0, y0, x1, y1)).convert("RGBA")
    # El bloque de la UPN y la leyenda no son campus: quedan transparentes para
    # que debajo se vea el mapa base.
    alfa_img = rec.getchannel("A")
    alfa = ImageDraw.Draw(alfa_img)
    alfa.rectangle((UPN[0] - x0, UPN[1] - y0, UPN[2] - x0, UPN[3] - y0), fill=0)
    alfa.rectangle((LEYENDA_X - x0, 0, x1 - x0, y1 - y0), fill=0)
    rec.putalpha(alfa_img)
    rec = rec.resize(((x1 - x0) // 2, (y1 - y0) // 2), Image.LANCZOS)
    tl = geo.a_ll(x0, y0)
    bl = geo.a_ll(x0, y1)
    br = geo.a_ll(x1, y1)

    # --- 6. reporte / verificación ---
    problemas = []
    if rms > 8:
        problemas.append(f"RMS de georreferenciación alto: {rms:.1f} m")
    if faltan:
        problemas.append(f"claves sin componente: {faltan}")
    if len(lotes_por_id) < len(LOTES_PX):
        problemas.append("faltan estacionamientos")
    if not campo:
        problemas.append("no se detectó el campo deportivo")
    ap = next(l for l in lugares if l["id"] == "lug_acceso_principal")["punto"]
    log(f"lugares: {len(lugares)} | acceso principal -> {ap['lat']},{ap['lng']}")
    for clave, pts in poligonos_px.items():
        nombre = CATALOGO[clave][0] if clave in CATALOGO else clave
        log(f"   {clave:22} {nombre:38} {len(pts):2} vértices")

    # --- debug PNG (siempre, es barato) ---
    dbg = im.copy().resize((W // 2, H // 2))
    dd = ImageDraw.Draw(dbg)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 22)
    except Exception:
        font = ImageFont.load_default()
    wm = np.asarray(dbg).copy()
    # cada región conexa de la máscara con un color distinto: las islas saltan a la vista
    paleta = [(0, 200, 255), (255, 0, 200), (0, 220, 90), (255, 200, 0), (150, 80, 255),
              (255, 90, 0), (0, 120, 255), (200, 255, 0)]
    for c in sorted(cw, key=lambda c: -c["area"]):
        sel = labW == c["k"]
        col = np.array(paleta[(c["k"] - 1) % len(paleta)])
        wm[sel] = (wm[sel] * 0.35 + col * 0.65).astype(np.uint8)
    dbg = Image.fromarray(wm)
    dd = ImageDraw.Draw(dbg)
    for clave, pts in poligonos_px.items():
        if len(pts) < 3:
            continue
        dd.polygon([(x / 2, y / 2) for x, y in pts], outline=(255, 0, 200), width=2)
        cx = sum(p[0] for p in pts) / len(pts) / 2
        cy = sum(p[1] for p in pts) / len(pts) / 2
        dd.text((cx - 8, cy - 12), clave if clave in CATALOGO else clave[-1], fill=(0, 0, 255), font=font)
    DATOS.mkdir(parents=True, exist_ok=True)
    dbg.save(DEBUG)
    log(f"-> {DEBUG.relative_to(RAIZ)}")

    if problemas:
        for p in problemas:
            log("PROBLEMA:", p)
    if verificar:
        log("(--verificar: no se escribió nada)")
        sys.exit(1 if problemas else 0)

    # --- 7. escribir salidas ---
    (SEED / "lugares.json").write_text(
        json.dumps(lugares, indent=1, ensure_ascii=False) + "\n")
    campus = json.loads((SEED / "campus.json").read_text())
    if campo_poly:
        campus["campoDeportivo"] = campo_poly
    campus["planoOverlay"] = {
        "imagen": "assets/plano/plano_campus.webp",
        "esquinas": {"tl": {"lat": tl[0], "lng": tl[1]},
                     "bl": {"lat": bl[0], "lng": bl[1]},
                     "br": {"lat": br[0], "lng": br[1]}},
    }
    (SEED / "campus.json").write_text(json.dumps(campus, indent=1, ensure_ascii=False) + "\n")
    Image.fromarray((walk * 255).astype(np.uint8)).save(CAMINABLE)
    PLANO_APP.parent.mkdir(parents=True, exist_ok=True)
    rec.save(PLANO_APP, "WEBP", quality=80, method=6)
    log(f"-> {SEED.relative_to(RAIZ)}/lugares.json ({len(lugares)} lugares)")
    log(f"-> {SEED.relative_to(RAIZ)}/campus.json (campoDeportivo + planoOverlay)")
    log(f"-> {CAMINABLE.relative_to(RAIZ)} ({walk.shape[1]}x{walk.shape[0]})")
    log(f"-> {PLANO_APP.relative_to(RAIZ)} ({PLANO_APP.stat().st_size // 1024} KB)")
    sys.exit(1 if problemas else 0)


if __name__ == "__main__":
    main()

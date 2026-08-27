#!/usr/bin/env python3
"""Extrae los assets del logo UES desde el manual oficial.

Fuente: "Manual del logotipo UES 2024.pdf" (rediseño de logosímbolo,
LDG Brenda Guerrero). El logo es 100 % vectorial; aquí se recuperan los trazos
con PyMuPDF y se reescriben como SVG mínimo (solo <path>), más los PNG que
necesitan flutter_launcher_icons / flutter_native_splash.

Uso:
    python3 scripts/extraer_logo.py [ruta_al_pdf]

Requiere: pymupdf, pillow  (pip install pymupdf pillow)
"""
from __future__ import annotations

import sys
from pathlib import Path

import pymupdf
from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
DEST = RAIZ / "assets" / "brand"
PDF_DEFECTO = Path.home() / "Documents" / "UES" / "Recursos" / "Manual del logotipo UES 2024.pdf"

NARANJA = "#FF6C0E"  # PANTONE 1585 C
AMARILLO = "#FFA400"  # PANTONE 137 C
VINO = "#8E1537"  # PANTONE 1955 C


def _hex_de_marca(fill) -> str | None:
    """Clasifica un color de relleno del PDF en uno de los 3 institucionales."""
    if fill is None:
        return None
    r, g, b = fill[0], fill[1], fill[2]
    if abs(r - 1) < 0.04 and abs(g - 0.64) < 0.05 and abs(b) < 0.09:
        return AMARILLO
    if abs(r - 1) < 0.04 and abs(g - 0.42) < 0.06 and abs(b - 0.055) < 0.05:
        return NARANJA
    if abs(r - 0.55) < 0.06 and abs(g - 0.08) < 0.05 and abs(b - 0.21) < 0.06:
        return VINO
    return None


def _path_d(draw, ox: float, oy: float) -> str:
    segs: list[str] = []
    cur = None

    def moveto(p) -> None:
        segs.append(f"M{p.x - ox:.2f} {p.y - oy:.2f}")

    for it in draw["items"]:
        op = it[0]
        if op == "l":
            p1, p2 = it[1], it[2]
            if cur is None or abs(cur.x - p1.x) > 0.01 or abs(cur.y - p1.y) > 0.01:
                moveto(p1)
            segs.append(f"L{p2.x - ox:.2f} {p2.y - oy:.2f}")
            cur = p2
        elif op == "c":
            p1, p2, p3, p4 = it[1], it[2], it[3], it[4]
            if cur is None or abs(cur.x - p1.x) > 0.01 or abs(cur.y - p1.y) > 0.01:
                moveto(p1)
            segs.append(
                f"C{p2.x - ox:.2f} {p2.y - oy:.2f} "
                f"{p3.x - ox:.2f} {p3.y - oy:.2f} "
                f"{p4.x - ox:.2f} {p4.y - oy:.2f}"
            )
            cur = p4
        elif op == "re":
            r = it[1]
            segs.append(
                f"M{r.x0 - ox:.2f} {r.y0 - oy:.2f}H{r.x1 - ox:.2f}"
                f"V{r.y1 - oy:.2f}H{r.x0 - ox:.2f}Z"
            )
            cur = None
        elif op == "qu":
            q = it[1]
            segs.append(
                f"M{q.ul.x - ox:.2f} {q.ul.y - oy:.2f}"
                f"L{q.ur.x - ox:.2f} {q.ur.y - oy:.2f}"
                f"L{q.lr.x - ox:.2f} {q.lr.y - oy:.2f}"
                f"L{q.ll.x - ox:.2f} {q.ll.y - oy:.2f}Z"
            )
            cur = None
    if draw.get("closePath"):
        segs.append("Z")
    return "".join(segs)


def _svg(page, excluir=lambda d: False, recolor: str | None = None, pad: float = 6.0) -> str:
    sel = []
    for d in page.get_drawings():
        h = _hex_de_marca(d.get("fill"))
        if not h or excluir(d):
            continue
        sel.append((d, h))
    if not sel:
        raise SystemExit("no se encontraron trazos del logo en la página")

    bb = pymupdf.Rect()
    for d, _ in sel:
        bb |= d["rect"]
    ox, oy = bb.x0 - pad, bb.y0 - pad
    w, h = bb.width + 2 * pad, bb.height + 2 * pad

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.2f} {h:.2f}" '
        f'width="{w:.1f}" height="{h:.1f}">'
    ]
    for d, color in sel:
        rule = "evenodd" if d.get("even_odd") else "nonzero"
        out.append(
            f'<path fill="{recolor or color}" fill-rule="{rule}" '
            f'd="{_path_d(d, ox, oy)}"/>'
        )
    out.append("</svg>")
    return "\n".join(out)


def _svg_a_png(svg_txt: str, escala: float = 8.0) -> Image.Image:
    doc = pymupdf.open(stream=svg_txt.encode(), filetype="svg")
    pix = doc[0].get_pixmap(matrix=pymupdf.Matrix(escala, escala), alpha=True)
    return Image.frombytes("RGBA", (pix.width, pix.height), pix.samples)


def _lienzo(fg: Image.Image, tam: int, fondo, margen: float) -> Image.Image:
    """Centra `fg` en un cuadrado `tam` con `fondo` (RGBA o None) y `margen` (0-1)."""
    base = Image.new("RGBA", (tam, tam), fondo if fondo else (0, 0, 0, 0))
    disp = int(tam * (1 - margen))
    escala = min(disp / fg.width, disp / fg.height)
    nueva = fg.resize((max(1, round(fg.width * escala)), max(1, round(fg.height * escala))), Image.LANCZOS)
    base.alpha_composite(nueva, ((tam - nueva.width) // 2, (tam - nueva.height) // 2))
    return base


def main() -> None:
    pdf = Path(sys.argv[1]) if len(sys.argv) > 1 else PDF_DEFECTO
    if not pdf.exists():
        raise SystemExit(f"no existe el PDF: {pdf}")
    DEST.mkdir(parents=True, exist_ok=True)
    doc = pymupdf.open(pdf)

    # --- SVGs ---
    # Isotipo: llama naranja sólida (pág. 6, versión "rediseñada" a la derecha).
    isotipo = _svg(doc[6], excluir=lambda d: d["rect"].x0 < 400)
    (DEST / "ues_isotipo.svg").write_text(isotipo)

    # Lockup horizontal a color (pág. 18); se excluye el cuadro-marcador de
    # sección (esquina inferior izquierda) por posición.
    excl = lambda d: d["rect"].x1 < 140 or d["rect"].y0 > 400
    color = _svg(doc[18], excluir=excl)
    (DEST / "ues_horizontal.svg").write_text(color)
    (DEST / "ues_horizontal_blanco.svg").write_text(
        _svg(doc[18], excluir=excl, recolor="#FFFFFF")
    )
    print("SVG:", *(p.name for p in DEST.glob("ues_*.svg")))

    # --- PNGs derivados ---
    llama = _svg_a_png(isotipo, escala=12)
    blanco = (255, 255, 255, 255)

    # Ícono del teléfono: llama naranja sobre blanco.
    _lienzo(llama, 1024, blanco, margen=0.22).save(DEST / "icono_app.png")
    # Foreground adaptativo Android (fondo blanco lo pone la config): la llama
    # debe caber en la zona segura (~66 %), por eso lleva más margen.
    _lienzo(llama, 1024, None, margen=0.40).save(DEST / "icono_adaptivo_fg.png")
    # Favicon / PWA: solo la llama, transparente.
    _lienzo(llama, 512, None, margen=0.12).save(DEST / "icono_web.png")
    # Splash (claro y oscuro): la llama funciona sobre ambos fondos.
    splash = _lienzo(llama, 1152, None, margen=0.30)
    splash.save(DEST / "splash.png")
    splash.save(DEST / "splash_dark.png")
    print("PNG:", *(p.name for p in DEST.glob("*.png")))


if __name__ == "__main__":
    main()

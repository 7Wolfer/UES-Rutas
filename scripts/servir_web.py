#!/usr/bin/env python3
"""Sirve build/web para probar en el navegador (LAN incluida).

Añade las cabeceras de aislamiento entre orígenes (COOP/COEP) que necesita
Flutter para usar el renderizador WASM multihilo (skwasm), que va bastante más
fluido que CanvasKit en Safari/Chrome de Apple Silicon.

Uso:
    flutter build web --release --wasm
    python3 scripts/servir_web.py            # http://localhost:8000
    python3 scripts/servir_web.py 9000       # otro puerto

Requiere: solo la biblioteca estándar de Python 3.
"""
from __future__ import annotations

import subprocess
import sys
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DIR_WEB = RAIZ / "build" / "web"
PUERTO = int(sys.argv[1]) if len(sys.argv) > 1 else 8000


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        # Aislamiento entre orígenes → habilita SharedArrayBuffer → skwasm MT.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        # Que el navegador no cachee el index ni el bootstrap entre pruebas.
        if self.path in ("/", "/index.html", "/flutter_bootstrap.js"):
            self.send_header("Cache-Control", "no-store")
        super().end_headers()


def _ip_lan() -> str:
    try:
        salida = subprocess.run(
            ["ipconfig", "getifaddr", "en0"], capture_output=True, text=True
        )
        return salida.stdout.strip() or "?"
    except Exception:
        return "?"


def main() -> None:
    if not (DIR_WEB / "index.html").exists():
        raise SystemExit(
            "No hay build/web. Corre primero:  flutter build web --release --wasm"
        )
    servidor = ThreadingHTTPServer(
        ("0.0.0.0", PUERTO), partial(Handler, directory=str(DIR_WEB))
    )
    print(f"Sirviendo {DIR_WEB}")
    print(f"  En esta Mac:   http://localhost:{PUERTO}")
    print(f"  Desde el móvil: http://{_ip_lan()}:{PUERTO}  (misma red Wi-Fi)")
    print("Ctrl+C para parar.")
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        servidor.shutdown()


if __name__ == "__main__":
    main()

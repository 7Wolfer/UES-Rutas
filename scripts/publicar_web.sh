#!/usr/bin/env bash
# Publica la versión web de UES Rutas en el servidor de ThunderHost (Pterodactyl).
#
#   bash scripts/publicar_web.sh            # compila y publica
#   bash scripts/publicar_web.sh --sin-compilar   # publica el build/web que ya existe
#
# Necesita ~/.config/ues-rutas/panel.env (fuera del repositorio, permisos 600) con:
#   PANEL_URL=https://panel.thunder053.com
#   PANEL_SERVIDOR=<id corto del servidor>
#   PANEL_CLAVE=ptlc_...   (Account → API Keys en el panel; se puede revocar ahí)
#
# Sube un .zip a web_nuevo/, lo descomprime y luego intercambia carpetas
# (web → web_anterior, web_nuevo → web), así el sitio nunca queda a medias.
# El servidor lee los archivos en cada petición: no hace falta reiniciarlo.
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
# El curl del sistema (en algunas Mac el PATH trae primero uno viejo, p. ej. el de XAMPP).
CURL=/usr/bin/curl
CONFIG="${UES_PANEL_ENV:-$HOME/.config/ues-rutas/panel.env}"
SITIO="${URL_PUBLICA:-https://uesrutas.thunder053.com}"

[ -f "$CONFIG" ] || { echo "Falta $CONFIG (ver cabecera del script)." >&2; exit 1; }
# shellcheck disable=SC1090
. "$CONFIG"
API="$PANEL_URL/api/client/servers/$PANEL_SERVIDOR"
AUTH=(-H "Authorization: Bearer $PANEL_CLAVE" -H "Accept: application/json")

api() { # método ruta [json]
  local m="$1" r="$2" d="${3:-}"
  if [ -n "$d" ]; then
    "$CURL" -fsS -X "$m" "${AUTH[@]}" -H "Content-Type: application/json" -d "$d" "$API$r"
  else
    "$CURL" -fsS -X "$m" "${AUTH[@]}" "$API$r"
  fi
}

existe() { # nombre en la raíz del servidor
  api GET "/files/list?directory=%2F" | python3 -c "
import sys, json
nombres = [f['attributes']['name'] for f in json.load(sys.stdin)['data']]
sys.exit(0 if sys.argv[1] in nombres else 1)" "$1"
}

if [ "${1:-}" != "--sin-compilar" ]; then
  echo "▸ Compilando la web…"
  (cd "$RAIZ" && flutter build web --release --dart-define=URL_PUBLICA="$SITIO")
fi
[ -f "$RAIZ/build/web/index.html" ] || { echo "No hay build/web/index.html." >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ZIP="$TMP/web.zip"
echo "▸ Empaquetando…"
(cd "$RAIZ/build/web" && zip -qr "$ZIP" . -x '.DS_Store')

echo "▸ Preparando carpeta temporal en el servidor…"
existe web_nuevo && api POST /files/delete '{"root":"/","files":["web_nuevo"]}' >/dev/null
api POST /files/create-folder '{"root":"/","name":"web_nuevo"}' >/dev/null

echo "▸ Subiendo ($(du -h "$ZIP" | cut -f1))…"
URL_SUBIDA="$(api GET /files/upload | python3 -c 'import sys,json; print(json.load(sys.stdin)["attributes"]["url"])')"
"$CURL" -fsS -X POST -F "files=@$ZIP;filename=web.zip" "$URL_SUBIDA&directory=%2Fweb_nuevo" >/dev/null

echo "▸ Descomprimiendo…"
api POST /files/decompress '{"root":"/web_nuevo","file":"web.zip"}' >/dev/null
api POST /files/delete '{"root":"/web_nuevo","files":["web.zip"]}' >/dev/null

echo "▸ Cambiando a la versión nueva…"
existe web_anterior && api POST /files/delete '{"root":"/","files":["web_anterior"]}' >/dev/null
# Dos llamadas separadas: el panel puede aplicar los renombres en paralelo.
api PUT /files/rename '{"root":"/","files":[{"from":"web","to":"web_anterior"}]}' >/dev/null
api PUT /files/rename '{"root":"/","files":[{"from":"web_nuevo","to":"web"}]}' >/dev/null
api POST /files/delete '{"root":"/","files":["web_anterior"]}' >/dev/null

echo "▸ Comprobando $SITIO …"
CODIGO="$("$CURL" -s -o /dev/null -w '%{http_code}' "$SITIO/?v=$(date +%s)")"
[ "$CODIGO" = "200" ] || { echo "El sitio respondió $CODIGO." >&2; exit 1; }
echo "✓ Publicado en $SITIO"

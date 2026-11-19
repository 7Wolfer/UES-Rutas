# Guía de desarrollo — UES Rutas

Cómo compilar, probar y mantener la app. Pensada para quien continúe el proyecto.

## Requisitos

- Flutter **3.47** (Dart 3.13). `flutter doctor` sin errores bloqueantes para la plataforma
  que se vaya a usar.
- Android: Android Studio con SDK 36 y un emulador (o un teléfono con depuración USB).
- iOS: Xcode completo + CocoaPods (`brew install cocoapods`). Solo en macOS.
- Web: cualquier navegador Chromium o Safari.
- Scripts de datos: Python 3 con `numpy`, `Pillow` y `pymupdf`.

## Comandos habituales

```bash
flutter pub get

# Análisis estático. Usar `dart analyze`: `flutter analyze` falla si la ruta del
# proyecto tiene espacios.
dart analyze

# Pruebas
flutter test

# Android (emulador o teléfono)
flutter emulators --launch Medium_Phone_API_36.0
flutter run

# iOS (teléfono conectado; la primera vez hay que elegir el equipo de firma en Xcode)
flutter run --release -d <id-del-iphone>

# Web: compilación de producción y servidor local con las cabeceras COOP/COEP que
# necesita el renderizador WASM multihilo
flutter build web --release --wasm
python3 scripts/servir_web.py          # http://localhost:8000
```

## Configuración (backend y enlaces)

Los valores sensibles al entorno entran por `--dart-define`. Lo más cómodo es un archivo
`env.json` en la raíz (está en `.gitignore`):

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_…",
  "URL_PUBLICA": "https://tu-sitio.netlify.app"
}
```

```bash
flutter run --dart-define-from-file=env.json
```

Sin `SUPABASE_URL` la app funciona igual con los datos empaquetados en `assets/seed/`.
La clave de Supabase que va en la app es la **publicable** (pública por diseño; la seguridad la
dan las políticas RLS). La clave secreta y la contraseña de la base de datos nunca van en la app
ni en el repositorio.

`AUTH_ENABLED=true` muestra el inicio de sesión (aún sin validar el correo institucional).

## Estructura

```
lib/
  core/            tema, marca UES, router, configuración, utilidades compartidas
  data/            modelos, repositorios, ruteo, búsqueda, proveedores (Riverpod)
  services/        ubicación, notificaciones y demás acceso a la plataforma
  features/<x>/    una carpeta por pantalla o funcionalidad
  design_system/   componentes visuales reutilizables y catálogo (/catalogo)
assets/
  seed/            catálogo del campus (lugares, grafo de rutas, docentes, avisos, calendario)
  tiles/           teselas del campus para usar el mapa sin conexión
  plano/           overlay reducido del plano oficial (vista "Plano")
scripts/           generadores de datos (Python)
supabase/          esquema SQL y datos iniciales del backend
test/              pruebas unitarias y de widgets
```

## Convenciones

- Dominio y textos de la interfaz en **español**; palabras clave y APIs en inglés.
- Estado con **Riverpod** (sin generación de código) y navegación con **go_router**.
- Los datos se leen siempre a través de un repositorio (`lib/data/*_repository.dart`), de modo
  que cambiar la fuente (archivos locales → Supabase) no toca las pantallas.
- Nomenclatura de la señalética física: `EDIFICIO E`, `AULA 1`, `NIVEL 2`
  (ver `docs/IDENTIDAD-UES.md`).
- Cada cambio deja `dart analyze` sin avisos y `flutter test` en verde.

## Regenerar los datos del campus

1. **Plano → edificios, andadores y overlay:** `python3 scripts/importar_plano.py`.
   El plano fuente a resolución completa **no está en el repositorio** (es material de la UES).
   Si no existe `scripts/datos/plano_campus_fuente.jpeg`, se extrae del PDF oficial:
   `python3 scripts/importar_plano.py --pdf "<ruta al PDF del plano>"`.
   `--verificar` revisa sin escribir; `--recalibrar` reajusta la georreferencia con los pares de
   control de `scripts/datos/plano_georef.json`.
2. **Grafo peatonal:** `python3 scripts/generar_grafo.py` (lee la máscara caminable y valida que
   ninguna arista cruce un edificio y que todo quede conectado).
3. **Teselas sin conexión:** `python3 scripts/descargar_teselas.py`.
4. **Íconos y splash:** `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.

## Publicación web

La web está en **https://uesrutas.thunder053.com** (servidor Pterodactyl de ThunderHost que sirve
la carpeta `web/` con `server.js`). Para publicar una versión nueva:

```bash
bash scripts/publicar_web.sh            # compila y publica
bash scripts/publicar_web.sh --sin-compilar
```

El script sube un .zip, lo descomprime en `web_nuevo/` e intercambia carpetas, así el sitio nunca
queda a medias. Necesita `~/.config/ues-rutas/panel.env` (fuera del repositorio, permisos 600)
con `PANEL_URL`, `PANEL_SERVIDOR` y `PANEL_CLAVE` (una clave de API del panel, en Account → API
Keys; se revoca desde ahí).

- El hosting manda `Referrer-Policy: same-origin`; `web/index.html` lo corrige con
  `<meta name="referrer">` para que OpenStreetMap no bloquee las teselas.
- Es un prototipo: lleva `noindex` y `robots.txt` para no aparecer en buscadores.
- `.github/workflows/publicar-web.yml` publica en GitHub Pages si Actions está disponible en la
  cuenta (hoy está bloqueado por facturación).

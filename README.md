# UES Rutas

Aplicación de orientación y navegación (*wayfinding*) para el campus de la
**Universidad Estatal de Sonora — plantel Hermosillo**. Proyecto de prácticas
profesionales.

Estado: **avance inicial**. App funcional con datos de prueba; sin backend
conectado todavía.

---

## Stack

| Capa | Tecnología |
|---|---|
| App móvil | Flutter (iOS + Android desde un solo código; también corre en web) |
| Estado | Riverpod |
| Navegación | go_router |
| Backend / BD (siguiente fase) | Supabase (Postgres, Auth, Storage) |
| Panel admin (siguiente fase) | Next.js en Vercel, mismo proyecto Supabase |

Identidad gráfica: ver [`docs/IDENTIDAD-UES.md`](docs/IDENTIDAD-UES.md)
(extraída del Manual de Identidad Gráfica UES 2024).

---

## Qué hace hoy

- **Buscador universal**: aulas (`AULA B-101`), edificios (`EDIFICIO E`),
  servicios y **docentes** (por nombre, departamento o materia). Sin acentos.
- **Ficha de docente**: oficina, y horario de clases con aula y edificio; botón
  "Ir" a cada aula.
- **Ficha de espacio**: datos, mini-mapa, y —para edificios— el listado de aulas
  y servicios por nivel.
- **Mapa del campus**: dibujado por código (`CustomPainter`), con pan/zoom,
  selector de nivel (PB / N1 / N2) y pines por categoría.
- **Cómo llegar**: ruta peatonal trazada sobre el mapa con indicaciones paso a
  paso, y un toggle **"Ruta accesible"** que evita escaleras (usa rampa/elevador).
- **Ajustes**: tema claro/oscuro, tamaño de texto, alto contraste.
- **Catálogo de diseño** (`/catalogo`): colores, tipografía y componentes UES.

Los datos de `assets/seed/` son **de ejemplo** para la demo.

---

## Correr el proyecto

Requisitos: Flutter (`flutter doctor` sin errores bloqueantes).

```bash
flutter pub get

# Web (rápido para probar / compartir link)
flutter run -d chrome

# iOS  (requiere Xcode + CocoaPods: sudo gem install cocoapods)
flutter run -d ios

# Android (requiere Android Studio + un emulador o dispositivo)
flutter run -d android
```

### Con Supabase (opcional, aún no requerido)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_PUBLISHABLE_KEY \
  --dart-define=AUTH_ENABLED=true
```

El esquema de la base está en
[`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql).

### Pruebas

```bash
flutter test          # lógica de búsqueda y ruteo + smoke test
dart analyze          # análisis estático (usar en vez de `flutter analyze`)
```

---

## Estructura

```
lib/
  core/            tema, router, marca (colores UES), config, formato de etiquetas
  design_system/   componentes reutilizables + catálogo (/catalogo)
  data/            modelos, repositorio (seed local / Supabase), búsqueda, ruteo
  features/
    inicio/ busqueda/ mapa/ espacio/ docente/ ruta/ ajustes/ auth/ shell/
assets/
  seed/            edificios, espacios, docentes y grafo de rutas (JSON de prueba)
  map/             (planos reales cuando la UES los entregue)
  brand/           placeholder del logo (sustituir por el oficial de DDIIUES)
```

---

## Pendientes que dependen de la Universidad

1. **Planos arquitectónicos digitales** del campus (por edificio / por nivel) →
   el mapa deja de ser ilustrativo.
2. **Método de inicio de sesión institucional**: API de control escolar para
   validar correo o matrícula, o validación por dominio `@ues.mx`. Confírmalo
   con el área de TI.
3. **Logo / logosímbolo vectorial** y guía de señalética → DDIIUES.
4. Catálogo real de edificios, aulas, servicios y docentes.
5. Titular y pago de las cuentas de tienda (Apple Developer, Google Play).
6. Responsable de mantener el contenido después de las prácticas.
7. Contacto en jurídico para el aviso de privacidad.

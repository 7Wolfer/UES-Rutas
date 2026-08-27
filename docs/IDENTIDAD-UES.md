# Identidad gráfica UES aplicada a la app

Fuente: *Manual de Identidad Gráfica UES 2024* (Depto. de Difusión e Imagen
Institucional — DDIIUES). Copia legible en texto:
`scratchpad/manual-identidad-ues.md` (fuera del repo).

> El manual es un documento **de impresión**. No cubre modo oscuro, estados de
> interacción ni colores de categoría para mapas. Esas piezas se derivan aquí y
> deben validarse con DDIIUES. Quedan marcadas como **[extensión digital]**.

---

## 1. Color

### Paleta institucional (única permitida en comunicación digital)

| Rol | Nombre | Pantone | HEX | RGB |
|---|---|---|---|---|
| Principal | Naranja | 1585 C | `#FF6C0E` | 255, 108, 14 |
| Secundario | Amarillo | 137 C | `#FFA400` | 255, 164, 0 |
| Institucional | Vino | 1955 C | `#8E1537` | 142, 21, 55 |

- Existe una **paleta de degradados oficial** y una **paleta auxiliar** — esta
  última **solo para prendas y merchandising**, no para la app.
- **Prohibido:** otros colores en el logo, degradados no oficiales, sombras
  inapropiadas, fondos sin contraste suficiente.

### Uso en la app

- **Naranja `#FF6C0E`** — acción primaria, navegación activa, punto de ubicación
  del usuario, trazo de ruta. Es muy saturado: **acento, nunca fondo dominante**.
- **Vino `#8E1537`** — encabezados, barra superior, énfasis institucional serio.
- **Amarillo `#FFA400`** — destacados puntuales (favoritos, avisos suaves).
- **Neutros cálidos** [extensión digital] — escala derivada para fondos, tarjetas
  y texto secundario (ver `lib/core/brand.dart`).

### Colores de categoría del mapa  [extensión digital — validar con DDIIUES]

Subconjunto sobrio y con contraste AA. No sustituyen a la paleta institucional;
solo dan legibilidad al mapa (como en apps de museos o centros comerciales).

| Categoría | HEX |
|---|---|
| Aula / edificio académico | `#8E1537` (vino) |
| Servicios (baños, agua) | `#3F6B7D` (azul pizarra) |
| Alimentos (cafetería) | `#B4531F` (terracota) |
| Biblioteca | `#4A5240` (verde oliva) |
| Estacionamiento | `#5B5563` (gris violáceo) |
| Salud / enfermería | `#1E7A5B` (verde) |
| Accesibilidad (rampa, elevador) | `#2457A6` (azul) |

---

## 2. Tipografía

| Familia | Google Fonts | Uso en la app |
|---|---|---|
| Source Sans Pro | **Source Sans 3** | Cuerpo, etiquetas, controles (principal digital) |
| Montserrat | **Montserrat** | Títulos y encabezados |
| Source Serif Pro | Source Serif 4 | *No se usa en la app* (textos largos/informes) |
| Cibreo | — | **Solo el logo.** Nunca en la UI |

Se cargan con el paquete `google_fonts`.

---

## 3. Símbolo — la llama

- Compuesta por líneas onduladas. Significa **sabiduría y pasión**.
- Tres módulos: los dos primeros amarillos, el tercero naranja.
- Puede usarse **sola** como elemento gráfico (patrones, marcas de agua sutiles).
- No alterar proporción, color ni orientación. Respetar el **área de protección**
  y el **tamaño mínimo**.

**Pendiente:** solicitar a DDIIUES el logosímbolo y la llama en **vectorial**
(AI / EPS / SVG). Mientras tanto la app usa un placeholder tipográfico
("UES Rutas") — ver `assets/brand/`.

---

## 4. Nomenclatura (señalética física oficial)

El manual define el sistema señalético del campus con estas etiquetas:

```
EDIFICIO E      AULA 1      NIVEL 2
```

**La app debe usar exactamente estas cadenas** para que coincidan con los
letreros reales. Helpers en `lib/core/formato.dart`:

- `etiquetaEdificio("E")           → "EDIFICIO E"`
- `etiquetaAula("1")               → "AULA 1"`
- `etiquetaNivel(2)                → "NIVEL 2"`
- `etiquetaNivel(0)                → "PLANTA BAJA"`

Tipos de señal del manual (referencia): orientadoras, informativas,
identificativas, reguladoras, ornamentales.

---

## 5. Checklist de cumplimiento (revisar antes de cada entrega)

- [ ] Colores exactos `#FF6C0E` / `#FFA400` / `#8E1537`; sin degradados no oficiales.
- [ ] Montserrat en títulos, Source Sans 3 en cuerpo; Cibreo ausente de la UI.
- [ ] Etiquetas `EDIFICIO` / `AULA` / `NIVEL` idénticas a la señalética.
- [ ] Logo (cuando llegue el vectorial): área de protección y tamaño mínimo.
- [ ] Contraste de texto AA como mínimo.
- [ ] Extensiones digitales (modo oscuro, colores de mapa) enviadas a DDIIUES
      para visto bueno.

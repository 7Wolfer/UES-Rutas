# Logo institucional UES

Assets del logosímbolo de la **Universidad Estatal de Sonora**, usados en la app
UES Rutas (proyecto de prácticas profesionales).

## Fuente

`Manual del logotipo UES 2024` — "Rediseño de logosímbolo", LDG Brenda Guerrero.
El logo es vectorial; estos archivos se extrajeron de ese PDF con
`scripts/extraer_logo.py`. Para regenerarlos:

```
python3 scripts/extraer_logo.py "/ruta/al/Manual del logotipo UES 2024.pdf"
```

## Archivos

| Archivo | Contenido |
|---|---|
| `ues_isotipo.svg` | Logosímbolo (llama), 1 tinta. Por defecto naranja `#FF6C0E`; se puede reteñir con `colorFilter`. |
| `ues_horizontal.svg` | Lockup horizontal a color: llama + "UES" (vino) + "Universidad Estatal de Sonora" (vino) + "La Fuerza del Saber Estimulará mi Espíritu" (amarillo). |
| `ues_horizontal_blanco.svg` | El lockup completo en blanco, para fondos oscuros / vino. |
| `icono_app.png` | Ícono de iOS/Android: llama naranja sobre blanco. |
| `icono_adaptivo_fg.png` | Foreground del ícono adaptativo de Android (fondo blanco por config). |
| `icono_web.png` | Favicon / iconos PWA: solo la llama, fondo transparente. |
| `splash.png` / `splash_dark.png` | Pantalla de arranque. |

## Paleta institucional (manual, pág. 17)

| Color | HEX | Pantone |
|---|---|---|
| Naranja | `#FF6C0E` | 1585 C |
| Amarillo | `#FFA400` | 137 C |
| Vino | `#8E1537` | 1955 C |

## Uso

- No deformar, re-colorear fuera de la paleta, ni ponerle sombras/contornos.
- En tamaños pequeños usar solo el logosímbolo (la llama).
- Las siglas "UES" del lockup están en la tipografía CIBREO: usar siempre el
  vector, no recrearlas con otra fuente.

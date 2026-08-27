# Fuentes empaquetadas

Tipografías de la identidad UES, incluidas como assets para no descargarlas en
runtime (arranque más rápido, sin *flash* de fuente ni reflow). Se declaran en
`pubspec.yaml` (`flutter > fonts`) y se usan desde `lib/core/theme.dart`.

| Familia        | Uso        | Origen                                             | Licencia |
|----------------|------------|----------------------------------------------------|----------|
| Montserrat     | Títulos    | github.com/JulietaUla/Montserrat                    | OFL 1.1  |
| Source Sans 3  | Cuerpo     | github.com/adobe-fonts/source-sans                  | OFL 1.1  |

Los `.ttf` están **subconjunteados** a Latín + Latín Extendido + puntuación
(`pyftsubset`, ~100–150 KB por peso) para reducir el tamaño del bundle. Si se
necesita otro rango de caracteres, volver a subconjuntear desde los archivos
completos del upstream.

Textos de licencia: `OFL-Montserrat.txt`, `OFL-SourceSans3.txt`.

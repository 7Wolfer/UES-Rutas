# assets/map/

El mapa del campus se dibuja **por código** (`CustomPainter`) sobre un sistema
de coordenadas 0–1000 × 0–700, usando el catálogo de `assets/seed/`.

Cuando la Universidad entregue los **planos arquitectónicos digitales**, aquí
van los SVG por edificio / por nivel, y el painter pasa a renderizarlos como
capas en lugar de rectángulos.

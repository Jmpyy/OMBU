#!/usr/bin/env python3
"""Recorta un menú de una captura completa por su color de fondo, sin nada de lo que haya detrás
(AGENTS.md: las capturas del repo no pueden mostrar otras ventanas).

Uso: menu-shot.py captura.png salida.png SEMILLA_X SEMILLA_Y [Y_MIN] [ANCHO_MAX] [ALTO_MAX]
La semilla es un punto dentro del menú (cerca de su margen, no sobre un slider). Se toma como fondo el
color más frecuente alrededor de ella y se inunda desde ahí: esa es la silueta del menú. Lo encerrado
(texto, íconos) se conserva y lo de afuera queda transparente. Y_MIN deja afuera la barra (50 para los
menús que cuelgan de ella). Si la silueta sale de un tamaño raro (se escapó a una ventana del mismo
color, o el menú no estaba abierto) no se guarda nada y sale con error.
Capturar con el menú ya abierto del todo: timeout 4 grim -o HDMI-A-1 captura.png
"""
import sys
from collections import deque
import numpy as np
from PIL import Image, ImageDraw

src, dst, sx, sy = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
ymin = int(sys.argv[5]) if len(sys.argv) > 5 else 50
wmax = int(sys.argv[6]) if len(sys.argv) > 6 else 900
hmax = int(sys.argv[7]) if len(sys.argv) > 7 else 1000

img = np.array(Image.open(src).convert("RGB"))
H, W, _ = img.shape
# El fondo del menú, tal como sale en la captura (el compositor lo corre un poco del de Themes.qml)
win = img[max(0, sy - 10):sy + 11, max(0, sx - 10):sx + 11].reshape(-1, 3)
colors, counts = np.unique(win, axis=0, return_counts=True)
BG = tuple(int(c) for c in colors[counts.argmax()])
isbg = np.all(np.abs(img.astype(int) - BG) <= 1, axis=2)
isbg[:ymin, :] = False  # la barra (y el cuello del menú) quedan afuera

# La semilla tiene que caer en el fondo: se busca el píxel de fondo más cercano
if not isbg[sy, sx]:
    ys, xs = np.nonzero(isbg[max(0, sy - 30):sy + 30, max(0, sx - 30):sx + 30])
    if len(ys) == 0:
        sys.exit(f"{dst}: no hay fondo del menú cerca de la semilla")
    i = np.argmin((ys - 30) ** 2 + (xs - 30) ** 2)
    sy, sx = ys[i] + max(0, sy - 30), xs[i] + max(0, sx - 30)

def flood(allowed, seeds):
    out = np.zeros_like(allowed)
    q = deque()
    for y, x in seeds:
        if allowed[y, x] and not out[y, x]:
            out[y, x] = True
            q.append((y, x))
    while q:
        y, x = q.popleft()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < allowed.shape[0] and 0 <= nx < allowed.shape[1] and allowed[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out

body = flood(isbg, [(sy, sx)])
ys, xs = np.nonzero(body)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
w, h = x1 - x0, y1 - y0
if w > wmax or h > hmax or w < 120 or h < 80:
    sys.exit(f"{dst}: silueta sospechosa {w}x{h} en ({x0},{y0}): no se guarda")

# Afuera = lo que no es fondo y se alcanza desde el borde del recuadro sin cruzar la silueta
b = body[y0:y1, x0:x1]
edge = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
outside = flood(~b, edge)
alpha = np.where(outside, 0, 255).astype(np.uint8)
rgba = np.dstack([img[y0:y1, x0:x1], alpha])
out = Image.fromarray(rgba, "RGBA")

# Arriba el corte es recto (ahí el menú se une a la barra): se le redondean las esquinas
r = 14
m = Image.new("L", (w, h), 0)
ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h + r], radius=r, fill=255)
out.putalpha(Image.fromarray(np.minimum(np.array(out.getchannel("A")), np.array(m))))
out.save(dst, optimize=True)
print(f"{dst}: {w}x{h}")

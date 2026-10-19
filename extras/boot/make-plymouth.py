#!/usr/bin/env python3
"""Genera el tema de Plymouth (la intro de arranque) de ombu: una araña colgada de su hilo que se balancea
mientras el sistema arranca y, al terminar, sube por el hilo. Usa los colores del tema de ombu.

Uso: make-plymouth.py CARPETA [--accent #e23b32] [--cream #efe8dc] [--shadow #8c231e] [--ink #0a0708]
Escribe CARPETA/ombu-spidey.plymouth y los cuadros (throbber-NN.png en bucle, animation-NN.png al terminar).
Necesita ImageMagick (`magick`) y la fuente Bangers (~/.local/share/fonts/ombu) para el nombre; sin ella
se usa la fuente por defecto. No toca el sistema: instalarlo es cosa de install-plymouth.sh."""
import argparse
import math
import os
import subprocess
import sys

W, H = 300, 1200         # tamaño de cada cuadro (1x): tan alto como una pantalla, para que el hilo salga del borde de arriba
CY = 560                  # altura de la araña en reposo
S = 2
LOOP, END = 30, 24
FONT = os.path.expanduser("~/.local/share/fonts/ombu/Bangers-Regular.ttf")

# Patas de la araña del logo de la barra (caja de 64x64), lado izquierdo; la derecha es el espejo
LEGS = [[(28, 22), (14, 8), (6, 14)], [(27, 27), (8, 22), (3, 32)], [(27, 34), (8, 38), (4, 50)], [(28, 42), (14, 54), (10, 62)]]


def spider_cmds(cx, cy, size, wiggle, accent, ink):
    """Instrucciones de dibujo (ImageMagick) de la araña con el centro de su caja en (cx, cy) a 2x"""
    k = size * S / 64.0

    def P(x, y):
        return cx + (x - 32) * k, cy + (y - 32) * k

    cmds = []
    for i, leg in enumerate(LEGS):
        for mirror in (False, True):
            pts = []
            for j, (x, y) in enumerate(leg):
                if j == len(leg) - 1:  # la punta se mueve un poco, cada pata a su ritmo
                    x += 2.2 * math.sin(wiggle + i * 1.3) * (-1 if mirror else 1)
                    y += 1.6 * math.cos(wiggle * 1.1 + i)
                px, py = P(64 - x if mirror else x, y)
                pts.append("%.1f,%.1f" % (px, py))
            cmds += ["-stroke", ink, "-strokewidth", str(round(10 * S / 2)), "-fill", "none", "-draw", "polyline " + " ".join(pts)]
            cmds += ["-stroke", accent, "-strokewidth", str(round(6 * S / 2)), "-fill", "none", "-draw", "polyline " + " ".join(pts)]
    bx, by = P(32, 41)
    hx, hy = P(32, 24)
    cmds += ["-stroke", ink, "-strokewidth", str(3 * S), "-fill", accent,
             "-draw", "ellipse %.1f,%.1f %.1f,%.1f 0,360" % (bx, by, 8.5 * k, 14 * k),
             "-draw", "circle %.1f,%.1f %.1f,%.1f" % (hx, hy, hx + 5.5 * k, hy)]
    return cmds, P(32, 18.5)


def frame(path, spider_y, wiggle, sway, alpha, args, label=True):
    cx = W * S / 2 + sway * S
    cmds = ["magick", "-size", "%dx%d" % (W * S, H * S), "xc:none", "-antialias"]
    sp, top = spider_cmds(cx, spider_y * S, 120, wiggle, args.accent, args.ink)
    # hilo: del borde de arriba a la cabeza
    cmds += ["-stroke", args.ink, "-strokewidth", str(6 * S), "-draw", "line %.1f,0 %.1f,%.1f" % (W * S / 2, top[0], top[1]),
             "-stroke", args.cream, "-strokewidth", str(3 * S), "-draw", "line %.1f,0 %.1f,%.1f" % (W * S / 2, top[0], top[1])]
    cmds += sp
    if label:
        font = ["-font", FONT] if os.path.exists(FONT) else []
        top = (CY + 120) * S   # el nombre queda fijo debajo de donde cuelga la araña
        for dx, dy, fill, stroke in ((5 * S, 5 * S, args.shadow, args.shadow), (0, 0, args.cream, args.ink)):
            cmds += font + ["-stroke", stroke, "-strokewidth", str(4 * S if stroke == args.ink else 1), "-fill", fill,
                            "-pointsize", str(58 * S), "-gravity", "north", "-annotate", "+%d+%d" % (dx, top + dy), "OMBU"]
    cmds += ["-resize", "%d%%" % (100 // S)]
    if alpha < 1:
        cmds += ["-channel", "A", "-evaluate", "multiply", "%.3f" % alpha, "+channel"]
    cmds.append(path)
    subprocess.run(cmds, check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--accent", default="#e23b32")
    ap.add_argument("--cream", default="#efe8dc")
    ap.add_argument("--shadow", default="#8c231e")
    ap.add_argument("--ink", default="#0a0708")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for i in range(LOOP):
        t = i / LOOP * 2 * math.pi
        frame(os.path.join(a.out, "throbber-%02d.png" % i), CY + 22 * math.sin(t), t * 2, 5 * math.sin(t), 1, a)
    for i in range(END):
        u = i / (END - 1)
        # sube por el hilo cada vez más rápido y se desvanece
        frame(os.path.join(a.out, "animation-%02d.png" % i), CY - (CY + 120) * u * u, u * 8, 0, 1 - u * u, a, label=True)
    with open(os.path.join(a.out, "ombu-spidey.plymouth"), "w", encoding="utf-8") as f:
        f.write(PLYMOUTH)
    print("tema en", a.out)


PLYMOUTH = """[Plymouth Theme]
Name=ombu-spidey
Description=La araña de ombu colgada de su hilo mientras arranca el sistema
ModuleName=two-step

[two-step]
Font=Inter 12
TitleFont=Inter Bold 32
ImageDir=/usr/share/plymouth/themes/ombu-spidey
DialogHorizontalAlignment=.5
DialogVerticalAlignment=.5
TitleHorizontalAlignment=.5
TitleVerticalAlignment=.382
HorizontalAlignment=.5
VerticalAlignment=.5
Transition=none
TransitionDuration=0.0
BackgroundStartColor=0x0a0708
BackgroundEndColor=0x161011
ProgressBarBackgroundColor=0x35282a
ProgressBarForegroundColor=0xe23b32
DialogClearsFirmwareBackground=false
MessageBelowAnimation=true

[boot-up]
UseEndAnimation=true
UseFirmwareBackground=false

[shutdown]
UseEndAnimation=false
UseFirmwareBackground=false

[reboot]
UseEndAnimation=false
UseFirmwareBackground=false

[updates]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
_Title=Instalando actualizaciones...
_SubTitle=No apagues el equipo

[system-upgrade]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
_Title=Actualizando el sistema...
_SubTitle=No apagues el equipo

[firmware-upgrade]
SuppressMessages=true
ProgressBarShowPercentComplete=true
UseProgressBar=true
_Title=Actualizando el firmware...
_SubTitle=No apagues el equipo
"""

if __name__ == "__main__":
    main()

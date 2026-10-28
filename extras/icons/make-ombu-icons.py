#!/usr/bin/env python3
"""Crea el tema de iconos "Ombu": Papirus-Dark con todas las carpetas del color que elijas
(violeta por defecto; lo cambia bin/qt-theme.py según el tema de colores).

Papirus trae una variante violeta de cada carpeta (folder-violet*.svg) pero el tema usa la
azul por defecto. Este script arma un tema de usuario que hereda Papirus-Dark y reemplaza,
con enlaces simbólicos, cada ícono de carpeta azul por su equivalente violeta.

Con --accent, en vez de enlazar el color de Papirus, escribe cada carpeta en una versión pastel del
acento (mismo tono, menos saturada y más clara, como las de Finder): el color puro de Papirus en
carpetas de 64 px dominaba toda la ventana.

Necesita: papirus-icon-theme.   Uso: python3 make-ombu-icons.py [color] [--accent #a78bfa]
Colores de Papirus: violet, indigo, blue, cyan, teal, green, yellow, orange, deeporange, red, pink...
Después: icon_theme=Ombu en qt6ct.conf (o el que use tu app).
"""
import colorsys
import glob
import os
import re
import subprocess
import sys

args = sys.argv[1:]
ACCENT = ""
if "--accent" in args:
    i = args.index("--accent")
    ACCENT = args[i + 1]
    del args[i:i + 2]
COLOR = args[0] if args else "violet"

# Colores de las carpetas azules de Papirus: frente, fondo (la solapa de atrás) y el dibujo de adentro
BLUE = {"#5294e2": "front", "#4877b1": "back", "#1d344f": "glyph"}


def soft(accent):
    """Frente, fondo y dibujo de la carpeta en el tono del acento: claro y poco saturado"""
    h = accent.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, _, sat = colorsys.rgb_to_hls(r, g, b)

    def hls(light, s):
        return "#%02x%02x%02x" % tuple(round(v * 255) for v in colorsys.hls_to_rgb(hue, light, min(sat, s)))

    return {"front": hls(0.72, 0.6), "back": hls(0.6, 0.5), "glyph": hls(0.3, 0.45)}


SOFT = soft(ACCENT) if ACCENT else None

BASE = "/usr/share/icons/Papirus-Dark"
DEST = os.path.expanduser("~/.local/share/icons/Ombu")

if not os.path.isdir(BASE):
    raise SystemExit("Falta papirus-icon-theme (no encuentro %s)" % BASE)

index = open(BASE + "/index.theme").read()
os.makedirs(DEST, exist_ok=True)
dirs, links = [], 0
for d in sorted(glob.glob(BASE + "/*/places")):
    size = os.path.basename(os.path.dirname(d))
    out = os.path.join(DEST, size, "places")
    made = False
    for name in os.listdir(d):
        real = os.path.realpath(os.path.join(d, name))
        base = os.path.basename(real)
        if "-blue" not in base:
            continue
        violet = os.path.join(os.path.dirname(real), base.replace("-blue", "-" + COLOR))
        if not SOFT and not os.path.exists(violet):
            continue
        os.makedirs(out, exist_ok=True)
        link = os.path.join(out, name)
        if os.path.lexists(link):
            os.remove(link)
        if SOFT:
            with open(real, encoding="utf-8") as f:
                svg = re.sub(r"#[0-9a-fA-F]{6}", lambda m: SOFT.get(BLUE.get(m.group(0).lower()), m.group(0)), f.read())
            with open(link, "w", encoding="utf-8") as f:
                f.write(svg)
        else:
            os.symlink(violet, link)
        links += 1
        made = True
    if made:
        dirs.append(size + "/places")

sections = ""
for d in dirs:
    m = re.search(r"\[%s\]\n(.*?)\n\n" % re.escape(d), index, re.S)
    sections += "[%s]\n%s\n\n" % (d, m.group(1))
with open(DEST + "/index.theme", "w") as f:
    f.write("[Icon Theme]\nName=Ombu\nComment=Papirus-Dark con carpetas de color %s\n"
            "Inherits=Papirus-Dark\nDirectories=%s\n\n%s" % (ACCENT + " suave" if ACCENT else COLOR, ",".join(dirs), sections))
subprocess.run(["gtk-update-icon-cache", "-f", "-t", DEST], check=False)
print("Tema Ombu listo: %d íconos en %s" % (links, DEST))

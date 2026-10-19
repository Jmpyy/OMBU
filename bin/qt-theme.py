#!/usr/bin/env python3
"""Pinta Dolphin, las demás apps Qt y la terminal (kitty) con los colores del tema de ombu.

Toma las plantillas de extras/ (que están en los colores del tema Ombú) y cambia cada color por
el del tema elegido; los tonos derivados (más claro, más oscuro) se calculan. Escribe:
  ~/.config/qt6ct/colors/ombu.conf        la paleta de qt6ct
  ~/.config/qt6ct/qss/ombu.qss            la hoja de estilos (bordes redondeados, selección)
  ~/.local/share/color-schemes/Ombu.colors  el esquema de colores de KDE
  ~/.config/kitty/themes/ombu.conf        los colores de la terminal (se recarga sola con SIGUSR1)
y rehace las carpetas del tema de íconos Ombu en el color de Papirus que corresponda.
Los archivos de antes se guardan una vez como .pre-temas. Las ventanas abiertas no cambian: el
tema se nota en la siguiente que abras.

Uso: qt-theme.py --bg #14131a --surface #1d1c26 --track #2b2a38 --text #e8e8f0 --dim #8a8a9c
                 --accent #a78bfa --danger #f87171 --warn #fbbf24 --on-accent #14131a --folder violet [--out CARPETA]
  --out escribe en CARPETA en vez de en tu configuración (para probar)."""
import argparse
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EXTRAS = os.path.join(HERE, "..", "extras")

# Colores base del tema Ombú: las plantillas están escritas con estos
DEFAULT = {"bg": "#14131a", "surface": "#1d1c26", "track": "#2b2a38", "text": "#e8e8f0",
           "dim": "#8a8a9c", "accent": "#a78bfa", "danger": "#f87171", "warn": "#fbbf24"}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in c)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


WHITE, BLACK = (255, 255, 255), (0, 0, 0)


def table(c):
    """De cada color de las plantillas al del tema nuevo (base y derivados), en RGB"""
    t = {k: rgb(v) for k, v in c.items()}
    d = {k: rgb(v) for k, v in DEFAULT.items()}
    out = {d[k]: t[k] for k in d}
    # Derivados: se calculan igual desde el tema Ombú (para encontrarlos) y desde el nuevo
    for src, dst in [(mix(d["track"], WHITE, 0.07), mix(t["track"], WHITE, 0.07)),
                     (mix(d["track"], WHITE, 0.04), mix(t["track"], WHITE, 0.04)),
                     (mix(d["accent"], WHITE, 0.35), mix(t["accent"], WHITE, 0.35)),
                     (mix(d["bg"], WHITE, 0.02), mix(t["bg"], WHITE, 0.02)),
                     (mix(d["bg"], BLACK, 0.25), mix(t["bg"], BLACK, 0.25)),
                     (mix(d["danger"], BLACK, 0.5), mix(t["danger"], BLACK, 0.5))]:
        out[tuple(round(v) for v in src)] = dst
    return out


# Derivados que las plantillas traen escritos a mano (no salen exactos de la fórmula de arriba)
EXACT = {"#3a3950": ("track", 0.07), "#323146": ("track", 0.04), "#c4b5fd": ("accent", 0.35),
         "#18171f": ("bg", 0.02), "#0f0e14": ("bg", -0.25), "#7f1d1d": ("danger", -0.5)}


ON = "@@ON_ACCENT@@"


def protect_on_accent(text):
    """Marca el texto que va sobre un fondo de acento (qss: `color:`/`selection-color:`; kitty: cursor y
    pestaña activa) para que no se confunda con el fondo oscuro, que usa el mismo color"""
    text = re.sub(r"((?:selection-)?color: )#14131a", r"\1" + ON, text)
    return re.sub(r"^((?:cursor_text_color|active_tab_foreground)\s+)#14131a", r"\1" + ON, text, flags=re.M)


def recolor(text, c):
    on_accent = c.pop("on_accent", None)
    text = protect_on_accent(text)
    base = {k: rgb(v) for k, v in c.items()}
    direct = {DEFAULT[k]: hexc(base[k]) for k in DEFAULT}
    for h, (k, t) in EXACT.items():
        direct[h] = hexc(mix(base[k], WHITE if t > 0 else BLACK, abs(t)))

    def hex_sub(m):
        return direct.get(m.group(0).lower(), m.group(0))

    text = re.sub(r"#[0-9a-fA-F]{6}\b", hex_sub, text)

    # Tripletas "r,g,b" (esquema de KDE) y "rgba(r, g, b, a)" (hoja de estilos)
    rgb_map = {rgb(h): rgb(v) for h, v in direct.items()}

    def trip_sub(m):
        key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        n = rgb_map.get(key)
        return "%d,%d,%d" % n if n else m.group(0)

    text = re.sub(r"(?<![0-9.])(\d{1,3}),(\d{1,3}),(\d{1,3})(?![0-9])", trip_sub, text)

    def rgba_sub(m):
        key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
        n = rgb_map.get(key)
        return "rgba(%d, %d, %d," % n if n else m.group(0)

    text = re.sub(r"rgba\((\d{1,3}), (\d{1,3}), (\d{1,3}),", rgba_sub, text)
    return text.replace(ON, on_accent or "#14131a")


def write(path, content, backup):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if backup and os.path.exists(path) and not os.path.exists(path + ".pre-temas"):
        shutil.copy2(path, path + ".pre-temas")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def main():
    ap = argparse.ArgumentParser()
    for k in DEFAULT:
        ap.add_argument("--" + k, default=DEFAULT[k])
    ap.add_argument("--on-accent", dest="on_accent", default="#14131a")
    ap.add_argument("--folder", default="violet")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    colors = {k: getattr(a, k) for k in DEFAULT}
    on_accent = a.on_accent
    home = os.path.expanduser("~")
    root = a.out or home
    targets = [
        (os.path.join(EXTRAS, "qt6ct", "colors", "ombu.conf"), os.path.join(root, ".config/qt6ct/colors/ombu.conf")),
        (os.path.join(EXTRAS, "qt6ct", "ombu.qss"), os.path.join(root, ".config/qt6ct/qss/ombu.qss")),
        (os.path.join(EXTRAS, "kde", "Ombu.colors"), os.path.join(root, ".local/share/color-schemes/Ombu.colors")),
        (os.path.join(EXTRAS, "kitty", "themes", "ombu.conf"), os.path.join(root, ".config/kitty/themes/ombu.conf")),
    ]
    for src, dst in targets:
        with open(src, encoding="utf-8") as f:
            text = f.read()
        # Con el tema Ombú las plantillas ya están en sus colores: se copian sin tocar
        same = colors == DEFAULT and on_accent == "#14131a"
        write(dst, text if same else recolor(text, dict(colors, on_accent=on_accent)), backup=not a.out)
    if not a.out:
        # kitty vuelve a leer su configuración al recibir SIGUSR1: las terminales abiertas cambian de color
        subprocess.run(["pkill", "-USR1", "-x", "kitty"], check=False)
        subprocess.run([sys.executable, os.path.join(EXTRAS, "icons", "make-ombu-icons.py"), a.folder],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    print("tema aplicado a las apps Qt" + (" (prueba en %s)" % root if a.out else ""))


if __name__ == "__main__":
    main()

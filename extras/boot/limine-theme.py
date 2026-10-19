#!/usr/bin/env python3
"""Cambia el aspecto del menú de arranque de Limine (/boot/limine.conf) al de ombu, sin tocar nada más.

Uso: limine-theme.py ENTRADA SALIDA [--wallpaper RUTA] [--direct] [--drop-others]
  Lee ENTRADA (una copia de limine.conf), cambia SOLO las opciones de aspecto de la parte de arriba (las
  de antes de las entradas del menú) y escribe SALIDA. Comprueba que todo lo demás (las entradas de
  kernel, Windows, las instantáneas, que llevan hashes) quede byte por byte igual; si no, no escribe nada.

Las opciones que cambia: la paleta, los colores de texto, la marca «OMBU» y el fondo. Sin más opciones no
toca el tiempo de espera, la entrada por defecto, ni term_background / term_background_bright (el tema de
CachyOS las usa a su manera y no se pueden probar sin arrancar).

  --direct        arranque directo: `quiet: yes` y 2 s de espera; el menú solo aparece si se aprieta una
                  tecla al encender. Siempre arranca la entrada por defecto (`remember_last_entry: no`).
  --drop-others   saca el grupo «Other systems and bootloaders» (Windows y el cargador de respaldo que
                  Limine agrega solo al encontrar restos en la partición de arranque)."""
import re
import sys

THEME = {
    "term_palette": "161011;e23b32;5fb98a;f2b84b;6f9bf0;ff7a8a;5fb0ae;efe8dc",
    "term_palette_bright": "4a3c3e;ff6a5f;8fe0b2;ffd27a;9fbcf7;ff9aa7;8fd6d3;fff4e8",
    "term_foreground": "efe8dc",
    "term_foreground_bright": "fff4e8",
    "interface_branding": "OMBU",
    "interface_branding_colour": "e23b32",
    "interface_help_colour": "a89c90",
    "interface_help_colour_bright": "f2b84b",
}
DIRECT = {"timeout": "2", "quiet": "yes", "remember_last_entry": "no"}
OTHERS = "/+Other systems and bootloaders"
ALIASES = {"interface_branding_color": "interface_branding_colour", "interface_help_color": "interface_help_colour",
           "interface_help_color_bright": "interface_help_colour_bright"}
KEY = re.compile(r"^([a-z_]+):")


def split(text):
    """(parte global, resto). El resto empieza en el primer comentario o entrada del menú."""
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.startswith("/") or line.startswith("comment:"):
            return "\n".join(lines[:i]) + "\n", "\n".join(lines[i:])
    raise ValueError("no encuentro dónde empiezan las entradas del menú")


def drop_others(rest):
    """El resto sin el grupo «Other systems and bootloaders» (que va al final de limine.conf)"""
    lines = rest.split("\n")
    for i, line in enumerate(lines):
        if line.startswith(OTHERS):
            return "\n".join(lines[:i]).rstrip("\n") + "\n"
    return rest


def retheme(text, wallpaper=None, direct=False, drop=False):
    head, rest = split(text)
    values = dict(THEME)
    if wallpaper:
        values["wallpaper"] = wallpaper
    if direct:
        values.update(DIRECT)
    done, out = set(), []
    for line in head.rstrip("\n").split("\n"):
        m = KEY.match(line)
        key = ALIASES.get(m.group(1), m.group(1)) if m else None
        if key in values:
            if key not in done:
                out.append("%s: %s" % (key, values[key]))
                done.add(key)
            continue  # un alias repetido se descarta
        out.append(line)
    # Las opciones que faltaban se agregan al final de la parte global
    while out and out[-1] == "":
        out.pop()
    missing = [k for k in values if k not in done]
    if missing:
        out.append("")
        out.append("# Aspecto de ombu (extras/boot/install-limine.sh)")
        out += ["%s: %s" % (k, values[k]) for k in missing]
    expected = drop_others(rest) if drop else rest
    new = "\n".join(out) + "\n\n" + expected
    # Garantía: lo que viene después de la parte global no cambió ni un byte (salvo el grupo quitado a pedido)
    if split(new)[1] != expected or (drop and OTHERS in new):
        raise ValueError("el resto de la configuración cambió: no se escribe nada")
    return new


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    wall = args[args.index("--wallpaper") + 1] if "--wallpaper" in args else None
    with open(args[0], encoding="utf-8") as f:
        text = f.read()
    new = retheme(text, wall, "--direct" in args, "--drop-others" in args)
    with open(args[1], "w", encoding="utf-8") as f:
        f.write(new)
    print("listo: %d líneas de aspecto, %d líneas de entradas intactas" % (len(split(new)[0].split("\n")), len(split(new)[1].split("\n"))))


if __name__ == "__main__":
    main()

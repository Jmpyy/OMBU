#!/usr/bin/env python3
"""Crea el tema de iconos "Ombu": Papirus-Dark con todas las carpetas en violeta.

Papirus trae una variante violeta de cada carpeta (folder-violet*.svg) pero el tema usa la
azul por defecto. Este script arma un tema de usuario que hereda Papirus-Dark y reemplaza,
con enlaces simbólicos, cada ícono de carpeta azul por su equivalente violeta.

Necesita: papirus-icon-theme.   Uso: python3 make-ombu-icons.py
Después: icon_theme=Ombu en qt6ct.conf (o el que use tu app).
"""
import glob
import os
import re
import subprocess

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
        violet = os.path.join(os.path.dirname(real), base.replace("-blue", "-violet"))
        if not os.path.exists(violet):
            continue
        os.makedirs(out, exist_ok=True)
        link = os.path.join(out, name)
        if os.path.lexists(link):
            os.remove(link)
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
    f.write("[Icon Theme]\nName=Ombu\nComment=Papirus-Dark con carpetas violeta\n"
            "Inherits=Papirus-Dark\nDirectories=%s\n\n%s" % (",".join(dirs), sections))
subprocess.run(["gtk-update-icon-cache", "-f", "-t", DEST], check=False)
print("Tema Ombu listo: %d íconos en %s" % (links, DEST))

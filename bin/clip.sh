#!/usr/bin/env bash
# Historial del portapapeles: elegís una entrada y se vuelve a copiar.
# Necesita que cliphist esté guardando (lo arranca shell.qml).
choice=$(cliphist list | rofi -dmenu -i -p "Portapapeles") || exit 0
[ -n "$choice" ] && printf '%s' "$choice" | cliphist decode | wl-copy

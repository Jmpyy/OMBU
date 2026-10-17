#!/usr/bin/env bash
# Abre el explorador de archivos en la carpeta de la ventana con foco: si es una terminal,
# la carpeta donde está parado su shell; si no, tu carpeta personal.
pid=$(hyprctl activewindow -j 2>/dev/null | python3 -I -c 'import sys,json; print(json.load(sys.stdin).get("pid",""))' 2>/dev/null)
dir="$HOME"
if [ -n "$pid" ]; then
    # Baja por los procesos hijos hasta el último (el shell o el programa que está corriendo)
    leaf=$pid
    while child=$(pgrep -P "$leaf" | tail -1) && [ -n "$child" ]; do
        leaf=$child
    done
    cwd=$(readlink "/proc/$leaf/cwd" 2>/dev/null)
    [ -d "$cwd" ] && dir=$cwd
fi
exec env QT_QPA_PLATFORMTHEME=qt6ct dolphin --new-window "$dir"

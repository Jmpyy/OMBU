#!/usr/bin/env bash
# Abre el explorador de archivos en la carpeta de la ventana con foco: si es una terminal,
# la carpeta donde está parado su shell; si no, tu carpeta personal. Va al cajón de Dolphin (files.sh):
# si ya está, en una pestaña nueva.
pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty' 2>/dev/null)
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
exec "$(dirname "$0")/files.sh" "$dir"

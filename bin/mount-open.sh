#!/usr/bin/env bash
# Monta una unidad con udisks (sin pedir contraseña para unidades de tu sesión) y la abre en
# el explorador. Uso: mount-open.sh /dev/sdb1
set -u
out=$(udisksctl mount -b "$1") || exit 1
# "Mounted /dev/sdb1 at /run/media/usuario/ETIQUETA."
dir=${out##* at }
dir=${dir%.}
[ -d "$dir" ] && exec env QT_QPA_PLATFORMTHEME=qt6ct dolphin --new-window "$dir"

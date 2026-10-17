#!/usr/bin/env bash
# Guarda el historial del portapapeles (texto e imagen) en cliphist.
# Al arrancar elimina los vigilantes de una ejecución anterior: Quickshell no los cierra
# al reiniciarse y, sin esto, cada reinicio duplicaría las entradas.
pkill -x wl-paste 2>/dev/null

# Al salir, cierra los vigilantes de este script (solo los hijos, no todo el grupo)
trap 'pkill -P $$ 2>/dev/null' EXIT

wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
wait

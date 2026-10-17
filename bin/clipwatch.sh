#!/usr/bin/env bash
# Guarda el historial del portapapeles (texto e imagen) en cliphist, por medio de clipstore.sh.
# Al arrancar elimina los vigilantes de una ejecución anterior: Quickshell no los cierra
# al reiniciarse y, sin esto, cada reinicio duplicaría las entradas.
pkill -x wl-paste 2>/dev/null

# Al salir, cierra los vigilantes de este script (solo los hijos, no todo el grupo)
trap 'pkill -P $$ 2>/dev/null' EXIT

# El historial no sobrevive a la sesión: se vacía la primera vez que arranca el shell en cada
# sesión. La marca vive en la carpeta de ejecución, que se borra al cerrar sesión, así que
# recargar o reiniciar el shell no lo vacía.
marker="${XDG_RUNTIME_DIR:-/tmp}/ombu-clip-session"
if [ ! -e "$marker" ]; then
    cliphist wipe 2>/dev/null
    touch "$marker"
fi

store="$(dirname "$0")/clipstore.sh"
wl-paste --type text --watch "$store" &
wl-paste --type image --watch "$store" &
wait

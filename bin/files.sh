#!/usr/bin/env bash
# Dolphin como cajón (Super+E): vive en el escritorio especial «archivos» y este script lo muestra o lo
# esconde, siempre la misma ventana. Una regla de Hyprland manda ahí las ventanas principales de Dolphin
# (hypr/ombu.lua) y Files.qml saca del cajón las apps que se abren desde él.
#
# Uso: files.sh              muestra o esconde el cajón (lo abre si no hay Dolphin)
#      files.sh CARPETA      abre CARPETA en una pestaña del cajón y lo muestra (files-here.sh)
#      files.sh adopt DIR    lleva la ventana DIR (sin 0x) al escritorio de siempre y esconde el cajón
#      files.sh rest         cierra Dolphin si el cajón está escondido (Files.qml, a los 10 minutos): con
#                            Dolphin y sus procesos de KIO eran ~225 MB. No lo cierra si tiene un diálogo
#                            abierto, porque las copias y movimientos muestran ahí su progreso
set -u

shown=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .specialWorkspace.name')
toggle() { hyprctl dispatch 'hl.dsp.workspace.toggle_special("archivos")' >/dev/null; }
# Mostrar el escritorio especial no le pasa el foco: sin esto, lo que se escribía iba a la ventana de atrás
show() {
    [ "$shown" = special:archivos ] || toggle
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$win\" })" >/dev/null
}

if [ "${1:-}" = adopt ]; then
    addr="0x${2#0x}"
    ws=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .activeWorkspace.id')
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ws\", window = \"address:$addr\" })" >/dev/null
    [ "$shown" = special:archivos ] && toggle
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
    exit 0
fi

if [ "${1:-}" = rest ]; then
    [ "$shown" = special:archivos ] && exit 0
    hyprctl clients -j | jq -e 'any(.[]; .class == "org.kde.dolphin" and (.title | endswith("— Dolphin") | not))' >/dev/null && exit 0
    for p in $(pgrep -x dolphin); do
        svc="org.kde.dolphin-$p"
        for o in $(busctl --user tree --list "$svc" 2>/dev/null | grep -E '^/dolphin/Dolphin_[0-9]+$'); do
            busctl --user call "$svc" "$o" org.kde.dolphin.MainWindow quit >/dev/null 2>&1
        done
    done
    exit 0
fi

dir="${1:-}"
read -r pid win < <(hyprctl clients -j | jq -r '[.[] | select(.class == "org.kde.dolphin" and .workspace.name == "special:archivos")][0] | "\(.pid // "") \(.address // "")"')

# Dolphin se lanza desprendido (setsid -f): con exec, el script esperaba hasta que Dolphin se cerrara
launch() { setsid -f uwsm app -- env QT_QPA_PLATFORMTHEME=qt6ct dolphin "$@" >/dev/null 2>&1; }

if [ -z "$pid" ]; then
    launch ${dir:+"$dir"}
    exit 0
fi

if [ -n "$dir" ]; then
    # En una pestaña nueva del Dolphin que ya está, en vez de sumar otra ventana
    svc="org.kde.dolphin-$pid"
    obj=$(busctl --user tree --list "$svc" 2>/dev/null | grep -E '^/dolphin/Dolphin_[0-9]+$' | head -n 1)
    busctl --user call "$svc" "$obj" org.kde.dolphin.MainWindow openDirectories asb 1 "file://$dir" false >/dev/null 2>&1 ||
        launch --new-window "$dir"
    show
    exit 0
fi

if [ "$shown" = special:archivos ]; then
    toggle
else
    show
fi

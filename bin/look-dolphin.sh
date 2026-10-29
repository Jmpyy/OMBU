#!/usr/bin/env bash
# Espacio en Dolphin: abre la vista rápida (Look.qml) del archivo elegido. El atajo lo pone y lo saca
# Look.qml, y solo existe mientras Dolphin es la ventana activa.
#
# Dolphin no dice por D-Bus qué archivo está elegido, pero sí deja disparar sus acciones: se pone una
# marca en el portapapeles, se dispara «Copiar ubicación» y se lee la ruta. Si la marca sigue ahí no
# había archivo, y el Espacio vuelve a Dolphin como una tecla común. El portapapeles queda como estaba
# y, mientras tanto, el historial (clipstore.sh) está en pausa: ni la marca ni la ruta quedan en él.
#
# Con check solo dice si la ventana activa es una principal de Dolphin (main) o un diálogo (other).
# Hyprland no los distingue (los diálogos también se titulan «… — Dolphin»), pero Dolphin publica sus
# ventanas principales por D-Bus: la activa es principal si su título es el de alguna más « — Dolphin».
# Uso: look-dolphin.sh [check]
set -u

# jq y no python: arrancar python eran 18 de los 23 ms del script, y esto corre con cada Espacio
{ read -r pid addr; IFS= read -r title; } < <(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.pid // 0) \(.address // "")", (.title // "")' 2>/dev/null)
[ -n "${pid:-}" ] && [ "$pid" != 0 ] || { [ "${1:-}" = check ] && echo other; exit 0; }
svc="org.kde.dolphin-$pid"

if [ "${1:-}" = check ]; then
    for o in $(busctl --user tree --list "$svc" 2>/dev/null | grep -E '^/dolphin/Dolphin_[0-9]+$'); do
        t=$(busctl --user get-property "$svc" "$o" org.qtproject.Qt.QWidget windowTitle 2>/dev/null)
        t="${t#s \"}"
        t="${t%\"}"
        if [ "$t — Dolphin" = "$title" ]; then
            echo main
            exit 0
        fi
    done
    echo other
    exit 0
fi

pass() {
    hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"\", key = \"space\", window = \"address:$addr\" })" >/dev/null
    exit 0
}

# La ventana de Dolphin que tiene el foco (puede haber varias en el mismo proceso)
obj=""
for o in $(busctl --user tree --list "$svc" 2>/dev/null | grep -E '^/dolphin/Dolphin_[0-9]+$'); do
    if busctl --user get-property "$svc" "$o" org.qtproject.Qt.QWidget isActiveWindow 2>/dev/null | grep -q true; then
        obj="$o"
        break
    fi
done
[ -n "$obj" ] || pass

run="${XDG_RUNTIME_DIR:-/tmp}"
pause="$run/ombu-clip-paused"
paused_before=0
[ -e "$pause" ] && paused_before=1
touch "$pause"

saved=$(mktemp "$run/ombu-look.XXXXXX")
type=$(wl-paste --list-types 2>/dev/null | head -n 1)
[ -n "$type" ] && wl-paste --no-newline --type "$type" >"$saved" 2>/dev/null

mark="ombu-look-$$-$RANDOM"
# wl-copy se queda en segundo plano sirviendo el portapapeles: sin soltar la salida, quien lea la de
# este script (un pipe) esperaría para siempre
printf '%s' "$mark" | wl-copy >/dev/null 2>&1
busctl --user call "$svc" "$obj" org.kde.KMainWindow activateAction s copy_location >/dev/null 2>&1
path="$mark"
for _ in $(seq 1 25); do
    path=$(wl-paste --no-newline 2>/dev/null)
    [ "$path" != "$mark" ] && break
    sleep 0.02
done
path="${path%%$'\n'*}"

if [ -n "$type" ]; then
    wl-copy --type "$type" <"$saved" >/dev/null 2>&1
else
    wl-copy --clear >/dev/null 2>&1
fi
rm -f -- "$saved"
# La pausa sigue 200 ms, hasta que el vigilante del portapapeles ve lo restaurado, pero en segundo plano:
# la vista no tiene por qué esperarla (eran 200 de los 400 ms del script)
[ $paused_before = 1 ] || (sleep 0.2; rm -f -- "$pause") >/dev/null 2>&1 &

if [ "$path" = "$mark" ] || [ -z "$path" ] || [ ! -e "$path" ]; then
    pass
fi
exec quickshell -c ombu ipc call look file "$path"

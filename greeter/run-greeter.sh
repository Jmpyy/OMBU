#!/bin/sh
# Lo lanza el Hyprland del greeter. Corre la interfaz de ombu y vigila que arranque:
# si en ~20 s no avisa que está lista, la cierra y cierra Hyprland, y ombu-greeter-session
# cae al greeter de Noctalia. Cuando el usuario inicia sesión, la interfaz se cierra sola
# (greetd arranca la sesión) y se cierra también este Hyprland.
SHARE="${OMBU_SHARE:-/usr/share/ombu-greeter}"
RT="${OMBU_GREETER_RT:-/tmp/ombu-greeter}"

rm -f "$RT/ready" "$RT/done"
# El registro de la interfaz queda en $RT/quickshell.log (legible, en /tmp/ombu-greeter): sin esto no queda
# ningún rastro de por qué el greeter se vio de cierta manera
quickshell -p "$SHARE" >"$RT/quickshell.log" 2>&1 &
QS=$!

i=0
while [ "$i" -lt 40 ]; do
    [ -e "$RT/ready" ] && break
    kill -0 "$QS" 2>/dev/null || break
    sleep 0.5
    i=$((i + 1))
done

if [ ! -e "$RT/ready" ]; then
    echo "run-greeter: la interfaz no arrancó" >&2
    kill "$QS" 2>/dev/null
    hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1
    exit 1
fi

wait "$QS"
RC=$?
[ "$RC" -eq 0 ] && touch "$RT/done"
hyprctl dispatch 'hl.dsp.exit()' >/dev/null 2>&1
exit "$RC"

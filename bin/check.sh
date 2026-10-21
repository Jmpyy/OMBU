#!/usr/bin/env bash
# Revisa si ombu cargó bien después de un cambio. Si un .qml tiene un error, Quickshell sigue corriendo la
# versión anterior sin avisar y parece que el cambio «no hizo nada»: esto lo dice en una línea.
# Uso:
#   check.sh       el resultado de la última recarga
#   check.sh -w    espera la próxima recarga (hasta 15 s): correlo apenas guardás un .qml
#   check.sh -r    reinicia ombu y revisa (cuando sigue el mismo error aunque ya lo arreglaste)
# Sale con 0 si cargó limpio, 1 si cargó con avisos y 2 si no cargó.
set -u
cfg=ombu
# Avisos que no son de ombu (Qt, apps por D-Bus) y no se arreglan desde acá
noise='qt\.qpa\.wayland\.textinput|quickshell\.dbus\.properties|Failed to register with host portal'

log() { qs -c "$cfg" log 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g'; }
reloads() { log | grep -cE 'Configuration Loaded|Failed to load configuration'; }

case "${1:-}" in
-w)
    before=$(reloads)
    for _ in {1..30}; do
        sleep 0.5
        [ "$(reloads)" -gt "$before" ] && break
    done
    if [ "$(reloads)" -le "$before" ]; then
        # Quickshell recarga solo si cambia el contenido (un touch no alcanza) y, si el archivo se
        # reemplaza en vez de editarse (sed -i), puede no enterarse hasta la próxima recarga
        echo "No hubo ninguna recarga en 15 s. Quickshell solo recarga si cambió el contenido de un .qml de ombu;"
        echo "si lo reemplazaste (sed -i) puede no haberse enterado: guardalo de nuevo desde el editor."
        exit 1
    fi
    ;;
-r)
    echo "Reiniciando ombu…"
    qs -c "$cfg" kill >/dev/null 2>&1
    sleep 1
    setsid -f quickshell -c "$cfg" -n -d >/dev/null 2>&1
    sleep 4
    ;;
"") ;;
*)
    sed -n '4,8p' "$0"
    exit 1
    ;;
esac

# Solo lo que pasó desde la última recarga (o desde que arrancó)
last=$(log | awk '/Reloading configuration/ { buf = "" } { buf = buf $0 "\n" } END { printf "%s", buf }')

instances=$(qs list --all 2>/dev/null | grep -c '^Instance')
if [ "$instances" -gt 1 ]; then
    echo "⚠ Hay $instances copias de ombu corriendo: pelean por D-Bus y duplican barras (qs list --all)"
fi

if grep -q 'Failed to load configuration' <<<"$last"; then
    echo "✗ La configuración nueva NO cargó: sigue corriendo la anterior."
    echo "  Causa: $(grep 'caused by' <<<"$last" | tail -1 | sed 's/.*caused by //')"
    echo "  (Las líneas «Type X unavailable» del log son el efecto dominó de esa: la última es la real.)"
    echo "  Si ya lo arreglaste y sigue el mismo error, Quickshell quedó con la versión rota en memoria: check.sh -r"
    exit 2
fi

if ! grep -q 'Configuration Loaded' <<<"$last"; then
    echo "Todavía está cargando: probá de nuevo en un segundo."
    exit 1
fi

warns=$(grep -E '^[[:space:]]*(WARN|ERROR)' <<<"$last" | grep -vE "$noise" | sed -E 's/^[[:space:]]*//' | sort | uniq -c | sort -rn)
if [ -z "$warns" ]; then
    echo "✓ Cargó sin errores."
    exit 0
fi
echo "✓ Cargó, pero con avisos (las veces que salió cada uno):"
head -30 <<<"$warns"
exit 1

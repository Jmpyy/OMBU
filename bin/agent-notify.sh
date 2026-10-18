#!/usr/bin/env bash
# Avisa cuando un agente de IA de la terminal (Claude Code, Antigravity) termina una tarea.
# Lo llaman los hooks de cada agente:
#
#   agent-notify.sh claude start|stop     (hooks UserPromptSubmit y Stop de Claude Code)
#   agent-notify.sh agy start|stop        (hooks PreInvocation y Stop de Antigravity)
#
# "start" anota la hora en que arranca el turno; "stop" calcula cuánto tardó.
# Si la terminal no tiene el foco (ej. estás jugando o en otra ventana), avisa siempre
# y permite hacer clic para volver a la consola al instante.
# Si ya tenés la terminal enfrente, solo avisa si tardó OMBU_AGENT_MIN_SECONDS (30 s por defecto).
#
# Nunca debe romper al agente: siempre termina bien y rápido.
agent="${1:-}"
event="${2:-}"
min="${OMBU_AGENT_MIN_SECONDS:-30}"
state="${XDG_RUNTIME_DIR:-/tmp}/ombu-agent-$agent.start"

# Antigravity espera un JSON de salida; Claude Code toma como contexto lo que se imprima
reply() { [ "$agent" = "agy" ] && printf '{}\n'; return 0; }

case "$agent" in
claude) name="Claude Code" ;;
agy) name="Antigravity" ;;
*) exit 0 ;;
esac

payload=$(cat 2>/dev/null)
field() {
    printf '%s' "$payload" | python3 -I -c "import sys,json
try: print(json.load(sys.stdin).get('$1',''))
except Exception: pass" 2>/dev/null
}

now=$(date +%s)
case "$event" in
start)
    # Antigravity llama a PreInvocation antes de cada respuesta del modelo: solo la primera
    # del turno marca el comienzo (las siguientes llegan con invocationNum mayor a 1)
    if [ "$agent" = "agy" ] && [ -e "$state" ]; then
        n=$(field invocationNum)
        [ -n "$n" ] && [ "$n" != "1" ] && { reply; exit 0; }
    fi
    printf '%s\n' "$now" >"$state"
    ;;
stop)
    start=$(cat "$state" 2>/dev/null)
    rm -f "$state"
    reason=$(field terminationReason)
    if [ -n "$start" ] && [ "$reason" != "USER_CANCELED" ]; then
        secs=$((now - start))
        active_class=$(hyprctl activewindow -j 2>/dev/null | python3 -I -c "import sys,json; print(json.load(sys.stdin).get('class',''))" 2>/dev/null)

        # Si no estás en la consola, o si tardó más del mínimo configurado:
        if [ "$active_class" != "kitty" ] || [ "$secs" -ge "$min" ]; then
            if [ "$secs" -ge 60 ]; then
                took="$((secs / 60)) min $((secs % 60)) s"
            else
                took="$secs s"
            fi

            (
                choice=$(notify-send -a "$name" -u normal \
                    -t 8000 \
                    -A "default=Ir a la consola" \
                    -A "focus=Ir a la consola" \
                    "$name terminó" "Tardó $took" 2>/dev/null)
                if [ "$choice" = "default" ] || [ "$choice" = "focus" ]; then
                    hyprctl dispatch 'hl.dsp.focus({ window = "class:kitty" })' >/dev/null 2>&1
                fi
            ) &
        fi
    fi
    ;;
esac
reply
exit 0

#!/usr/bin/env bash
# Avisa cuando un agente de IA de la terminal (Claude Code, Antigravity) termina una tarea larga.
# Lo llaman los hooks de cada agente:
#
#   agent-notify.sh claude start|stop     (hooks UserPromptSubmit y Stop de Claude Code)
#   agent-notify.sh agy start|stop        (hooks PreInvocation y Stop de Antigravity)
#
# "start" anota la hora en que arranca el turno; "stop" calcula cuánto tardó y, si fueron
# OMBU_AGENT_MIN_SECONDS o más (30 por defecto), manda una notificación en español. Si tenés
# una terminal a la vista, ombu la descarta sola (ver NotifRules.qml).
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
        if [ "$secs" -ge "$min" ]; then
            if [ "$secs" -ge 60 ]; then
                took="$((secs / 60)) min $((secs % 60)) s"
            else
                took="$secs s"
            fi
            notify-send -a "$name" -u normal "$name terminó" "Tardó $took" >/dev/null 2>&1 &
        fi
    fi
    ;;
esac
reply
exit 0

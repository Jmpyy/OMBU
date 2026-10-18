#!/usr/bin/env bash
# Pide confirmación interactiva mediante notificación de ombu cuando un agente
# (Antigravity o Claude Code) va a ejecutar un comando y la terminal no tiene el foco.

agent="${1:-agy}"
payload=$(cat 2>/dev/null)

cmd=$(printf '%s' "$payload" | python3 -I -c "
import sys, json
try:
    d = json.load(sys.stdin)
    # Antigravity format
    c = d.get('toolCall', {}).get('args', {}).get('CommandLine')
    if not c:
        # Claude Code format
        c = d.get('tool_input', {}).get('command') or d.get('input', {}).get('command')
    print(c or '')
except Exception:
    print('')
" 2>/dev/null)

case "$agent" in
claude) name="Claude Code" ;;
agy) name="Antigravity" ;;
*) name="Agente IA" ;;
esac

# ¿Tiene la terminal el foco activo ahora mismo?
active_class=$(hyprctl activewindow -j 2>/dev/null | python3 -I -c "
import sys, json
try:
    print(json.load(sys.stdin).get('class', ''))
except Exception:
    print('')
" 2>/dev/null)

# Si el usuario ya está mirando la terminal, dejamos que confirme en la consola
if [ "$active_class" = "kitty" ]; then
    if [ "$agent" = "agy" ]; then
        printf '{"decision": "ask"}\n'
    fi
    exit 0
fi

# Si no hay comando reconocible, dejamos que proceda
if [ -z "$cmd" ]; then
    if [ "$agent" = "agy" ]; then
        printf '{"decision": "allow"}\n'
    fi
    exit 0
fi

short_cmd="$cmd"
if [ ${#short_cmd} -gt 100 ]; then
    short_cmd="${short_cmd:0:97}..."
fi

# Notificación interactiva en ombu con botones de acción (espera hasta 45 segundos)
choice=$(notify-send -a "$name" \
    -u critical \
    -t 45000 \
    -A "allow=✓ Permitir" \
    -A "deny=✗ Denegar" \
    -A "focus=Ir a la consola" \
    "$name · Confirmar comando" \
    "$short_cmd" 2>/dev/null)

case "$choice" in
allow)
    if [ "$agent" = "agy" ]; then
        printf '{"decision": "allow"}\n'
    fi
    exit 0
    ;;
deny)
    if [ "$agent" = "agy" ]; then
        printf '{"decision": "deny", "reason": "Cancelado por el usuario desde la notificación de ombu."}\n'
    fi
    exit 1
    ;;
focus)
    hyprctl dispatch 'hl.dsp.focus({ window = "class:kitty" })' >/dev/null 2>&1
    if [ "$agent" = "agy" ]; then
        printf '{"decision": "ask"}\n'
    fi
    exit 0
    ;;
*)
    # Si expiró o cerró el aviso sin elegir, pide confirmación en la consola
    if [ "$agent" = "agy" ]; then
        printf '{"decision": "ask"}\n'
    fi
    exit 0
    ;;
esac

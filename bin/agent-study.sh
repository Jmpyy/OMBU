#!/usr/bin/env bash
# Modo estudio para la IA: si el modo foco de ombu está en un bloque de estudio, le pasa al agente
# unas reglas para ese bloque. Lo llaman los hooks de Claude Code (UserPromptSubmit) y de
# Antigravity (PreInvocation). Si no hay un bloque de estudio activo, no hace ni dice nada.
# Uso: agent-study.sh claude|agy
set -u
agent="${1:-agy}"
modo="${OMBU_MODO_FILE:-$HOME/.local/state/ombu/modo}"
# Un bloque dura 25 min como mucho: un archivo más viejo que esto quedó de un shell caído
max_age=$((40 * 60))

[ -r "$modo" ] || exit 0
[ "$(cat "$modo")" = "estudio activo" ] || exit 0
age=$(( $(date +%s) - $(stat -c %Y "$modo") ))
[ "$age" -le "$max_age" ] || exit 0

read -r -d '' reglas <<'TXT' || true
MODO ESTUDIO (ombu): Juan está en un bloque de estudio con el temporizador en marcha. Reglas hasta que termine:
1. Ayudá solo con temas de la facultad: programación (sobre todo C), redes, seguridad, matemática, etc.
2. Si pide otra cosa (ideas o trabajo de Plaxia, el consultorio, juegos, mejoras de ombu o del sistema), no la hagas ahora: decile en una frase que está en un bloque de estudio, ofrecé anotar la idea en el cajón (qs -c ombu ipc call focus idea "texto") y volvé al estudio.
3. En lo de estudio, enseñá: explicá el porqué con ejemplos cortos, preguntá qué intentó, dá pistas antes de la solución y, si es un ejercicio de entrega, guiá paso a paso sin dar el código completo.
4. Sin sermones: breve y cálido. Si insiste en dejar el estudio, no discutas: puede pausar el temporizador con el botón de la barra.
TXT

if [ "$agent" = "claude" ]; then
  python3 -I -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":sys.argv[1]}}))' "$reglas"
else
  python3 -I -c 'import json,sys; print(json.dumps({"injectSteps":[{"ephemeralMessage":sys.argv[1]}]}))' "$reglas"
fi

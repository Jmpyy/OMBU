#!/usr/bin/env bash
# Lanza un programa y manda a un monitor la primera ventana NUEVA cuyo título coincida con el patrón.
# Uso: to-monitor.sh PATRON MONITOR SEGUNDOS -- programa [argumentos...]
# Ej.: to-monitor.sh NotebookLM DP-1 25 -- zen-browser --new-window https://notebooklm.google.com
# Las ventanas que ya estaban abiertas no se tocan (se anotan antes de lanzar). Si en ese tiempo no
# aparece ninguna, no hace nada. Lo usa el modo foco (Focus.openTool) para abrir NotebookLM en el TV.
set -uo pipefail

pat="${1:-}" mon="${2:-}" secs="${3:-20}"
shift 3 2>/dev/null || exit 2
[ "${1:-}" = "--" ] && shift
[ -n "$pat" ] && [ -n "$mon" ] && [ $# -gt 0 ] || exit 2

clients() { hyprctl clients -j 2>/dev/null; }
before=$(clients | python3 -I -c 'import json,sys; print(" ".join(c["address"] for c in json.load(sys.stdin)))')

"$@" >/dev/null 2>&1 &
disown

end=$((SECONDS + secs))
while [ "$SECONDS" -lt "$end" ]; do
    addr=$(clients | python3 -I -c '
import json, re, sys
before = set(sys.argv[2].split())
pat = re.compile(sys.argv[1], re.I)
for c in json.load(sys.stdin):
    if c["address"] not in before and pat.search(c.get("title") or ""):
        print(c["address"])
        break' "$pat" "$before")
    if [ -n "$addr" ]; then
        hyprctl dispatch "hl.dsp.window.move({ monitor = \"$mon\", window = \"address:$addr\" })" >/dev/null
        exit 0
    fi
    sleep 0.4
done
exit 1

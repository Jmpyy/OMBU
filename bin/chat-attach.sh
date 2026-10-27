#!/usr/bin/env bash
# Adjuntos del chat del panel lateral (ChatView). Imprime una línea JSON:
#   chat-attach.sh clip       lo que hay en el portapapeles: texto ({kind: "text"}) o imagen ({kind: "image"})
#   chat-attach.sh shot       elegís una región de la pantalla ({kind: "image"})
#   chat-attach.sh file DIR   elegís un archivo con zenity, empezando en DIR ({kind: "file"})
# Si se cancela: {"kind": "none"}. Si falla: {"error": "..."}.
# Las imágenes quedan en $XDG_RUNTIME_DIR/ombu-chat (memoria, se borra al cerrar sesión); el chat le
# pasa esa carpeta al agente con --add-dir para que pueda leerlas.
set -uo pipefail

dir="${XDG_RUNTIME_DIR:-/tmp}/ombu-chat"
mkdir -p "$dir" && chmod 700 "$dir"
stamp=$(date +%H%M%S)

json() { python3 -I -c 'import json,sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2])), ensure_ascii=False))' "$@"; }

case "${1:-}" in
clip)
    types=$(timeout 2 wl-paste --list-types 2>/dev/null)
    if printf '%s\n' "$types" | grep -q '^image/png$'; then
        out="$dir/portapapeles-$stamp.png"
        timeout 3 wl-paste --type image/png >"$out" 2>/dev/null && [ -s "$out" ] ||
            { json error "No se pudo leer la imagen del portapapeles"; exit 0; }
        json kind image label "Imagen del portapapeles" path "$out"
        exit 0
    fi
    text=$(timeout 2 wl-paste --no-newline --type text 2>/dev/null)
    [ -n "$text" ] || { json error "El portapapeles está vacío"; exit 0; }
    # Tope de 20 000 caracteres: más que eso es pegar un archivo entero (para eso, adjuntá el archivo)
    printf '%s' "$text" | python3 -I -c '
import json, sys
t = sys.stdin.read()
cut = len(t) > 20000
t = t[:20000]
lines = t.count("\n") + 1
label = "Portapapeles · " + (str(lines) + " líneas" if lines > 1 else str(len(t)) + " caracteres") + (" (recortado)" if cut else "")
print(json.dumps({"kind": "text", "label": label, "text": t}, ensure_ascii=False))'
    ;;
shot)
    # Espera a que se cierre el panel para que no salga en la captura
    sleep 0.35
    geo=$(timeout 30 slurp 2>/dev/null) || { json kind none; exit 0; }
    out="$dir/captura-$stamp.png"
    timeout 5 grim -g "$geo" "$out" 2>/dev/null && [ -s "$out" ] || { json error "No se pudo capturar"; exit 0; }
    json kind image label "Captura" path "$out"
    ;;
file)
    start="${2:-$HOME}"
    path=$(cd "$start" 2>/dev/null && timeout 300 zenity --file-selection --title="Adjuntar al chat" --filename="$start/" 2>/dev/null) ||
        { json kind none; exit 0; }
    [ -f "$path" ] || { json kind none; exit 0; }
    json kind file label "$(basename "$path")" path "$path"
    ;;
*)
    json error "uso: chat-attach.sh clip|shot|file DIR"
    ;;
esac

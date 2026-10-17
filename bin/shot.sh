#!/usr/bin/env bash
# Capturas de pantalla. Modos:
#   edit    elegís una región y se abre el editor (anotar, recortar); Enter copia y guarda  [Print]
#   quick   elegís una región y se guarda y copia directo                                  [Shift+Print]
#   full    el monitor con foco, directo                                                   [Super+Print]
#   ocr     elegís una región y el texto que contiene queda en el portapapeles             [Ctrl+Print]
#
# Guarda en ~/Pictures/Screenshots, copia al portapapeles y avisa con una miniatura: clic en el
# aviso la abre en el editor, "Borrar" la manda a la papelera.
#
# Ojo: en esta PC grim se cuelga al capturar el monitor DP-2 (HDMI-A-1 anda bien).
# Por eso todo va con un límite de tiempo y, si falla, avisa en vez de quedarse trabado.
set -uo pipefail

dir="$HOME/Pictures/Screenshots"
tmp="${XDG_RUNTIME_DIR:-/tmp}"
mkdir -p "$dir"
file="$dir/captura-$(date +%Y-%m-%d_%H-%M-%S).png"
raw=""

cleanup() { rm -f "$raw" "${raw:+$raw.pre.png}"; }
trap cleanup EXIT

say() { notify-send -a "Capturas" "$@" >/dev/null 2>&1; }

fail() {
    rm -f "$file"
    say -u critical "No se pudo capturar" "$1"
    exit 1
}

# Abre una captura ya guardada en el editor
edit_file() {
    satty --filename "$1" --output-filename "$1" >/dev/null 2>&1
}

# Aviso con miniatura. Corre en segundo plano para no trabar el atajo:
# clic = editar, "Borrar" = papelera.
announce() {
    local f="$1"
    (
        choice=$(notify-send -a "Capturas" -i "$f" -A "default=Editar" -A "borrar=Borrar" --wait \
            "Captura guardada" "$(basename "$f") · copiada al portapapeles" 2>/dev/null)
        case "$choice" in
        default) command -v satty >/dev/null && edit_file "$f" ;;
        borrar) gio trash "$f" && say "Captura movida a la papelera" ;;
        esac
    ) >/dev/null 2>&1 &
    disown
}

# Elegir un área con el mouse; Esc cancela y no se hace nada
pick_area() { slurp -d || exit 0; }

grab_region() {
    local area
    area=$(pick_area) || exit 0
    timeout 8 grim -g "$area" "$1" || fail "grim no respondió (¿el área incluye el monitor DP-2?)"
}

case "${1:-edit}" in
edit)
    if ! command -v satty >/dev/null; then
        say "Falta el editor" "Instalá satty para anotar capturas; se guarda sin editar."
        exec "$0" quick
    fi
    raw=$(mktemp -p "$tmp" shot-XXXXXX.png)
    grab_region "$raw"
    # satty guarda en $file al copiar; si se cierra con Esc no queda nada
    satty --filename "$raw" --output-filename "$file" >/dev/null 2>&1
    [ -s "$file" ] || exit 0
    announce "$file"
    ;;
quick)
    grab_region "$file"
    wl-copy <"$file"
    announce "$file"
    ;;
full)
    monitor=$(hyprctl monitors -j | python3 -I -c "import sys,json; print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))")
    timeout 8 grim -o "$monitor" "$file" || fail "grim no respondió en $monitor"
    wl-copy <"$file"
    announce "$file"
    ;;
ocr)
    if ! command -v tesseract >/dev/null; then
        say "Falta tesseract" "Instalá tesseract y tesseract-data-spa para copiar texto de una imagen."
        exit 1
    fi
    raw=$(mktemp -p "$tmp" ocr-XXXXXX.png)
    grab_region "$raw"
    # Se agranda y se pasa a grises: el texto chico de pantalla se lee mucho mejor
    magick "$raw" -resize 250% -colorspace Gray -normalize -sharpen 0x1 "$raw.pre.png" 2>/dev/null || cp "$raw" "$raw.pre.png"
    langs="eng"
    tesseract --list-langs 2>/dev/null | grep -qx spa && langs="spa+eng"
    text=$(tesseract "$raw.pre.png" stdout -l "$langs" --psm 6 2>/dev/null | sed 's/[[:space:]]*$//')
    if [ -z "$(printf '%s' "$text" | tr -d '[:space:]')" ]; then
        say "Sin texto" "No encontré texto en esa zona."
        exit 0
    fi
    printf '%s' "$text" | wl-copy
    preview=$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-110)
    say "Texto copiado" "$preview"
    ;;
*)
    echo "uso: shot.sh edit|quick|full|ocr" >&2
    exit 1
    ;;
esac

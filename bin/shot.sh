#!/usr/bin/env bash
# Capturas de pantalla: "region" (elegís el área) o "full" (el monitor con foco).
# Guarda el archivo en ~/Pictures/Screenshots, lo copia al portapapeles y avisa.
#
# Ojo: en esta PC grim se cuelga al capturar el monitor DP-2 (HDMI-A-1 anda bien).
# Por eso todo va con un límite de tiempo y, si falla, avisa en vez de quedarse trabado.
set -uo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/captura-$(date +%Y-%m-%d_%H-%M-%S).png"

fail() {
    rm -f "$file"
    notify-send -u critical -a "Capturas" "No se pudo capturar" "$1"
    exit 1
}

case "${1:-region}" in
region)
    # Esc cancela la selección y no se hace nada
    area=$(slurp -d) || exit 0
    timeout 8 grim -g "$area" "$file" || fail "grim no respondió (¿el área incluye el monitor DP-2?)"
    ;;
full)
    monitor=$(hyprctl monitors -j | python3 -I -c "import sys,json; print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))")
    timeout 8 grim -o "$monitor" "$file" || fail "grim no respondió en $monitor"
    ;;
*)
    echo "uso: shot.sh region|full" >&2
    exit 1
    ;;
esac

wl-copy <"$file"
notify-send -a "Capturas" -i "$file" "Captura guardada" "$(basename "$file") · copiada al portapapeles"

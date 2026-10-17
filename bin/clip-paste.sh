#!/usr/bin/env bash
# Pone una entrada del historial (o un texto fijado) en el portapapeles y, si se pide, la pega
# en la ventana que tenía el foco.
#   clip-paste.sh paste|copy entry ID        una entrada del historial de cliphist
#   clip-paste.sh paste|copy text "texto"    un texto fijado
mode="${1:-paste}"
kind="${2:-}"
value="${3:-}"

# Deja que el menú suelte el teclado y el foco vuelva a la ventana de antes
sleep 0.18

case "$kind" in
entry) cliphist decode "$value" | wl-copy ;;
text) printf '%s' "$value" | wl-copy ;;
*) exit 1 ;;
esac

[ "$mode" = "paste" ] || exit 0
sleep 0.08

# Las terminales pegan con Ctrl+Shift+V; el resto de las apps con Ctrl+V
class=$(hyprctl activewindow -j 2>/dev/null | python3 -I -c 'import sys,json
try: print(json.load(sys.stdin).get("class",""))
except Exception: pass' 2>/dev/null)
case "${class,,}" in
kitty | alacritty | foot | footclient | konsole | org.kde.konsole | com.mitchellh.ghostty | org.wezfurlong.wezterm | xterm | *terminal*) mods="CTRL SHIFT" ;;
*) mods="CTRL" ;;
esac
hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"$mods\", key = \"V\", window = \"activewindow\" })" >/dev/null 2>&1

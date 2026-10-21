#!/usr/bin/env bash
# Guarda en cliphist lo que se acaba de copiar (llega por stdin; lo llama wl-paste --watch).
# No guarda nada si el historial está en pausa o si la app marcó lo copiado como sensible
# (los gestores de contraseñas lo hacen con el tipo x-kde-passwordManagerHint).
[ -e "${XDG_RUNTIME_DIR:-/tmp}/ombu-clip-paused" ] && exit 0
# wl-paste ya avisa en el entorno si lo copiado es sensible (o si se vació el portapapeles)
case "${CLIPBOARD_STATE:-}" in sensitive | clear) exit 0 ;; esac
wl-paste --list-types 2>/dev/null | grep -qx "x-kde-passwordManagerHint" && exit 0
exec cliphist -max-items 100 store

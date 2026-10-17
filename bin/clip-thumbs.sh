#!/usr/bin/env bash
# Prepara las miniaturas de las imágenes del historial: decodifica cada entrada que todavía no
# tenga archivo en la carpeta de caché. Uso: clip-thumbs.sh ID [ID...]
dir="${XDG_RUNTIME_DIR:-/tmp}/ombu-clip"
mkdir -p "$dir"
for id in "$@"; do
    [ -s "$dir/$id.png" ] || cliphist decode "$id" >"$dir/$id.png" 2>/dev/null
done

#!/usr/bin/env bash
# Vista previa de un archivo para el launcher (estilo Quick Look). Imprime el tipo en la primera
# línea y lo que hay que mostrar en las siguientes:
#   image   la ruta de la imagen (las páginas de un PDF se convierten a imagen)
#   text    las primeras líneas del archivo
#   dir     lo que tiene la carpeta
#   other   el tipo MIME y el tamaño en bytes
#   none    el archivo no existe
# Uso: ql.sh RUTA
f="${1:-}"
[ -n "$f" ] && [ -e "$f" ] || { echo none; exit 0; }

if [ -d "$f" ]; then
    echo dir
    ls -1A -- "$f" 2>/dev/null | head -40
    exit 0
fi

mime=$(file -b --mime-type -- "$f" 2>/dev/null)
case "$mime" in
image/*)
    echo image
    echo "$f"
    ;;
application/pdf)
    out="${XDG_RUNTIME_DIR:-/tmp}/ombu-ql"
    mkdir -p "$out"
    rm -f "$out"/page-*.png
    stamp=$(date +%s%N)
    if pdftoppm -png -singlefile -r 70 -f 1 -l 1 -- "$f" "$out/page-$stamp" 2>/dev/null; then
        echo image
        echo "$out/page-$stamp.png"
    else
        echo other
        echo "$mime"
        stat -c '%s' -- "$f"
    fi
    ;;
text/* | application/json | application/xml | application/javascript | application/x-shellscript | application/x-subrip | inode/x-empty)
    echo text
    head -c 8000 -- "$f" 2>/dev/null | head -n 60
    ;;
*)
    echo other
    echo "$mime"
    stat -c '%s' -- "$f" 2>/dev/null
    ;;
esac

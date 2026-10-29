#!/usr/bin/env bash
# Vista previa de un archivo para el launcher (estilo Quick Look). Imprime el tipo en la primera
# línea y lo que hay que mostrar en las siguientes:
#   image   la ruta de la imagen (las páginas de un PDF se convierten a imagen)
#   text    las primeras líneas del archivo
#   dir     lo que tiene la carpeta
#   other   el tipo MIME y el tamaño en bytes
#   none    el archivo no existe
# Con full (la vista rápida a pantalla completa, Look.qml) cambia lo que sale:
#   pdf     la imagen de la página pedida en grande y la cantidad de páginas (solo con la página 1)
#   video   la ruta (la reproduce Look.qml)
#   audio   la ruta
#   text    hasta 3000 líneas en vez de 60
# Uso: ql.sh RUTA [full [PÁGINA]]
f="${1:-}"
full=0
[ "${2:-}" = full ] && full=1
page="${3:-1}"
case "$page" in '' | *[!0-9]*) page=1 ;; esac
[ -n "$f" ] && [ -e "$f" ] || { echo none; exit 0; }

if [ -d "$f" ]; then
    echo dir
    ls -1A -- "$f" 2>/dev/null | head -n $((full ? 400 : 40))
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
    if [ $full = 1 ]; then
        mkdir -p "$out"
        rm -f "$out"/look-*.png
        stamp=$(date +%s%N)
        # Las páginas se cuentan solo al abrirlo (página 1): al pasar de página Look ya las sabe
        pages=""
        [ "$page" = 1 ] && pages=$(pdfinfo -- "$f" 2>/dev/null | awk '/^Pages:/{print $2}')
        if pdftoppm -png -singlefile -scale-to 1800 -f "$page" -l "$page" -- "$f" "$out/look-$stamp" 2>/dev/null; then
            echo pdf
            echo "$out/look-$stamp.png"
            echo "$pages"
            exit 0
        fi
    fi
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
video/* | audio/*)
    if [ $full = 1 ]; then
        echo "${mime%%/*}"
        echo "$f"
    else
        echo other
        echo "$mime"
        stat -c '%s' -- "$f" 2>/dev/null
    fi
    ;;
text/* | application/json | application/xml | application/javascript | application/x-shellscript | application/x-subrip | inode/x-empty)
    echo text
    if [ $full = 1 ]; then
        head -c 200000 -- "$f" 2>/dev/null | head -n 3000
    else
        head -c 8000 -- "$f" 2>/dev/null | head -n 60
    fi
    ;;
*)
    echo other
    echo "$mime"
    stat -c '%s' -- "$f" 2>/dev/null
    ;;
esac

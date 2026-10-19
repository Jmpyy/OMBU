#!/bin/sh
# Feriados de Argentina de un año, en JSON ([{date, localName}]). Se bajan una vez de la API
# pública de Nager.Date y se guardan en ~/.cache/ombu; si no hay red y no hay copia, sale [].
# Uso: feriados.sh AÑO
year=${1:?uso: feriados.sh AÑO}
dir=${XDG_CACHE_HOME:-$HOME/.cache}/ombu
file=$dir/feriados-$year.json
mkdir -p "$dir"
if [ ! -s "$file" ]; then
    tmp=$(mktemp)
    if curl -fsS -m 15 "https://date.nager.at/api/v3/PublicHolidays/$year/AR" -o "$tmp" && grep -q '"date"' "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
    fi
fi
[ -s "$file" ] && cat "$file" || echo "[]"

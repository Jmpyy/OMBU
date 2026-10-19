#!/usr/bin/env bash
# Vuelve el menú de arranque de Limine a como estaba antes de ombu (usa limine.conf.pre-ombu) y borra el
# fondo de ombu. Necesita root:
#
#     sudo bash ~/.config/quickshell/ombu/extras/boot/uninstall-limine.sh
set -euo pipefail

ESP="$(sed -n 's/^ESP_PATH="\(.*\)"/\1/p' /etc/default/limine 2>/dev/null | head -1)"
ESP="${ESP:-/boot}"
CONF="$ESP/limine.conf"
[ "$(id -u)" -eq 0 ] || { echo "Hace falta root: sudo bash $0" >&2; exit 1; }
[ -f "$CONF.pre-ombu" ] || { echo "No encuentro $CONF.pre-ombu: no hay nada que restaurar." >&2; exit 1; }

cp "$CONF.pre-ombu" "$CONF"
sync
limine-enroll-config
rm -f "$ESP/limine-ombu.jpg"
echo "Listo: el menú de arranque volvió a como estaba (desde el próximo arranque)."
echo "Ojo: si desde entonces se actualizó un kernel, las entradas de $CONF.pre-ombu pueden estar viejas;"
echo "  corré 'sudo limine-update' (o reinstalá el kernel) para regenerarlas."

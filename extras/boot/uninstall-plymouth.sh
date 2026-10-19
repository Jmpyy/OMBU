#!/usr/bin/env bash
# Vuelve a otro tema de Plymouth (por defecto, el de CachyOS) y borra el de ombu. Necesita root:
#
#     sudo bash ~/.config/quickshell/ombu/extras/boot/uninstall-plymouth.sh [TEMA]
set -euo pipefail

BACK="${1:-cachyos-bootanimation}"
THEMES="${OMBU_PLYMOUTH_DIR:-/usr/share/plymouth/themes}"
[ "$(id -u)" -eq 0 ] || { echo "Hace falta root: sudo bash $0" >&2; exit 1; }
[ -d "$THEMES/$BACK" ] || { echo "No existe el tema $BACK en $THEMES. Temas disponibles:" >&2; ls "$THEMES" >&2; exit 1; }

echo "Volviendo a $BACK y reconstruyendo el initramfs (un minuto, no lo interrumpas)..."
plymouth-set-default-theme -R "$BACK"
rm -rf "$THEMES/ombu-spidey"
echo "Listo: tema $BACK activo desde el próximo arranque."

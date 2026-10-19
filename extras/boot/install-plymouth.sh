#!/usr/bin/env bash
# Instala la intro de arranque de ombu (tema de Plymouth «ombu-spidey»). Necesita root:
#
#     sudo bash ~/.config/quickshell/ombu/extras/boot/install-plymouth.sh
#
# Qué hace (y nada más):
#   1. Genera el tema con tu usuario (make-plymouth.py) en una carpeta temporal y lo comprueba.
#   2. Lo copia a /usr/share/plymouth/themes/ombu-spidey.
#   3. Lo deja como tema por defecto y reconstruye el initramfs (`plymouth-set-default-theme -R`),
#      que tarda un minuto: no lo interrumpas.
#
# NO reinicia nada. La intro nueva se ve en el próximo arranque. Para volver atrás:
# extras/boot/uninstall-plymouth.sh. Con OMBU_INSTALL_TEST=1 solo genera y comprueba el tema (sin root).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
THEME=ombu-spidey
DEST="${OMBU_PLYMOUTH_DIR:-/usr/share/plymouth/themes}/$THEME"
TEST="${OMBU_INSTALL_TEST:-0}"

if [ "$TEST" != "1" ] && [ "$(id -u)" -ne 0 ]; then
    echo "Hace falta root: sudo bash $0" >&2
    exit 1
fi
USERNAME="${SUDO_USER:-$(id -un)}"
[ "$TEST" = "1" ] && USERNAME="$(id -un)"
[ -n "$USERNAME" ] && [ "$USERNAME" != "root" ] || { echo "Ejecutalo con sudo desde tu cuenta, no como root directo." >&2; exit 1; }
for cmd in magick python3 plymouth-set-default-theme; do
    command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
chmod 755 "$STAGE"
# La carpeta la crea root: el tema se genera con tu usuario, así que tiene que poder escribir ahí
[ "$TEST" = "1" ] || chown "$USERNAME" "$STAGE"

echo "Generando el tema (unos segundos)..."
if [ "$TEST" = "1" ]; then
    python3 -I "$HERE/make-plymouth.py" "$STAGE/$THEME" >/dev/null
else
    runuser -u "$USERNAME" -- python3 -I "$HERE/make-plymouth.py" "$STAGE/$THEME" >/dev/null
fi

# Comprobaciones: el archivo del tema y los cuadros tienen que estar completos
[ -f "$STAGE/$THEME/$THEME.plymouth" ] || { echo "Falta $THEME.plymouth: no se tocó nada." >&2; exit 1; }
loop=$(ls "$STAGE/$THEME"/throbber-*.png 2>/dev/null | wc -l)
end=$(ls "$STAGE/$THEME"/animation-*.png 2>/dev/null | wc -l)
[ "$loop" -ge 10 ] && [ "$end" -ge 10 ] || { echo "Faltan cuadros ($loop de bucle, $end finales): no se tocó nada." >&2; exit 1; }
grep -q "^ModuleName=two-step" "$STAGE/$THEME/$THEME.plymouth"
echo "Tema listo: $loop cuadros de bucle y $end finales."
if [ "$TEST" = "1" ]; then
    echo "Modo de prueba: no se instaló nada. Tema generado en $STAGE/$THEME (se borra al terminar)."
    exit 0
fi

PREVIOUS="$(plymouth-set-default-theme 2>/dev/null || true)"
echo "Tema actual: ${PREVIOUS:-desconocido}"

install -d -m 755 "$DEST"
cp -a "$STAGE/$THEME"/. "$DEST"/
chown -R root:root "$DEST"
chmod -R a+rX "$DEST"
echo "Copiado a $DEST"

echo "Reconstruyendo el initramfs (un minuto, no lo interrumpas)..."
plymouth-set-default-theme -R "$THEME"

echo
echo "Listo. La intro nueva se ve en el PRÓXIMO arranque (no se reinició nada)."
echo "Para volver al tema anterior ($PREVIOUS):  sudo bash $HERE/uninstall-plymouth.sh $PREVIOUS"

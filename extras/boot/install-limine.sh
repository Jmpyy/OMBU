#!/usr/bin/env bash
# Pone el aspecto de ombu (fondo de Spider-Man, paleta roja, marca «OMBU») en el menú de arranque de Limine.
# Necesita root:
#
#     sudo bash ~/.config/quickshell/ombu/extras/boot/install-limine.sh
#
# Qué hace (y nada más):
#   1. Genera el fondo (limine-ombu.jpg) con tu usuario a partir del fondo de pantalla elegido.
#   2. Guarda una copia de /boot/limine.conf (limine.conf.pre-ombu, la primera vez, y limine.conf.ultima
#      en cada corrida).
#   3. Cambia SOLO las opciones de aspecto de la parte de arriba de limine.conf (limine-theme.py); las
#      entradas de kernel, Windows y las instantáneas quedan idénticas, y se comprueba antes de escribir.
#   4. Vuelve a registrar el hash de la configuración (limine-enroll-config), porque Limine lo verifica.
#   5. Si ese paso FALLA, restaura limine.conf y vuelve a registrar el hash original.
#
# NO reinicia. Se ve en el próximo arranque. Para volver atrás: extras/boot/uninstall-limine.sh.
# Si Limine no arrancara: el menú de la placa madre (F12, F8 o Esc al encender) permite elegir
# «UEFI OS» / el cargador de respaldo (EFI/BOOT/BOOTX64.EFI), que no verifica la configuración.
# Con OMBU_INSTALL_TEST=1 y OMBU_ESP=CARPETA (con un limine.conf adentro) prueba todo sin root ni hash.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TEST="${OMBU_INSTALL_TEST:-0}"
ESP="${OMBU_ESP:-}"
if [ -z "$ESP" ]; then
    ESP="$(sed -n 's/^ESP_PATH="\(.*\)"/\1/p' /etc/default/limine 2>/dev/null | head -1)"
    ESP="${ESP:-/boot}"
fi
CONF="$ESP/limine.conf"
WALL_NAME="limine-ombu.jpg"

if [ "$TEST" != "1" ] && [ "$(id -u)" -ne 0 ]; then
    echo "Hace falta root: sudo bash $0" >&2
    exit 1
fi
USERNAME="${SUDO_USER:-$(id -un)}"
[ "$TEST" = "1" ] && USERNAME="$(id -un)"
[ -n "$USERNAME" ] && [ "$USERNAME" != "root" ] || { echo "Ejecutalo con sudo desde tu cuenta, no como root directo." >&2; exit 1; }
USERHOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
for cmd in magick python3; do
    command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done
if [ "$TEST" != "1" ]; then
    command -v limine-enroll-config >/dev/null || { echo "Falta limine-enroll-config." >&2; exit 1; }
    command -v limine >/dev/null || { echo "Falta el comando limine." >&2; exit 1; }
fi
[ -f "$CONF" ] || { echo "No encuentro $CONF" >&2; exit 1; }
echo "Configuración: $CONF"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
chmod 755 "$STAGE"
[ "$TEST" = "1" ] || chown "$USERNAME" "$STAGE"

# --- 1. fondo ---------------------------------------------------------------------------------
WALL_SRC="$(python3 -I - "$USERHOME" <<'PYEOF'
import json, os, sys
try:
    print(json.load(open(os.path.join(sys.argv[1], ".local/share/ombu/fondo.json"))).get("path", ""))
except Exception:
    print("")
PYEOF
)"
[ -n "$WALL_SRC" ] && [ -f "$WALL_SRC" ] || { echo "No encuentro el fondo de pantalla elegido en ombu ($WALL_SRC)." >&2; exit 1; }
echo "Generando el fondo desde: $(basename "$WALL_SRC")"
MAKE_WALL=(magick "$WALL_SRC" -resize 1920x1080^ -gravity center -extent 1920x1080 -blur 0x1.2 -fill "#0a0708" -colorize 62%
    -sampling-factor 4:2:0 -quality 82 -interlace none "$STAGE/$WALL_NAME")
if [ "$TEST" = "1" ]; then "${MAKE_WALL[@]}"; else runuser -u "$USERNAME" -- "${MAKE_WALL[@]}"; fi
[ -s "$STAGE/$WALL_NAME" ] || { echo "No se pudo generar el fondo: no se tocó nada." >&2; exit 1; }

# --- 2 y 3. configuración nueva (se arma aparte y se comprueba antes de tocar nada) --------------
python3 -I "$HERE/limine-theme.py" "$CONF" "$STAGE/limine.conf" --wallpaper "boot():/$WALL_NAME"
grep -q "^/+CachyOS\|^/CachyOS\|^/" "$STAGE/limine.conf" || { echo "La configuración nueva no tiene entradas: no se tocó nada." >&2; exit 1; }

[ -e "$CONF.pre-ombu" ] || { cp -a "$CONF" "$CONF.pre-ombu"; echo "Copia original: $CONF.pre-ombu"; }
cp -a "$CONF" "$CONF.ultima"
install -m 644 "$STAGE/$WALL_NAME" "$ESP/$WALL_NAME"
cp "$STAGE/limine.conf" "$CONF"
sync
echo "Aspecto escrito en $CONF"

# --- 4 y 5. hash de la configuración --------------------------------------------------------------
if [ "$TEST" = "1" ]; then
    echo "Modo de prueba: no se registró el hash (en la instalación real se hace acá)."
    exit 0
fi
echo "Registrando el hash de la configuración..."
if ! limine-enroll-config; then
    echo "FALLÓ el registro del hash: restauro la configuración anterior." >&2
    cp "$CONF.ultima" "$CONF"
    sync
    limine-enroll-config || echo "ATENCIÓN: tampoco se pudo volver a registrar el hash original. Antes de reiniciar, corré: sudo limine-enroll-config" >&2
    exit 1
fi

echo
echo "Listo. El menú nuevo se ve en el PRÓXIMO arranque (no se reinició nada)."
echo "Para volver atrás:  sudo bash $HERE/uninstall-limine.sh"

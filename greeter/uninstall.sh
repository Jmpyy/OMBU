#!/usr/bin/env bash
# Vuelve al greeter de Noctalia: restaura la configuración original de greetd y borra los
# archivos del greeter de ombu. No reinicia greetd: el cambio se ve en el próximo inicio de
# sesión.
#
#     sudo bash ~/.config/quickshell/ombu/greeter/uninstall.sh
set -euo pipefail

SHARE="${OMBU_SHARE:-/usr/share/ombu-greeter}"
BIN="${OMBU_BIN:-/usr/local/bin/ombu-greeter-session}"
GREETD_CONF="${OMBU_GREETD_CONF:-/etc/greetd/config.toml}"
TEST="${OMBU_INSTALL_TEST:-0}"

if [ "$TEST" != "1" ] && [ "$(id -u)" -ne 0 ]; then
    echo "Hace falta root: sudo bash $0" >&2
    exit 1
fi

if [ -e "$GREETD_CONF.noctalia-backup" ]; then
    cp -a "$GREETD_CONF.noctalia-backup" "$GREETD_CONF"
    echo "Restaurado $GREETD_CONF desde la copia de seguridad."
else
    echo "No hay copia de seguridad ($GREETD_CONF.noctalia-backup); la configuración de greetd no se tocó." >&2
fi

rm -rf "$SHARE"
rm -f "$BIN"
# Sin intro en el login, la bienvenida de ombu vuelve a reproducirla después de la contraseña
USERNAME="${OMBU_USER:-${SUDO_USER:-$(logname 2>/dev/null || id -un)}}"
USERHOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
[ -n "$USERHOME" ] && rm -f "$USERHOME/.local/share/ombu/intro-en-login"
echo "Archivos del greeter de ombu borrados. La copia de seguridad se conserva por si hace falta."

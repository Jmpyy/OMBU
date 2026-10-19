#!/usr/bin/env bash
# Instala el greeter de ombu en greetd. Necesita root:
#
#     sudo bash ~/.config/quickshell/ombu/greeter/install.sh
#
# Qué hace (y nada más):
#   1. Arma el greeter y genera su configuración de Hyprland con tu teclado y tu monitor
#      principal.
#   2. Comprueba que esa configuración sea válida. Si no lo es, se detiene SIN haber tocado
#      nada del sistema.
#   3. Copia el greeter a /usr/share/ombu-greeter y el script de sesión a /usr/local/bin.
#   4. Guarda una copia de /etc/greetd/config.toml (config.toml.noctalia-backup) y cambia
#      solo el comando del greeter.
#
# NO reinicia greetd: tu sesión actual sigue intacta. El cambio se ve en el próximo inicio
# de sesión (cerrar sesión o reiniciar). Para volver atrás: greeter/uninstall.sh.
# Si el greeter de ombu fallara al arrancar, ombu-greeter-session usa el de Noctalia solo.
set -euo pipefail

SHARE="${OMBU_SHARE:-/usr/share/ombu-greeter}"
BIN="${OMBU_BIN:-/usr/local/bin/ombu-greeter-session}"
GREETD_CONF="${OMBU_GREETD_CONF:-/etc/greetd/config.toml}"
TEST="${OMBU_INSTALL_TEST:-0}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "$TEST" != "1" ] && [ "$(id -u)" -ne 0 ]; then
    echo "Hace falta root: sudo bash $0" >&2
    exit 1
fi

# Usuario que va a iniciar sesión: quien ejecutó sudo
USERNAME="${OMBU_USER:-${SUDO_USER:-$(logname 2>/dev/null || id -un)}}"
if [ -z "$USERNAME" ] || [ "$USERNAME" = "root" ]; then
    echo "No pude determinar el usuario (¿ejecutaste con sudo desde tu cuenta?)" >&2
    exit 1
fi
USERHOME="$(getent passwd "$USERNAME" | cut -d: -f6)"

for cmd in quickshell Hyprland start-hyprland python3; do
    command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done
[ -f "$GREETD_CONF" ] || { echo "No encuentro $GREETD_CONF" >&2; exit 1; }

# Si el greeter de ombu no arranca, ombu-greeter-session cae a este otro. Sin él no habría
# pantalla de ingreso: avisa y se detiene salvo que lo confirmes con OMBU_NO_FALLBACK=1.
FALLBACK="${OMBU_GREETER_FALLBACK:-/usr/bin/noctalia-greeter-session}"
if [ ! -x "$FALLBACK" ] && [ "${OMBU_NO_FALLBACK:-0}" != "1" ]; then
    echo "No encuentro el greeter de respaldo ($FALLBACK)." >&2
    echo "Si el greeter de ombu fallara, no tendrías pantalla de ingreso (solo la consola, Ctrl+Alt+F2)." >&2
    echo "Instalá uno de respaldo, indicá otro con OMBU_GREETER_FALLBACK=/ruta, o seguí igual con OMBU_NO_FALLBACK=1." >&2
    exit 1
fi

echo "Usuario: $USERNAME | configuración de greetd: $GREETD_CONF"

# --- 1. armar y configurar ----------------------------------------------------------------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
chmod 755 "$STAGE"
OMBU_SHARE="$SHARE" OMBU_THEME_HOME="$USERHOME" bash "$HERE/build.sh" "$STAGE"

# Teclado y monitor principal se toman de tu configuración de Hyprland
GREETER_USER="$USERNAME" python3 - "$USERHOME" "$STAGE" "$SHARE" <<'PYEOF'
import re, sys, os
home, stage, share = sys.argv[1:4]

def read(path):
    try:
        return open(path).read()
    except OSError:
        return ""

inputs = read(os.path.join(home, ".config/hypr/config/inputs.lua"))
layout = (re.search(r'kb_layout\s*=\s*"([^"]*)"', inputs) or [None, "us"])[1]
options = (re.search(r'kb_options\s*=\s*"([^"]*)"', inputs) or [None, ""])[1]

variables = read(os.path.join(home, ".config/hypr/config/variables.lua"))
primary = ""
m = re.search(r'PRIMARY_MONITOR\s*=\s*(\w+)', variables)
if m:
    mm = re.search(r'%s\s*=\s*"([^"]*)"' % re.escape(m.group(1)), variables)
    primary = mm.group(1) if mm else ""

env_lines = ""
if os.path.isdir("/proc/driver/nvidia"):
    env_lines = ('hl.env("GBM_BACKEND", "nvidia-drm")\n'
                 'hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")\n'
                 'hl.env("LIBVA_DRIVER_NAME", "nvidia")\n')

tpl = open(os.path.join(stage, "hyprland.lua.in")).read()
tpl = (tpl.replace("@ENV_LINES@", env_lines).replace("@KB_LAYOUT@", layout)
          .replace("@KB_OPTIONS@", options).replace("@SHARE@", share))
open(os.path.join(stage, "hyprland.lua"), "w").write(tpl)
os.remove(os.path.join(stage, "hyprland.lua.in"))

# GreeterConfig.qml con los valores reales y el modo de prueba apagado
cfg_path = os.path.join(stage, "GreeterConfig.qml")
cfg = open(cfg_path).read()
cfg = re.sub(r'(readonly property string user:).*', r'\1 "%s"' % os.environ["GREETER_USER"], cfg)
cfg = re.sub(r'(readonly property string primaryOutput:).*', r'\1 "%s"' % primary, cfg)
cfg = re.sub(r'(readonly property bool testMode:).*', r'\1 false', cfg)
open(cfg_path, "w").write(cfg)
print("teclado: layout=%r opciones=%r | monitor principal=%r | NVIDIA=%s" % (layout, options, primary, bool(env_lines)))
PYEOF

# --- 2. comprobar -------------------------------------------------------------------------
echo "Comprobando la configuración de Hyprland del greeter..."
if [ "$TEST" = "1" ]; then
    VERIFY=(Hyprland --verify-config -c "$STAGE/hyprland.lua")
else
    VERIFY=(runuser -u "$USERNAME" -- Hyprland --verify-config -c "$STAGE/hyprland.lua")
fi
VERIFY_OUT="$("${VERIFY[@]}" 2>&1 || true)"
echo "$VERIFY_OUT" | tail -5
if ! echo "$VERIFY_OUT" | grep -qi "config ok"; then
    echo "La configuración de Hyprland del greeter NO es válida. No se tocó nada." >&2
    exit 1
fi
sh -n "$HERE/ombu-greeter-session" && sh -n "$HERE/run-greeter.sh"

# --- 3. instalar --------------------------------------------------------------------------
install -d -m 755 "$SHARE"
cp -a "$STAGE"/. "$SHARE"/
chown -R root:root "$SHARE" 2>/dev/null || true
chmod -R a+rX "$SHARE"
chmod 755 "$SHARE/run-greeter.sh"
install -d -m 755 "$(dirname "$BIN")"
install -m 755 "$HERE/ombu-greeter-session" "$BIN"
echo "Archivos instalados en $SHARE y $BIN"

# Si el greeter trae la intro en video, se deja una marca en tu carpeta de datos: así ombu no la repite
# después de la contraseña (ver Welcome.qml). Sin intro, se borra la marca.
MARK="$USERHOME/.local/share/ombu/intro-en-login"
if [ -f "$SHARE/intro.mp4" ]; then
    install -d -m 755 -o "$USERNAME" "$(dirname "$MARK")" 2>/dev/null || mkdir -p "$(dirname "$MARK")"
    echo 1 >"$MARK"
    chown "$USERNAME" "$MARK" 2>/dev/null || true
    echo "La intro en video sonará en el login (marca: $MARK)"
else
    rm -f "$MARK"
fi

# --- 4. greetd ----------------------------------------------------------------------------
if [ ! -e "$GREETD_CONF.noctalia-backup" ]; then
    cp -a "$GREETD_CONF" "$GREETD_CONF.noctalia-backup"
    echo "Copia de seguridad: $GREETD_CONF.noctalia-backup"
fi
python3 - "$GREETD_CONF" "$BIN" <<'PYEOF'
import re, sys
path, command = sys.argv[1:3]
section, out, done = None, [], False
for line in open(path).read().split("\n"):
    m = re.match(r"\s*\[(.+)\]\s*$", line)
    if m:
        section = m.group(1)
    if section == "default_session" and re.match(r"\s*command\s*=", line):
        out.append('command = "%s"' % command)
        done = True
        continue
    out.append(line)
if not done:
    sys.exit("No encontré 'command' en [default_session]")
open(path, "w").write("\n".join(out))
PYEOF

echo
echo "Listo. El greeter de ombu se usará en el PRÓXIMO inicio de sesión (greetd no se reinició)."
echo "Si algo fallara y no ves la pantalla de ingreso:"
echo "  1. Ctrl+Alt+F2, iniciá sesión en la consola de texto"
echo "  2. sudo bash $HERE/uninstall.sh   (o: sudo cp $GREETD_CONF.noctalia-backup $GREETD_CONF)"
echo "  3. sudo systemctl restart greetd"

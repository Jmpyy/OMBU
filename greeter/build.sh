#!/usr/bin/env bash
# Arma en una carpeta todo lo que necesita el greeter: los archivos propios (greeter/) más los
# componentes que comparte con la pantalla de bloqueo (se copian desde la carpeta de ombu, así
# hay una sola fuente de verdad). Uso: build.sh DESTINO
set -euo pipefail

DEST="${1:?uso: build.sh DESTINO}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OMBU="$(cd "$HERE/.." && pwd)"

SHARED=(Theme.qml MIcon.qml AvatarRing.qml NameBadge.qml Halftone.qml LockBackdrop.qml LockChip.qml LockPower.qml Chrono.qml Keyboard.qml Ui.qml)
OWN=(shell.qml GreeterConfig.qml GreeterAuth.qml GreeterScreen.qml GreeterIntro.qml IntroState.qml)

mkdir -p "$DEST"
for f in "${SHARED[@]}"; do cp "$OMBU/$f" "$DEST/$f"; done
for f in "${OWN[@]}"; do cp "$HERE/$f" "$DEST/$f"; done
# La trama de puntos (Halftone) lee su imagen de assets/
mkdir -p "$DEST/assets" && cp "$OMBU/assets/halftone.png" "$DEST/assets/halftone.png"
cp "$HERE/run-greeter.sh" "$DEST/run-greeter.sh"
cp "$HERE/hyprland.lua.in" "$DEST/hyprland.lua.in"
chmod +x "$DEST/run-greeter.sh"

# El greeter corre como otro usuario, sin acceso a tu carpeta personal ni a Themes.qml/Walls.qml:
# se le fijan la paleta del tema elegido, el fondo y la tipografía. SHARE es donde quedará instalado.
# OMBU_THEME_HOME: la casa de quien tiene el tema (install.sh la pasa; por defecto, la de quien corre esto).
SHARE="${OMBU_SHARE:-/usr/share/ombu-greeter}" THEME_HOME="${OMBU_THEME_HOME:-$HOME}" \
python3 - "$OMBU" "$DEST" <<'PYEOF'
import json, os, re, shutil, sys
ombu, dest = sys.argv[1:3]
share, home = os.environ["SHARE"], os.environ["THEME_HOME"]
data = os.path.join(home, ".local/share/ombu")

def load(path):
    try:
        return json.load(open(path))
    except (OSError, ValueError):
        return {}

# Paleta: se saca del bloque con ese id en Themes.qml (los valores son cadenas simples)
theme_id = load(os.path.join(data, "tema.json")).get("id", "")
src = open(os.path.join(ombu, "Themes.qml")).read()
palette = None
for m in re.finditer(r"\{([^{}]*?)\}", src):
    body = m.group(1)
    ident = re.search(r'id:\s*"([^"]+)"', body)
    if ident and (ident.group(1) == theme_id or (palette is None and ident.group(1) == "ombu")):
        palette = {k: v for k, v in re.findall(r'(\w+):\s*"([^"]*)"', re.sub(r"//[^\n]*", "", body))}
        if ident.group(1) == theme_id:
            break
palette = palette or {}
palette.setdefault("bg", "#14131a")
open(os.path.join(dest, "Themes.qml"), "w").write(
    "pragma Singleton\n\nimport QtQuick\nimport Quickshell\n\n// Generado por greeter/build.sh: el tema elegido, fijo\nSingleton {\n"
    "    readonly property var active: %s\n}\n" % json.dumps(palette))

# Fondo: el elegido, copiado junto al greeter
wall = load(os.path.join(data, "fondo.json")).get("path", "") or load(os.path.join(data, "fondo.json")).get("current", "")
has_wall = bool(wall) and os.path.isfile(wall)
if has_wall:
    shutil.copy(wall, os.path.join(dest, "fondo.jpg"))
open(os.path.join(dest, "Walls.qml"), "w").write(
    'pragma Singleton\n\nimport QtQuick\nimport Quickshell\n\n// Generado por greeter/build.sh: el fondo elegido, copiado\nSingleton {\n'
    '    readonly property string current: "%s"\n}\n' % (os.path.join(share, "fondo.jpg") if has_wall else ""))

# Intro de ombu en video (si existe): suena en el login antes de pedir la contraseña
intro = os.path.join(data, "intro.mp4")
has_intro = os.path.isfile(intro)
if has_intro:
    shutil.copy(intro, os.path.join(dest, "intro.mp4"))

# Tipografía del tema (si es una que tengamos en ~/.local/share/fonts/ombu)
font = palette.get("display", "")
fdir = os.path.join(home, ".local/share/fonts/ombu")
if font and os.path.isdir(fdir):
    for f in os.listdir(fdir):
        if f.lower().startswith(font.lower()):
            shutil.copy(os.path.join(fdir, f), os.path.join(dest, f))
print("tema=%s fondo=%s tipografía=%s intro=%s" % (theme_id or "(ninguno)", "sí" if has_wall else "no", font or "-", "sí" if has_intro else "no"))
PYEOF
echo "greeter armado en $DEST ($(ls "$DEST" | wc -l) archivos)"

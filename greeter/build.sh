#!/usr/bin/env bash
# Arma en una carpeta todo lo que necesita el greeter: los archivos propios (greeter/) más los
# componentes que comparte con la pantalla de bloqueo (se copian desde la carpeta de ombu, así
# hay una sola fuente de verdad). Uso: build.sh DESTINO
set -euo pipefail

DEST="${1:?uso: build.sh DESTINO}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OMBU="$(cd "$HERE/.." && pwd)"

SHARED=(Theme.qml MIcon.qml AvatarRing.qml LockBackdrop.qml LockChip.qml LockPower.qml Chrono.qml Keyboard.qml Ui.qml)
OWN=(shell.qml GreeterConfig.qml GreeterAuth.qml GreeterScreen.qml)

mkdir -p "$DEST"
for f in "${SHARED[@]}"; do cp "$OMBU/$f" "$DEST/$f"; done
for f in "${OWN[@]}"; do cp "$HERE/$f" "$DEST/$f"; done
cp "$HERE/run-greeter.sh" "$DEST/run-greeter.sh"
cp "$HERE/hyprland.lua.in" "$DEST/hyprland.lua.in"
chmod +x "$DEST/run-greeter.sh"
echo "greeter armado en $DEST ($(ls "$DEST" | wc -l) archivos)"

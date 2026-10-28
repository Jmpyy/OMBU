#!/usr/bin/env bash
# Tests de QML (qmltestrunner, sin pantalla). Arma una carpeta con los controles reales, el Theme de
# mentira de tests/qml/stub y Logic.js, y corre los tst_*.qml de tests/qml. Sale con 0 si pasan todos.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
controls=(MenuRow ToggleSwitch Segmented PillSlider MixerSlider KeyFocus MIcon)
for c in "${controls[@]}"; do cp "$here/$c.qml" "$dir/"; done
cp "$here/Logic.js" "$here/tests/qml/stub/Theme.qml" "$here"/tests/qml/tst_*.qml "$dir/"
{
    echo "singleton Theme 1.0 Theme.qml"
    for c in "${controls[@]}"; do echo "$c 1.0 $c.qml"; done
} >"$dir/qmldir"
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$dir" "$@"

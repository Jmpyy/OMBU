pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Modo de atajos activo de Hyprland (ej. "resize"). Vacío = ninguno.
// Hyprland avisa cada cambio con el evento submap>>nombre.
Singleton {
    id: root

    property string name: ""

    readonly property bool active: name !== "" && name !== "default" && name !== "reset"
    readonly property string label: name === "resize" ? "Redimensionar" : name

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "submap")
                root.name = event.data;
        }
    }
}

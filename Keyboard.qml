pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Layout de teclado activo (latam / us). Hyprland avisa cada cambio por evento.
Singleton {
    id: root

    property string layoutName: ""
    readonly property string code: shortCode(layoutName)

    function shortCode(name: string): string {
        if (!name)
            return "--";
        if (name.includes("Latin American"))
            return "LATAM";
        if (name.includes("(US)"))
            return "US";
        return name.slice(0, 3).toUpperCase();
    }

    // Igual que Alt+Shift: pasa al siguiente layout en todos los teclados
    function toggle(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    // Estado inicial: el layout del teclado principal
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards;
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    if (main)
                        root.layoutName = main.active_keymap;
                } catch (e) {
                    console.warn("No pude leer el layout de teclado:", e);
                }
            }
        }
    }

    // activelayout>>teclado,layout
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "activelayout")
                root.layoutName = event.data.slice(event.data.indexOf(",") + 1);
        }
    }
}

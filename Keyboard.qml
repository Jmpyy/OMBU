pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Layout de teclado activo (latam / us). Hyprland avisa cada cambio por evento.
Singleton {
    id: root

    property string layoutName: ""
    // Bloq Mayús activado en el teclado principal
    property bool caps: false
    readonly property string code: shortCode(layoutName)
    // Una pantalla que pide contraseña está a la vista (el greeter; el bloqueo ya se sabe por Ui.locked)
    property bool watch: false

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

    // Hyprland no avisa los cambios de Bloq Mayús: se vuelve a leer cuando hace falta
    function refreshLeds(): void {
        ledTimer.restart();
    }

    Timer {
        id: ledTimer

        // El estado cambia un instante después de apretar la tecla
        interval: 80
        onTriggered: {
            if (!leds.running)
                leds.running = true;
        }
    }

    // Hyprland no avisa del Bloq Mayús y la lectura al apretar la tecla a veces llega antes del
    // cambio: mientras se pide contraseña se relee seguido para que el aviso nunca quede pegado
    Timer {
        interval: 400
        repeat: true
        running: Ui.locked || root.watch
        onTriggered: root.refreshLeds()
    }

    // Estado inicial: el layout del teclado principal y el Bloq Mayús
    Process {
        id: leds

        running: true
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards;
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    if (main) {
                        root.layoutName = main.active_keymap;
                        root.caps = main.capsLock === true;
                    }
                } catch (e) {
                    console.warn("No pude leer el layout de teclado:", e);
                }
            }
        }
    }

    // Al bloquear, el Bloq Mayús pudo haber quedado activado
    Connections {
        target: Ui

        function onLockedChanged(): void {
            if (Ui.locked)
                root.refreshLeds();
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

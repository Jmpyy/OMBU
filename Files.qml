pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Dolphin como cajón (Super+E, ver bin/files.sh): vive en el escritorio especial «archivos». Una app que se
// abre desde el cajón (un PDF, una imagen, la terminal) nacería adentro y se escondería con él: acá se la
// lleva al escritorio de siempre y se esconde el cajón, como cuando Finder abre un archivo.
// Si el cajón queda escondido 10 minutos se cierra Dolphin (files.sh rest): mientras se usa, Super+E es
// instantáneo; después, los ~225 MB de Dolphin y sus procesos de KIO vuelven.
Singleton {
    id: root

    // Lo nombra shell.qml al arrancar para que el singleton exista y escuche
    function start(): void {
    }

    Timer {
        id: rest

        interval: 600000
        onTriggered: Quickshell.execDetached([Quickshell.shellPath("bin/files.sh"), "rest"])
    }

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "activespecial") {
                // «escritorio especial,monitor»: vacío si se escondió
                if ((event.data ?? "").split(",")[0] === "special:archivos")
                    rest.stop();
                else
                    rest.restart();
                return;
            }
            if (event.name !== "openwindow")
                return;
            // «dirección,escritorio,clase,título»: el título puede tener comas, lo demás no
            const d = (event.data ?? "").split(",");
            if (d[1] === "special:archivos" && d[2] !== "org.kde.dolphin")
                Quickshell.execDetached([Quickshell.shellPath("bin/files.sh"), "adopt", d[0]]);
        }
    }
}

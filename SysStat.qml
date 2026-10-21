pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Estado de la PC: el chip de la barra y el panel lateral. Lo mide bin/sysstat.py.
Singleton {
    id: root

    // Modo liviano (procesador y memoria, sin nvidia-smi) para algo que lo necesite siempre a la vista. Hoy
    // nada: el chip de RAM de la barra se sacó (la persona no quiere monitores del sistema ahí), así que
    // no corre nada de fondo. La medición completa solo corre con el panel en su pestaña «Sistema».
    property bool active: false
    // Lo enciende el panel lateral (SidePanel) mientras muestra su pestaña «Sistema»
    property bool full: false
    // Última medición (ver bin/sysstat.py); {} hasta que llega la primera
    property var data: ({})

    function read(line: string): void {
        try {
            root.data = JSON.parse(line);
        } catch (e) {}
    }

    function stopped(): void {
        if (!lightMeter.running && !fullMeter.running)
            root.data = ({});
    }

    Process {
        id: lightMeter

        running: root.active && !root.full
        command: [Quickshell.shellPath("bin/sysstat.py"), "--watch", "3", "--light"]
        stdout: SplitParser {
            onRead: line => root.read(line)
        }
        onRunningChanged: if (!running)
            root.stopped()
    }

    Process {
        id: fullMeter

        running: root.full
        command: [Quickshell.shellPath("bin/sysstat.py"), "--watch", "2"]
        stdout: SplitParser {
            onRead: line => root.read(line)
        }
        onRunningChanged: if (!running)
            root.stopped()
    }
}

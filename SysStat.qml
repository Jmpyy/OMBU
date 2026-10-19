pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Estado de la PC: el chip de la barra y el panel lateral. Lo mide bin/sysstat.py.
Singleton {
    id: root

    // El chip de la barra necesita procesador y memoria todo el tiempo: eso corre en modo liviano (sin
    // nvidia-smi, que es lo caro). La medición completa solo corre con el panel en su pestaña «Sistema».
    property bool active: true
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

        running: root.active && root.full
        command: [Quickshell.shellPath("bin/sysstat.py"), "--watch", "2"]
        stdout: SplitParser {
            onRead: line => root.read(line)
        }
        onRunningChanged: if (!running)
            root.stopped()
    }
}

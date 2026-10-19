pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Estado de la PC para el panel lateral. bin/sysstat.py solo corre mientras `active` es verdadero
// (el panel abierto en su pestaña «Sistema»): cerrado no mide nada.
Singleton {
    id: root

    property bool active: false
    // Última medición (ver bin/sysstat.py); {} hasta que llega la primera
    property var data: ({})

    Process {
        running: root.active
        command: [Quickshell.shellPath("bin/sysstat.py"), "--watch", "2"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.data = JSON.parse(line);
                } catch (e) {}
            }
        }
        onRunningChanged: if (!running)
            root.data = ({})
    }
}

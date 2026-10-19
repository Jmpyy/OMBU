pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Brillo del monitor por DDC/CI (ddcutil): el monitor externo no tiene control por software
// como una notebook. Busca el bus I2C del primer monitor que responda, lee el brillo una vez
// y después manda los cambios de a uno (ddcutil tarda unos cientos de ms por llamada).
Singleton {
    id: root

    property int bus: -1
    property real level: 0.5
    readonly property bool available: bus >= 0

    // Brillo que se quiere (0-100) y el último que se mandó
    property int wanted: -1
    property int sent: -1

    function step(delta: int): void {
        if (!available)
            return;
        wanted = Math.max(0, Math.min(100, Math.round(level * 100) + delta));
        level = wanted / 100;
        Osd.showBrightness();
        flush();
    }

    function flush(): void {
        if (setter.running || wanted < 0 || wanted === sent)
            return;
        sent = wanted;
        setter.command = ["ddcutil", "--bus", String(bus), "setvcp", "10", String(sent), "--noverify"];
        setter.running = true;
    }

    Process {
        id: detect

        running: true
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/Display \d+\s+I2C bus:\s+\/dev\/i2c-(\d+)/);
                if (m) {
                    root.bus = parseInt(m[1]);
                    reader.running = true;
                }
            }
        }
    }

    Process {
        id: reader

        command: ["ddcutil", "--bus", String(root.bus), "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "VCP 10 C 53 100": valor actual y máximo
                const m = text.match(/VCP 10 C (\d+) (\d+)/);
                if (m && parseInt(m[2]) > 0)
                    root.level = parseInt(m[1]) / parseInt(m[2]);
            }
        }
    }

    Process {
        id: setter

        onRunningChanged: if (!running)
            root.flush()
    }
}

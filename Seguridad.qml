pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Seguridad y procesos para la pestaña «Sistema» del panel lateral (bin/seguridad.py). Lo «en vivo»
// (puertos, servicios caídos, firewall, procesos) solo corre con esa pestaña abierta (`active`, lo
// prende un Binding de SidePanel); las actualizaciones se consultan al abrirla (copia de 1 hora).
Singleton {
    id: root

    property bool active: false

    property var live: ({})
    property var updates: ({})
    property bool checking: false
    property string message: ""

    readonly property var ports: live.ports ?? []
    readonly property var exposed: ports.filter(p => p.exposed)
    readonly property var outgoing: live.outgoing ?? []
    readonly property var failed: live.failed ?? []
    readonly property var firewall: live.firewall ?? null
    readonly property var top: live.top ?? ({
            cpu: [],
            mem: []
        })
    readonly property int pending: (updates.repo ?? []).length + (updates.aur ?? []).length
    readonly property var unreadNews: (updates.news ?? []).filter(n => n.unread)
    readonly property real upgradedAt: live.upgradedAt ?? updates.upgradedAt ?? 0

    function load(force: bool): void {
        if (updProc.running)
            return;
        checking = true;
        updProc.command = [Quickshell.shellPath("bin/seguridad.py"), "updates"].concat(force ? ["--refresh"] : []);
        updProc.running = true;
    }

    // Cierra (SIGTERM) los procesos propios con ese nombre; seguridad.py se niega con los de la sesión
    function close(name: string): void {
        killProc.command = [Quickshell.shellPath("bin/seguridad.py"), "kill", name];
        killProc.running = true;
    }

    // Actualizar se hace en la terminal (pide la contraseña y conviene ver qué pasa)
    function upgradeInTerminal(): void {
        Quickshell.execDetached(["kitty", "--title", "Actualizar el sistema", "sh", "-c", "paru; echo; echo 'Listo. Enter para cerrar.'; read _"]);
        Ui.sideOpen = false;
    }

    function journal(unit: string, scope: string): void {
        Quickshell.execDetached(["kitty", "--title", "Log de " + unit, "journalctl"].concat(scope === "user" ? ["--user"] : []).concat(["-e", "-u", unit, "-n", "200"]));
        Ui.sideOpen = false;
    }

    Process {
        running: root.active
        command: [Quickshell.shellPath("bin/seguridad.py"), "watch", "3"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.live = JSON.parse(line);
                } catch (e) {}
            }
        }
    }

    Process {
        id: updProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                try {
                    root.updates = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: killProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.message = r.error ?? (r.closed > 0 ? "Cerrado" : "No había nada para cerrar");
                } catch (e) {
                    root.message = "";
                }
                msgTimer.restart();
            }
        }
    }

    Timer {
        id: msgTimer

        interval: 4000
        onTriggered: root.message = ""
    }
}

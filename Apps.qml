pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Apps que siguen corriendo aunque no tengan ventana abierta.
Singleton {
    id: root

    // Todas las apps gráficas corriendo, según bgapps.py
    property var running: []

    // Ventanas de verdad: hay apps (el Minecraft Launcher) que esconden su ventana y Hyprland la deja
    // en la lista sin escritorio; esas no se muestran ni se cuentan.
    readonly property var windows: Array.from(Hyprland.toplevels.values).filter(t => t.workspace !== null && t.workspace !== undefined)

    readonly property var windowPids: {
        const set = {};
        for (const t of windows) {
            const pid = t.lastIpcObject?.pid;
            if (pid)
                set[pid] = true;
        }
        return set;
    }

    // Algunas apps abren su ventana desde otro proceso: también se compara por entrada .desktop
    readonly property var windowEntryIds: {
        const set = {};
        for (const t of windows) {
            const appId = t.wayland?.appId;
            const entry = appId ? DesktopEntries.heuristicLookup(appId) : null;
            if (entry)
                set[entry.id.toLowerCase()] = true;
        }
        return set;
    }

    readonly property var background: running.filter(a => !a.pids.some(p => windowPids[p]) && !windowEntryIds[a.id.toLowerCase()])

    function refresh(): void {
        Hyprland.refreshToplevels();
        if (!scan.running)
            scan.running = true;
    }

    // Para refrescar la lista poco después de una acción (minimizar, cerrar...)
    function refreshSoon(): void {
        recheck.restart();
    }

    // Lanzar una app que ya está corriendo suele traer su ventana al frente
    function open(app): void {
        const entry = DesktopEntries.heuristicLookup(app.id) ?? DesktopEntries.heuristicLookup(app.name);
        if (entry)
            entry.execute();
    }

    // Cierre normal (SIGTERM) de todos los procesos de la app; si alguno no hace caso (el Minecraft
    // Launcher captura la señal), a los 3 segundos se lo fuerza. Se mata por PID: el juego, que es
    // un proceso aparte, sigue.
    function close(app): void {
        const pids = (app.pids ?? [app.main]).map(String);
        Quickshell.execDetached(["sh", "-c", 'kill "$@" 2>/dev/null; sleep 3; kill -9 "$@" 2>/dev/null', "sh"].concat(pids));
        recheck.restart();
    }

    Process {
        id: scan

        command: ["python3", "-I", Quickshell.shellPath("bgapps.py")]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.running = JSON.parse(text);
                } catch (e) {
                    console.warn("bgapps.py devolvió algo ilegible:", e);
                }
            }
        }
    }

    Timer {
        interval: Ui.popup.startsWith("apps@") ? 1500 : 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: recheck

        interval: 900
        onTriggered: root.refresh()
    }
}
